// 회원정보 입력 전 이탈한 임시 계정 정리
// - 이메일 가입: 전화번호 인증 후 이메일/비밀번호 연결 전 이탈 (5분)
// - 소셜 가입: 소셜 로그인 후 회원정보 입력 전 이탈 (30분, tempUsers.provider 있음)
// users 문서가 없으면 가입 미완료로 보고 Auth 계정과 tempUsers 문서를 삭제
// 남겨 두면 해당 소셜 계정을 나중에 마이페이지에서 기존 계정에 연결할 수 없음

const EMAIL_SIGNUP_TTL_MS = 5 * 60 * 1000;
const SOCIAL_SIGNUP_TTL_MS = 30 * 60 * 1000;

function tempAccountTtl(data) {
  return data.provider ? SOCIAL_SIGNUP_TTL_MS : EMAIL_SIGNUP_TTL_MS;
}

async function cleanupTempAccounts({ db, auth, now = Date.now(), logger = console }) {
  const snapshot = await db.collection('tempUsers').get();
  const deletedUids = [];

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const createdAt = data.createdAt?.toDate?.();
    if (!createdAt || now - createdAt.getTime() < tempAccountTtl(data)) continue;

    const uid = doc.id;
    try {
      const userDoc = await db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        try {
          await auth.deleteUser(uid);
        } catch (error) {
          // 앱에서 가입 취소로 이미 삭제한 경우
          if (error.code !== 'auth/user-not-found') throw error;
        }
        deletedUids.push(uid);
        logger.log(`🗑️ 임시 계정 삭제됨: ${uid}`);
      }
      // 가입 완료 후 남은 문서이거나 계정을 삭제한 경우 모두 정리
      await doc.ref.delete();
    } catch (error) {
      logger.error(`❌ 임시 계정 정리 실패: ${uid}`, error);
    }
  }

  return { deletedUids };
}

module.exports = {
  EMAIL_SIGNUP_TTL_MS,
  SOCIAL_SIGNUP_TTL_MS,
  cleanupTempAccounts,
};
