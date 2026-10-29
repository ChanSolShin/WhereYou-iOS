const test = require('node:test');
const assert = require('node:assert/strict');
const {
  createSendMeetingChatMessageHandler,
  createMarkMeetingChatReadHandler,
  createAcceptMeetingInvitationHandler,
  createCompleteLegacyMeetingInvitationHandler,
} = require('../meetingChat');

function fakeDatabase() {
  const records = new Map();
  function ref(path) {
    return {
      path,
      collection(name) { return collection(`${path}/${name}`); },
    };
  }
  function collection(path) {
    return { doc(id) { return ref(`${path}/${id}`); } };
  }
  const db = {
    collection,
    async runTransaction(callback) {
      const writes = [];
      const tx = {
        async get(item) {
          const value = records.get(item.path);
          return { exists: value !== undefined, data: () => value };
        },
        create(item, data) { writes.push([item.path, data]); },
        set(item, data) { writes.push([item.path, data]); },
        update(item, data) { writes.push([item.path, { ...records.get(item.path), ...data }]); },
        delete(item) { writes.push([item.path, undefined]); },
      };
      const result = await callback(tx);
      for (const [path, data] of writes) {
        if (data === undefined) records.delete(path);
        else records.set(path, data);
      }
      return result;
    },
  };
  return { db, records };
}

test('only current meeting members can send and repeated message IDs do not duplicate counts', async () => {
  const { db, records } = fakeDatabase();
  records.set('meetings/m1', { meetingMembers: ['leader', 'member'] });
  const send = createSendMeetingChatMessageHandler({ db });
  const data = { meetingId: 'm1', messageId: 'fixed-id', text: '  안녕하세요  ' };
  await assert.rejects(send({ data }), { code: 'unauthenticated' });
  await assert.rejects(send({ auth: { uid: 'stranger' }, data }), { code: 'permission-denied' });
  await send({ auth: { uid: 'leader' }, data });
  await send({ auth: { uid: 'leader' }, data });
  assert.equal(records.get('meetings/m1/messages/fixed-id').text, '안녕하세요');
  assert.deepEqual(records.get('meetings/m1/chat/summary').incomingCounts, {
    leader: 0, member: 1,
  });
  assert.equal(records.get('meetings/m1/chat/summary').lastSequence, 1);
  await assert.rejects(send({ auth: { uid: 'member' }, data }), { code: 'already-exists' });
});

test('an invitation must belong to the caller and an active meeting member', async () => {
  const { db, records } = fakeDatabase();
  const accept = createAcceptMeetingInvitationHandler({ db });
  records.set('meetingRequests/r1', {
    toUserID: 'invitee', fromUserID: 'leader', meetingID: 'm1', status: 'pending',
  });
  records.set('meetings/m1', { meetingMembers: ['leader'] });
  await assert.rejects(accept({ auth: { uid: 'other' }, data: { requestId: 'r1' } }),
    { code: 'permission-denied' });
  await accept({ auth: { uid: 'invitee' }, data: { requestId: 'r1' } });
  assert.equal(records.has('meetingRequests/r1'), false);
  await assert.rejects(accept({ auth: { uid: 'invitee' }, data: { requestId: 'r1' } }),
    { code: 'permission-denied' });
});

test('old app invitation acceptance completes membership only for a real inviter', async () => {
  const { db, records } = fakeDatabase();
  const complete = createCompleteLegacyMeetingInvitationHandler({ db });
  const event = (fromUserID) => ({ params: { requestId: 'r1' }, data: {
    before: { data: () => ({ status: 'pending' }) },
    after: { data: () => ({
      status: 'accepted', fromUserID, toUserID: 'invitee', meetingID: 'm1',
    }) },
  } });
  records.set('meetings/m1', { meetingMembers: ['leader'] });
  records.set('meetingRequests/r1', {
    status: 'accepted', meetingID: 'm1', toUserID: 'invitee', fromUserID: 'leader',
  });
  await complete(event('stranger'));
  assert.deepEqual(records.get('meetings/m1').meetingMembers, ['leader']);
  assert.equal(records.has('meetingRequests/r1'), false);
  records.set('meetingRequests/r1', {
    status: 'accepted', meetingID: 'm1', toUserID: 'invitee', fromUserID: 'leader',
  });
  await complete(event('leader'));
  assert.notDeepEqual(records.get('meetings/m1').meetingMembers, ['leader']);
  assert.equal(records.has('meetingRequests/r1'), false);
});

test('read state stops at the last message actually seen and never moves backwards', async () => {
  const { db, records } = fakeDatabase();
  records.set('meetings/m1', { meetingMembers: ['leader', 'member'] });
  const send = createSendMeetingChatMessageHandler({ db });
  const markRead = createMarkMeetingChatReadHandler({ db });
  for (const messageId of ['a', 'b', 'c']) {
    await send({ auth: { uid: 'leader' }, data: { meetingId: 'm1', messageId, text: messageId } });
  }
  await markRead({ auth: { uid: 'member' }, data: { meetingId: 'm1', messageId: 'b' } });
  assert.equal(records.get('meetings/m1/readStates/member').lastReadIncomingCount, 2);
  await markRead({ auth: { uid: 'member' }, data: { meetingId: 'm1', messageId: 'a' } });
  assert.equal(records.get('meetings/m1/readStates/member').lastReadIncomingCount, 2);
  assert.equal(records.get('meetings/m1/chat/summary').incomingCounts.member -
    records.get('meetings/m1/readStates/member').lastReadIncomingCount, 1);
  await assert.rejects(markRead({ auth: { uid: 'stranger' }, data: {
    meetingId: 'm1', messageId: 'c',
  } }), { code: 'permission-denied' });
});
