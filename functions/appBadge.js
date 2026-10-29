function nonNegativeCount(value) {
  const count = Number(value);
  return Number.isSafeInteger(count) && count > 0 ? count : 0;
}

async function getAppBadgeCount(db, uid) {
  const [friendRequests, meetingRequests, meetings] = await Promise.all([
    db.collection('friendRequests')
      .where('toUserID', '==', uid).where('status', '==', 'pending').count().get(),
    db.collection('meetingRequests')
      .where('toUserID', '==', uid).where('status', '==', 'pending').count().get(),
    db.collection('meetings').where('meetingMembers', 'array-contains', uid).get(),
  ]);

  const unreadByMeeting = await Promise.all(meetings.docs.map(async (meeting) => {
    const [summary, readState] = await Promise.all([
      meeting.ref.collection('chat').doc('summary').get(),
      meeting.ref.collection('readStates').doc(uid).get(),
    ]);
    const summaryData = summary.data() || {};
    const readData = readState.data() || {};
    const incoming = nonNegativeCount((summaryData.incomingCounts || {})[uid]);
    const read = nonNegativeCount(readData.lastReadIncomingCount);
    return Math.max(0, incoming - read);
  }));

  return nonNegativeCount(friendRequests.data().count) +
    nonNegativeCount(meetingRequests.data().count) +
    unreadByMeeting.reduce((total, count) => total + count, 0);
}

function badgeApns(count) {
  return {
    headers: { 'apns-push-type': 'alert', 'apns-priority': '10' },
    payload: { aps: { badge: count } },
  };
}

function notificationPreview(value, fallback, limit) {
  const text = typeof value === 'string' ? value.trim() : '';
  const characters = Array.from(text || fallback);
  return characters.length > limit ? characters.slice(0, limit).join('') + '…' : characters.join('');
}

function createSendChatNotificationHandler({ db, messaging, logger = console }) {
  return async (event) => {
    const message = event.data && event.data.data();
    const meetingId = event.params && event.params.meetingId;
    const messageId = event.params && event.params.messageId;
    if (!meetingId || !messageId || !message || !message.senderId ||
        typeof message.text !== 'string' || !message.text.trim()) return;

    const meeting = await db.collection('meetings').doc(meetingId).get();
    const members = (meeting.data() || {}).meetingMembers;
    if (!Array.isArray(members) || !members.includes(message.senderId)) return;

    const sender = await db.collection('users').doc(message.senderId).get();
    const senderName = notificationPreview((sender.data() || {}).name, '모임 멤버', 40);
    const meetingName = notificationPreview((meeting.data() || {}).meetingName, '모임 채팅', 80);
    const preview = notificationPreview(message.text, '', 200);
    const recipients = [...new Set(members)].filter((uid) => typeof uid === 'string' && uid && uid !== message.senderId);
    await Promise.all(recipients.map(async (uid) => {
      try {
        const user = await db.collection('users').doc(uid).get();
        const recipient = user.data() || {};
        const token = recipient.fcmToken;
        if (typeof token !== 'string' || !token || recipient.loginStatus === false) return;
        const apns = {
          headers: { 'apns-push-type': 'alert', 'apns-priority': '10' },
          payload: { aps: { sound: 'default', threadId: `meeting-chat-${meetingId}` } },
        };
        // A temporary badge query failure must not discard the actual message alert.
        try {
          apns.payload.aps.badge = await getAppBadgeCount(db, uid);
        } catch (error) {
          logger.error(`채팅 알림 뱃지 계산 실패 (${uid}):`, error);
        }
        await messaging.send({
          token,
          notification: { title: meetingName, body: `${senderName}: ${preview}` },
          data: { route: 'meetingChat', meetingId, messageId },
          apns,
        });
      } catch (error) {
        logger.error(`채팅 메시지 알림 전송 실패 (${uid}):`, error);
      }
    }));
  };
}

module.exports = { getAppBadgeCount, badgeApns, createSendChatNotificationHandler };
