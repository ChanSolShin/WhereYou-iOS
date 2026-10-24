const assert = require('node:assert/strict');
const test = require('node:test');
const { createMeetingMemberNotificationHandler } = require('../meetingMemberNotification');

function fakeServices() {
  const records = new Map([
    ['meetings/meeting', { meetingName: '토요일 모임', meetingMembers: ['sender', 'recipient'] }],
    ['users/sender', { name: '찬솔' }],
    ['users/recipient', { fcmToken: 'recipient-token', loginStatus: true }],
  ]);
  const messages = [];
  let nextId = 0;
  let sendError;

  const snapshot = (ref) => ({
    exists: records.has(ref.path),
    data: () => records.get(ref.path),
  });
  const db = {
    collection(name) {
      return {
        doc(id = `auto-${++nextId}`) {
          const ref = { path: `${name}/${id}` };
          ref.get = async () => snapshot(ref);
          return ref;
        },
      };
    },
    async runTransaction(callback) {
      const changes = [];
      const transaction = {
        get: async (ref) => snapshot(ref),
        set: (ref, value) => changes.push(() => records.set(ref.path, value)),
        update: (ref, value) => changes.push(() => {
          const updated = { ...records.get(ref.path) };
          for (const [key, field] of Object.entries(value)) {
            if (key === 'fcmToken' && typeof field !== 'string') {
              delete updated[key];
            } else {
              updated[key] = field;
            }
          }
          records.set(ref.path, updated);
        }),
        delete: (ref) => changes.push(() => records.delete(ref.path)),
      };
      const result = await callback(transaction);
      changes.forEach((change) => change());
      return result;
    },
  };
  const messaging = {
    async send(message) {
      if (sendError) throw sendError;
      messages.push(message);
      return 'message-id';
    },
  };
  return {
    db, messaging, records, messages,
    logger: { error() {} },
    setSendError: (error) => { sendError = error; },
  };
}

const request = {
  auth: { uid: 'sender' },
  data: { meetingId: 'meeting', recipientId: 'recipient', preset: 'startingSoon' },
};

test('rejects unauthenticated, self, and nonmember requests before sending', async () => {
  const services = fakeServices();
  const send = createMeetingMemberNotificationHandler(services);

  await assert.rejects(send({ ...request, auth: null }), { code: 'unauthenticated' });
  await assert.rejects(send({ ...request, data: { ...request.data, recipientId: 'sender' } }),
    { code: 'invalid-argument' });
  services.records.set('meetings/meeting', { meetingMembers: ['sender'] });
  await assert.rejects(send(request), { code: 'permission-denied' });
  assert.equal(services.messages.length, 0);
});

test('sends one iOS alert to the selected member and limits repeated sends', async () => {
  const services = fakeServices();
  let currentTime = 100_000;
  const send = createMeetingMemberNotificationHandler({ ...services, now: () => currentTime });

  assert.deepEqual(await send(request), { sent: true });
  assert.equal(services.messages.length, 1);
  assert.equal(services.messages[0].token, 'recipient-token');
  assert.equal(services.messages[0].notification.body, '곧 시작해요. 서둘러 주세요!');
  assert.deepEqual(services.messages[0].data, { route: 'meetingView', meetingId: 'meeting' });
  assert.equal(services.messages[0].apns.payload.aps.sound, 'default');

  await assert.rejects(send(request), { code: 'resource-exhausted' });
  assert.equal(services.messages.length, 1);
  currentTime += 30_000;
  assert.deepEqual(await send(request), { sent: true });
});

test('removes an invalid token and releases the cooldown for a replacement token', async () => {
  const services = fakeServices();
  const send = createMeetingMemberNotificationHandler(services);
  services.setSendError({ code: 'messaging/registration-token-not-registered' });

  await assert.rejects(send(request), { code: 'failed-precondition' });
  assert.equal(services.records.get('users/recipient').fcmToken, undefined);
  assert.equal([...services.records.keys()].some((key) => key.startsWith('_meetingNotificationCooldowns/')), false);

  services.records.set('users/recipient', { fcmToken: 'new-token', loginStatus: true });
  services.setSendError(null);
  assert.deepEqual(await send(request), { sent: true });
  assert.equal(services.messages[0].token, 'new-token');
});

test('releases the cooldown after a temporary FCM failure', async () => {
  const services = fakeServices();
  const send = createMeetingMemberNotificationHandler(services);
  services.setSendError(new Error('temporary failure'));

  await assert.rejects(send(request), { code: 'unavailable' });
  services.setSendError(null);
  assert.deepEqual(await send(request), { sent: true });
});
