const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp(); // Firebase Admin SDK 초기화

const db = admin.firestore(); // Firestore 인스턴스 가져오기

// 친구 요청 알림 함수 (Firestore에 friendRequests 문서가 생성될 때)
exports.sendFriendRequestNotification = functions.firestore
    .onDocumentCreated('friendRequests/{requestId}', async (event) => {
      const requestData = event.data.data(); // 변경된 부분: snapshot -> event.data
      const toUserID = requestData.toUserID;
      const fromUserName = requestData.fromUserName;

      if (!toUserID || !fromUserName) {
        console.log('필수 데이터 누락');
        return null;
      }

      try {
        // Firestore에서 요청 받은 사용자의 FCM 토큰 가져오기
        const userDoc = await db.collection('users').doc(toUserID).get();
        if (!userDoc.exists) {
          console.log('수신자 정보를 찾을 수 없음');
          return null;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (!fcmToken) {
          console.log('FCM 토큰이 없음');
          return null;
        }

        // FCM 메시지 구성
        const message = {
          notification: {
            title: '친구 요청',
            body: `${fromUserName}님이 친구 요청을 보냈습니다!`,
          },
          token: fcmToken,
        };

        // FCM을 통해 푸시 알림 전송
        const response = await admin.messaging().send(message);
        console.log('푸시 알림 전송 성공:', response);

        return null;
      } catch (error) {
        console.error('푸시 알림 전송 실패:', error);
        return null;
      }
    });
