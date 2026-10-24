const { FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');

const messages = Object.freeze({
  whereAreYou: '어디쯤 오고 있어요?',
  startingSoon: '곧 시작해요. 서둘러 주세요!',
  almostThere: '저 거의 도착했어요.',
  runningLate: '조금 늦을 것 같아요.',
});

const cooldownMs = 30_000;
const invalidTokenCodes = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function validDocumentId(value) {
  return typeof value === 'string' && value.length > 0 &&
    value.length <= 128 && !value.includes('/');
}

function createMeetingMemberNotificationHandler({ db, messaging, now = Date.now, logger = console }) {
  return async (request) => {
    const senderId = request.auth?.uid;
    if (!senderId) {
      throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
    }

    const { meetingId, recipientId, preset } = request.data || {};
    if (!validDocumentId(meetingId) || !validDocumentId(recipientId) ||
        typeof preset !== 'string' || !Object.hasOwn(messages, preset)) {
      throw new HttpsError('invalid-argument', '알림 정보를 확인해 주세요.');
    }
    if (senderId === recipientId) {
      throw new HttpsError('invalid-argument', '자기 자신에게는 알림을 보낼 수 없습니다.');
    }

    const meetingRef = db.collection('meetings').doc(meetingId);
    const senderRef = db.collection('users').doc(senderId);
    const recipientRef = db.collection('users').doc(recipientId);
    const [meetingDoc, senderDoc, recipientDoc] = await Promise.all([
      meetingRef.get(), senderRef.get(), recipientRef.get(),
    ]);
    const meeting = meetingDoc.data();
    const members = meeting?.meetingMembers;
    if (!Array.isArray(members) || !members.includes(senderId) || !members.includes(recipientId)) {
      throw new HttpsError('permission-denied', '같은 모임의 멤버에게만 알림을 보낼 수 있습니다.');
    }

    const recipient = recipientDoc.data();
    const token = recipient?.fcmToken;
    if (typeof token !== 'string' || !token || recipient?.loginStatus === false) {
      throw new HttpsError('failed-precondition', '상대방이 알림을 받을 수 없는 상태입니다.');
    }

    const cooldownRef = db.collection('_meetingNotificationCooldowns')
      .doc(`${meetingId}_${senderId}_${recipientId}`);
    const reservationId = db.collection('_meetingNotificationCooldowns').doc().id;
    const sentAt = now();
    await db.runTransaction(async (transaction) => {
      const cooldown = await transaction.get(cooldownRef);
      if (sentAt - (cooldown.data()?.lastSentAtMs || 0) < cooldownMs) {
        throw new HttpsError('resource-exhausted', '같은 멤버에게는 30초 후 다시 보낼 수 있습니다.');
      }
      transaction.set(cooldownRef, { lastSentAtMs: sentAt, reservationId });
    });

    try {
      const senderName = senderDoc.data()?.name || '모임 멤버';
      const meetingName = meeting.meetingName || '모임';
      await messaging.send({
        token,
        notification: {
          title: `${meetingName} · ${senderName}님`,
          body: messages[preset],
        },
        data: { route: 'meetingView', meetingId },
        apns: {
          headers: { 'apns-push-type': 'alert', 'apns-priority': '10' },
          payload: { aps: { sound: 'default', threadId: meetingId } },
        },
      });
      return { sent: true };
    } catch (error) {
      const invalidToken = invalidTokenCodes.has(error?.code);
      try {
        // A newer token or reservation may have been written while FCM was responding.
        await db.runTransaction(async (transaction) => {
          const cooldown = await transaction.get(cooldownRef);
          const latestRecipient = invalidToken ? await transaction.get(recipientRef) : null;
          if (cooldown.data()?.reservationId === reservationId) {
            transaction.delete(cooldownRef);
          }
          if (invalidToken && latestRecipient.data()?.fcmToken === token) {
            transaction.update(recipientRef, { fcmToken: FieldValue.delete() });
          }
        });
      } catch (cleanupError) {
        logger.error('모임 멤버 알림 실패 상태 정리 오류:', cleanupError);
      }
      logger.error('모임 멤버 알림 전송 실패:', error);
      if (invalidToken) {
        throw new HttpsError('failed-precondition', '상대방의 알림 정보가 만료되었습니다. 상대방이 앱을 다시 열어야 합니다.');
      }
      throw new HttpsError('unavailable', '알림을 보내지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  };
}

module.exports = { createMeetingMemberNotificationHandler };
