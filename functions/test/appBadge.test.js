const test = require('node:test');
const assert = require('node:assert/strict');
const { getAppBadgeCount, createSendChatNotificationHandler } = require('../appBadge');

function fakeServices() {
  const records = new Map();
  const messages = [];
  function document(path) {
    return {
      path,
      collection(name) { return collection(`${path}/${name}`); },
      async get() { return { ref: this, data: () => records.get(path) }; },
    };
  }
  function collection(path) {
    const docs = (filters) => [...records.entries()]
      .filter(([key, data]) => key.startsWith(`${path}/`) &&
        !key.slice(path.length + 1).includes('/') &&
        filters.every(([field, operator, value]) => operator === 'array-contains'
          ? Array.isArray(data[field]) && data[field].includes(value)
          : data[field] === value))
      .map(([key, data]) => ({ ref: document(key), data: () => data }));
    function query(filters) {
      return {
        where(field, operator, value) { return query([...filters, [field, operator, value]]); },
        count() { return { get: async () => ({ data: () => ({ count: docs(filters).length }) }) }; },
        async get() { return { docs: docs(filters) }; },
      };
    }
    return { ...query([]), doc(id) { return document(`${path}/${id}`); } };
  }
  return {
    db: { collection }, records, messages,
    messaging: { async send(message) { messages.push(message); } },
    logger: { error() {} },
  };
}

test('badge sums pending invitations and unread chats across current memberships', async () => {
  const { db, records } = fakeServices();
  records.set('friendRequests/f1', { toUserID: 'member', status: 'pending' });
  records.set('friendRequests/f2', { toUserID: 'member', status: 'accepted' });
  records.set('meetingRequests/r1', { toUserID: 'member', status: 'pending' });
  records.set('meetingRequests/r2', { toUserID: 'other', status: 'pending' });
  records.set('meetings/m1', { meetingMembers: ['sender', 'member'] });
  records.set('meetings/m1/chat/summary', { incomingCounts: { member: 5 } });
  records.set('meetings/m1/readStates/member', { lastReadIncomingCount: 3 });
  records.set('meetings/m2', { meetingMembers: ['member'] });
  records.set('meetings/m2/chat/summary', { incomingCounts: { member: 2 } });
  records.set('meetings/m3', { meetingMembers: ['other'] });
  records.set('meetings/m3/chat/summary', { incomingCounts: { member: 9 } });

  assert.equal(await getAppBadgeCount(db, 'member'), 6);
  records.set('meetings/m1/readStates/member', { lastReadIncomingCount: 5 });
  assert.equal(await getAppBadgeCount(db, 'member'), 4);
});

test('new chat sends preview, room deep link, sound and total badge to other members once', async () => {
  const services = fakeServices();
  services.records.set('meetings/m1', { meetingName: '저녁 약속', meetingMembers: ['sender', 'member', 'member'] });
  services.records.set('meetings/m1/chat/summary', { incomingCounts: { member: 3 } });
  services.records.set('meetings/m1/readStates/member', { lastReadIncomingCount: 1 });
  services.records.set('meetingRequests/r1', { toUserID: 'member', status: 'pending' });
  services.records.set('users/member', { fcmToken: 'member-token' });
  services.records.set('users/sender', { name: '찬솔', fcmToken: 'sender-token' });

  const send = createSendChatNotificationHandler(services);
  await send(chatEvent());

  assert.equal(services.messages.length, 1);
  assert.equal(services.messages[0].token, 'member-token');
  assert.equal(services.messages[0].apns.payload.aps.badge, 3);
  assert.deepEqual(services.messages[0].notification, { title: '저녁 약속', body: '찬솔: 곧 도착해요!' });
  assert.deepEqual(services.messages[0].data, { route: 'meetingChat', meetingId: 'm1', messageId: 'message1' });
  assert.equal(services.messages[0].apns.payload.aps.sound, 'default');
  assert.equal(services.messages[0].apns.payload.aps.threadId, 'meeting-chat-m1');
});

function chatEvent(text = '곧 도착해요!') {
  return {
    params: { meetingId: 'm1', messageId: 'message1' },
    data: { data: () => ({ senderId: 'sender', text }) },
  };
}

test('deleted meetings and nonmember senders do not produce notifications', async () => {
  const services = fakeServices();
  services.records.set('users/member', { fcmToken: 'member-token' });
  const send = createSendChatNotificationHandler(services);
  await send(chatEvent());
  services.records.set('meetings/m1', { meetingMembers: ['member'] });
  await send(chatEvent());
  assert.equal(services.messages.length, 0);
});

test('logged-out recipients and users without tokens are skipped', async () => {
  const services = fakeServices();
  services.records.set('meetings/m1', { meetingMembers: ['sender', 'logged-out', 'no-token'] });
  services.records.set('users/logged-out', { fcmToken: 'old-token', loginStatus: false });
  await createSendChatNotificationHandler(services)(chatEvent());
  assert.equal(services.messages.length, 0);
});

test('long unicode messages stay within the APNs payload limit with readable previews', async () => {
  const services = fakeServices();
  services.records.set('meetings/m1', { meetingName: '모'.repeat(2000), meetingMembers: ['sender', 'member'] });
  services.records.set('users/sender', { name: '이'.repeat(2000) });
  services.records.set('users/member', { fcmToken: 'member-token' });
  await createSendChatNotificationHandler(services)(chatEvent('😀'.repeat(1000)));
  const payload = services.messages[0];
  assert.ok(payload.notification.body.endsWith('😀…'));
  assert.ok(!payload.notification.body.includes('\uFFFD'));
  assert.ok(Buffer.byteLength(JSON.stringify(payload), 'utf8') < 4096);
});

test('badge calculation failure still delivers the message without resetting the badge', async () => {
  const services = fakeServices();
  services.records.set('meetings/m1', { meetingMembers: ['sender', 'member'] });
  services.records.set('users/member', { fcmToken: 'member-token' });
  const collection = services.db.collection;
  services.db.collection = (name) => {
    if (name === 'friendRequests') throw new Error('Temporary query failure');
    return collection(name);
  };
  await createSendChatNotificationHandler(services)(chatEvent());
  assert.equal(services.messages.length, 1);
  assert.equal(services.messages[0].notification.body, '모임 멤버: 곧 도착해요!');
  assert.equal(services.messages[0].apns.payload.aps.badge, undefined);
});

test('one invalid recipient token does not block another member notification', async () => {
  const services = fakeServices();
  services.records.set('meetings/m1', { meetingMembers: ['sender', 'bad', 'member'] });
  services.records.set('users/bad', { fcmToken: 'bad-token' });
  services.records.set('users/member', { fcmToken: 'member-token' });
  services.messaging.send = async (message) => {
    if (message.token === 'bad-token') throw new Error('Invalid token');
    services.messages.push(message);
  };
  await createSendChatNotificationHandler(services)(chatEvent());
  assert.equal(services.messages.length, 1);
  assert.equal(services.messages[0].token, 'member-token');
});
