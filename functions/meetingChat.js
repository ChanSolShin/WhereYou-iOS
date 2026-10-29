const { FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');

function documentId(value) {
  return typeof value === 'string' && value.length > 0 && value.length <= 128 &&
    !value.includes('/');
}

function memberIds(meeting) {
  const members = meeting?.meetingMembers;
  return Array.isArray(members) ? [...new Set(members.filter(documentId))] : [];
}

function requireMember(meeting, uid) {
  if (!memberIds(meeting).includes(uid)) {
    throw new HttpsError('permission-denied', '이 모임의 멤버만 채팅할 수 있습니다.');
  }
}

function createSendMeetingChatMessageHandler({ db }) {
  return async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
    const { meetingId, messageId, text } = request.data || {};
    const body = typeof text === 'string' ? text.trim() : '';
    if (!documentId(meetingId) || !documentId(messageId) || !body || body.length > 2000) {
      throw new HttpsError('invalid-argument', '메시지는 1~2000자로 입력해 주세요.');
    }

    const meetingRef = db.collection('meetings').doc(meetingId);
    const summaryRef = meetingRef.collection('chat').doc('summary');
    const messageRef = meetingRef.collection('messages').doc(messageId);
    return db.runTransaction(async (tx) => {
      const [meetingDoc, summaryDoc, existingDoc] = await Promise.all([
        tx.get(meetingRef), tx.get(summaryRef), tx.get(messageRef),
      ]);
      requireMember(meetingDoc.data(), uid);
      if (existingDoc.exists) {
        if (existingDoc.data().senderId !== uid) {
          throw new HttpsError('already-exists', '이미 사용된 메시지 ID입니다.');
        }
        return { sent: true, messageId };
      }
      const old = summaryDoc.data() || {};
      // Keep departed members' counters so rejoining does not reset their unread baseline.
      const incomingCounts = { ...(old.incomingCounts || {}) };
      for (const memberId of memberIds(meetingDoc.data())) {
        incomingCounts[memberId] = Math.max(0, Number(old.incomingCounts?.[memberId]) || 0) +
          (memberId === uid ? 0 : 1);
      }
      const sequence = Math.max(0, Number(old.lastSequence) || 0) + 1;
      const createdAt = FieldValue.serverTimestamp();
      tx.create(messageRef, { senderId: uid, text: body, createdAt, sequence, incomingCounts });
      tx.set(summaryRef, {
        lastSequence: sequence,
        lastMessageId: messageId,
        lastMessagePreview: body.slice(0, 100),
        lastMessageSenderId: uid,
        lastMessageAt: createdAt,
        incomingCounts,
      });
      return { sent: true, messageId };
    });
  };
}

function createMarkMeetingChatReadHandler({ db }) {
  return async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
    const { meetingId, messageId } = request.data || {};
    if (!documentId(meetingId) || !documentId(messageId)) {
      throw new HttpsError('invalid-argument', '읽은 메시지 정보를 확인해 주세요.');
    }
    const meetingRef = db.collection('meetings').doc(meetingId);
    const messageRef = meetingRef.collection('messages').doc(messageId);
    const readRef = meetingRef.collection('readStates').doc(uid);
    return db.runTransaction(async (tx) => {
      const [meetingDoc, messageDoc, readDoc] = await Promise.all([
        tx.get(meetingRef), tx.get(messageRef), tx.get(readRef),
      ]);
      requireMember(meetingDoc.data(), uid);
      if (!messageDoc.exists) {
        throw new HttpsError('not-found', '메시지를 찾을 수 없습니다.');
      }
      const seenCount = Math.max(0, Number(messageDoc.data().incomingCounts?.[uid]) || 0);
      const previous = Math.max(0, Number(readDoc.data()?.lastReadIncomingCount) || 0);
      if (seenCount > previous) {
        tx.set(readRef, { lastReadIncomingCount: seenCount, updatedAt: FieldValue.serverTimestamp() });
      }
      return { read: true };
    });
  };
}

function createAcceptMeetingInvitationHandler({ db }) {
  return async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
    const requestId = request.data?.requestId;
    if (!documentId(requestId)) {
      throw new HttpsError('invalid-argument', '초대 정보를 확인해 주세요.');
    }
    const invitationRef = db.collection('meetingRequests').doc(requestId);
    return db.runTransaction(async (tx) => {
      const invitationDoc = await tx.get(invitationRef);
      const invitation = invitationDoc.data();
      if (!invitation || invitation.toUserID !== uid || invitation.status !== 'pending' ||
          !documentId(invitation.meetingID)) {
        throw new HttpsError('permission-denied', '유효한 모임 초대가 아닙니다.');
      }
      const meetingRef = db.collection('meetings').doc(invitation.meetingID);
      const meetingDoc = await tx.get(meetingRef);
      if (!meetingDoc.exists || !memberIds(meetingDoc.data()).includes(invitation.fromUserID)) {
        throw new HttpsError('failed-precondition', '모임이 없거나 초대한 사람이 모임을 떠났습니다.');
      }
      tx.update(meetingRef, { meetingMembers: FieldValue.arrayUnion(uid) });
      tx.delete(invitationRef);
      return { accepted: true };
    });
  };
}

function createCompleteLegacyMeetingInvitationHandler({ db }) {
  return async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (before?.status !== 'pending' || after?.status !== 'accepted' ||
        !documentId(after.meetingID) || !documentId(after.toUserID) ||
        !documentId(after.fromUserID) || !documentId(event.params?.requestId)) return;
    const meetingRef = db.collection('meetings').doc(after.meetingID);
    const invitationRef = db.collection('meetingRequests').doc(event.params.requestId);
    await db.runTransaction(async (tx) => {
      const [meeting, invitation] = await Promise.all([
        tx.get(meetingRef), tx.get(invitationRef),
      ]);
      if (meeting.exists && memberIds(meeting.data()).includes(after.fromUserID)) {
        tx.update(meetingRef, { meetingMembers: FieldValue.arrayUnion(after.toUserID) });
      }
      const current = invitation.data();
      if (current?.status === 'accepted' && current.meetingID === after.meetingID &&
          current.toUserID === after.toUserID) {
        tx.delete(invitationRef);
      }
    });
  };
}

module.exports = {
  createSendMeetingChatMessageHandler,
  createMarkMeetingChatReadHandler,
  createAcceptMeetingInvitationHandler,
  createCompleteLegacyMeetingInvitationHandler,
};
