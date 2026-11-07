const test = require('node:test');
const assert = require('node:assert/strict');
const {
  EMAIL_SIGNUP_TTL_MS,
  SOCIAL_SIGNUP_TTL_MS,
  cleanupTempAccounts,
  createDiscardTempAccountHandler,
} = require('../tempAccountCleanup');

const NOW = Date.UTC(2026, 10, 3, 12, 0, 0);
const minutesAgo = (minutes) => ({ toDate: () => new Date(NOW - minutes * 60 * 1000) });

function fakeServices({ tempUsers = {}, users = [], authUsers = [] }) {
  const tempRecords = new Map(Object.entries(tempUsers));
  const userDocs = new Set(users);
  const authRecords = new Set(authUsers);
  const db = {
    collection(name) {
      if (name === 'tempUsers') {
        return {
          async get() {
            return {
              docs: [...tempRecords.entries()].map(([id, data]) => ({
                id,
                data: () => data,
                ref: { delete: async () => { tempRecords.delete(id); } },
              })),
            };
          },
          doc: (id) => ({ delete: async () => { tempRecords.delete(id); } }),
        };
      }
      return { doc: (id) => ({ get: async () => ({ exists: userDocs.has(id) }) }) };
    },
  };
  const auth = {
    async deleteUser(uid) {
      if (!authRecords.has(uid)) {
        const error = new Error('not found');
        error.code = 'auth/user-not-found';
        throw error;
      }
      authRecords.delete(uid);
    },
  };
  const logger = { log() {}, error() {} };
  return { db, auth, logger, tempRecords, authRecords };
}

test('deletes abandoned email signups after 5 minutes and social signups after 30 minutes', async () => {
  const services = fakeServices({
    tempUsers: {
      emailOld: { createdAt: minutesAgo(6) },
      emailNew: { createdAt: minutesAgo(4) },
      socialOld: { createdAt: minutesAgo(31), provider: 'google.com' },
      socialNew: { createdAt: minutesAgo(10), provider: 'apple.com' },
    },
    authUsers: ['emailOld', 'emailNew', 'socialOld', 'socialNew'],
  });

  const { deletedUids } = await cleanupTempAccounts({ ...services, now: NOW });

  assert.deepEqual(deletedUids.sort(), ['emailOld', 'socialOld']);
  assert.deepEqual([...services.authRecords].sort(), ['emailNew', 'socialNew']);
  assert.deepEqual([...services.tempRecords.keys()].sort(), ['emailNew', 'socialNew']);
  assert.equal(EMAIL_SIGNUP_TTL_MS < SOCIAL_SIGNUP_TTL_MS, true);
});

test('keeps accounts that finished signup and only removes the leftover temp document', async () => {
  const services = fakeServices({
    tempUsers: { done: { createdAt: minutesAgo(60), provider: 'google.com' } },
    users: ['done'],
    authUsers: ['done'],
  });

  const { deletedUids } = await cleanupTempAccounts({ ...services, now: NOW });

  assert.deepEqual(deletedUids, []);
  assert.equal(services.authRecords.has('done'), true);
  assert.equal(services.tempRecords.has('done'), false);
});

test('removes the temp document when the app already deleted the account', async () => {
  const services = fakeServices({
    tempUsers: { canceled: { createdAt: minutesAgo(40), provider: 'apple.com' } },
  });

  const { deletedUids } = await cleanupTempAccounts({ ...services, now: NOW });

  assert.deepEqual(deletedUids, ['canceled']);
  assert.equal(services.tempRecords.has('canceled'), false);
});

test('a failure on one account does not stop the rest', async () => {
  const services = fakeServices({
    tempUsers: {
      broken: { createdAt: minutesAgo(10) },
      ok: { createdAt: minutesAgo(10) },
    },
    authUsers: ['broken', 'ok'],
  });
  const deleteUser = services.auth.deleteUser;
  services.auth.deleteUser = async (uid) => {
    if (uid === 'broken') throw Object.assign(new Error('internal'), { code: 'auth/internal-error' });
    return deleteUser(uid);
  };

  const { deletedUids } = await cleanupTempAccounts({ ...services, now: NOW });

  assert.deepEqual(deletedUids, ['ok']);
  assert.equal(services.tempRecords.has('broken'), true);
});

test('discard deletes the caller temp account immediately', async () => {
  const services = fakeServices({
    tempUsers: { temp: { createdAt: minutesAgo(1), provider: 'google.com' } },
    authUsers: ['temp'],
  });
  const handler = createDiscardTempAccountHandler(services);

  const result = await handler({ auth: { uid: 'temp' } });

  assert.deepEqual(result, { deleted: true });
  assert.equal(services.authRecords.has('temp'), false);
  assert.equal(services.tempRecords.has('temp'), false);
});

test('discard never deletes an account that finished signup', async () => {
  const services = fakeServices({ users: ['member'], authUsers: ['member'] });
  const handler = createDiscardTempAccountHandler(services);

  await assert.rejects(handler({ auth: { uid: 'member' } }), { code: 'failed-precondition' });
  assert.equal(services.authRecords.has('member'), true);
});

test('discard requires sign-in and tolerates an already deleted account', async () => {
  const services = fakeServices({ tempUsers: { gone: { createdAt: minutesAgo(1) } } });
  const handler = createDiscardTempAccountHandler(services);

  await assert.rejects(handler({}), { code: 'unauthenticated' });
  assert.deepEqual(await handler({ auth: { uid: 'gone' } }), { deleted: true });
  assert.equal(services.tempRecords.has('gone'), false);
});
