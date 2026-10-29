const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');
const { getFirestore } = require("firebase-admin/firestore");
const { onSchedule } = require('firebase-functions/scheduler'); // V2에서는 onSchedule 사용
const { onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { onCall } = require('firebase-functions/v2/https');
const {
  createMeetingMemberNotificationHandler,
  cleanupExpiredMeetingNotificationCooldowns,
} = require('./meetingMemberNotification');
const {
  createSendMeetingChatMessageHandler,
  createMarkMeetingChatReadHandler,
  createAcceptMeetingInvitationHandler,
  createCompleteLegacyMeetingInvitationHandler,
} = require('./meetingChat');
const { getAppBadgeCount, badgeApns, createSendChatNotificationHandler } = require('./appBadge');

admin.initializeApp({
  databaseURL: "https://meetingapp-2985d-default-rtdb.firebaseio.com"
});

const db = getFirestore(); // Firestore 인스턴스 가져오기
const messaging = admin.messaging(); // Firebase Cloud Messaging 인스턴스 가져오기

exports.sendMeetingChatMessage = onCall(
  { region: 'us-central1' }, createSendMeetingChatMessageHandler({ db })
);
exports.markMeetingChatRead = onCall(
  { region: 'us-central1' }, createMarkMeetingChatReadHandler({ db })
);
// Keep the deployed trigger name so one message does not invoke two push functions.
// The push now includes the message preview, chat deep link, and total icon badge.
exports.sendMeetingChatBadge = functions.firestore.onDocumentCreated(
  { document: 'meetings/{meetingId}/messages/{messageId}', region: 'us-central1' },
  createSendChatNotificationHandler({ db, messaging })
);
exports.acceptMeetingInvitation = onCall(
  { region: 'us-central1' }, createAcceptMeetingInvitationHandler({ db })
);

// Older app versions mark an invitation accepted and then update the meeting
// directly. Complete the membership change here when direct self-joins are denied.
exports.completeLegacyMeetingInvitation = onDocumentUpdated(
  { document: 'meetingRequests/{requestId}', region: 'us-central1' },
  createCompleteLegacyMeetingInvitationHandler({ db })
);

// Deleting a Firestore parent does not delete its subcollections. The parent is
// already gone when this runs, so rules immediately deny former members access.
exports.deleteMeetingChat = onDocumentDeleted(
  { document: 'meetings/{meetingId}', region: 'us-central1', retry: true, timeoutSeconds: 540 },
  async (event) => {
    if (event.data) await db.recursiveDelete(event.data.ref);
  }
);

// 모임 멤버 한 명에게만 보내는 빠른 알림. 발신자와 수신자는 서버에서 다시 검증한다.
exports.sendMeetingMemberNotification = onCall(
  { region: 'us-central1' },
  createMeetingMemberNotificationHandler({ db, messaging })
);

exports.cleanupExpiredMeetingNotificationCooldowns = onSchedule(
  { schedule: 'every 1 minutes', region: 'us-central1' },
  async () => {
    const { deleted } = await cleanupExpiredMeetingNotificationCooldowns({ db });
    if (deleted > 0) console.log(`🗑 만료된 모임 알림 제한 기록 ${deleted}개 삭제`);
  }
);

// ✅ 친구 요청 알림 함수 (Firestore에 friendRequests 문서가 생성될 때)
exports.sendFriendRequestNotification = functions.firestore.onDocumentCreated('friendRequests/{requestId}', async (event) => {
    const requestData = event.data.data();
    const toUserID = requestData.toUserID;
    const fromUserName = requestData.fromUserName;

    if (!toUserID || !fromUserName) {
        console.log('필수 데이터 누락');
        return null;
    }

    try {
        const userDoc = await db.collection('users').doc(toUserID).get();
        if (!userDoc.exists) return console.log('수신자 정보를 찾을 수 없음');

        const fcmToken = userDoc.data()?.fcmToken;
        if (!fcmToken) return console.log('FCM 토큰이 없음');

        const message = {
          notification: {
            title: '웨어유',
            body: `${fromUserName}님이 친구 요청을 보냈습니다!`,
          },
          data: {
            route: "friendRequests"
          },
          token: fcmToken,
        };

        try {
          message.apns = badgeApns(await getAppBadgeCount(db, toUserID));
        } catch (error) {
          console.error('친구 요청 뱃지 계산 실패:', error);
        }

        await messaging.send(message);  // admin.messaging()으로 수정
        console.log('푸시 알림 전송 성공');
    } catch (error) {
        console.error('푸시 알림 전송 실패:', error);
    }

    return null;
});

exports.cleanupOrphanedRealtimeMeetings = onSchedule("every 10 minutes", async (event) => {
  console.log("🧹 [cleanupOrphanedRealtimeMeetings] 호출됨");

  try {
    // 1. Firestore의 meetings ID 목록 가져오기
    const firestoreSnapshot = await db.collection("meetings").get();
    const firestoreMeetingIds = firestoreSnapshot.docs.map(doc => doc.id);
    const firestoreIdSet = new Set(firestoreMeetingIds);
    console.log(`📄 Firestore meeting 수: ${firestoreMeetingIds.length}`);

    // 2. RealtimeDB의 meetings key 목록 가져오기
    const rtdbSnapshot = await admin.database().ref("meetings").once("value");
    const rtdbData = rtdbSnapshot.val();

    if (!rtdbData) {
      console.log("📦 RealtimeDB meetings 경로가 비어 있음");
      return;
    }

    const rtdbMeetingIds = Object.keys(rtdbData);
    console.log(`⚡️ RealtimeDB meeting 수: ${rtdbMeetingIds.length}`);

    // 3. Firestore에는 없지만 RealtimeDB에만 있는 ID 목록 추출
    const orphanedIds = rtdbMeetingIds.filter(id => !firestoreIdSet.has(id));

    if (orphanedIds.length === 0) {
      console.log("✅ 정리할 orphaned meeting 없음");
      return;
    }

    // 4. 해당 orphaned ID 삭제
    for (const id of orphanedIds) {
      try {
        const rootRef = admin.database().ref();
        const meetingRef = rootRef.child(`meetings/${id}`);
        console.log("🧪 삭제할 경로:", meetingRef.toString());

        const snapshot = await meetingRef.once('value');
        if (snapshot.exists()) {
          await meetingRef.remove();
          console.log(`✅ RealtimeDB에서 orphaned meeting 삭제 완료: ${id}`);
        } else {
          console.log(`⚠️ RealtimeDB에 존재하지 않음 (스킵): ${id}`);
        }
      } catch (err) {
        console.error(`❌ 삭제 실패 (${id}):`, err);
      }
    }
  } catch (err) {
    console.error("❌ orphaned 데이터 정리 중 오류 발생:", err);
  }

  return null;
});

// ✅ 모임 초대 요청 알림 함수 (Firestore에 meetingRequests 문서가 생성될 때)
exports.sendMeetingInviteNotification = functions.firestore.onDocumentCreated('meetingRequests/{requestId}', async (event) => {
    const requestData = event.data.data();
    const toUserID = requestData.toUserID;
    const fromUserName = requestData.fromUserName;
    const meetingName = requestData.meetingName;

    if (!toUserID || !fromUserName || !meetingName) {
        console.log('필수 데이터 누락');
        return null;
    }

    try {
        const userDoc = await db.collection('users').doc(toUserID).get();
        if (!userDoc.exists) return console.log('수신자 정보를 찾을 수 없음');

        const fcmToken = userDoc.data()?.fcmToken;
        if (!fcmToken) return console.log('FCM 토큰이 없음');

        const message = {
          notification: {
            title: '웨어유',
            body: `${fromUserName}님이 '${meetingName}' 모임에 초대했습니다!`,
          },
          data: {
            route: "meetingRequests"
          },
          token: fcmToken,
        };

        try {
          message.apns = badgeApns(await getAppBadgeCount(db, toUserID));
        } catch (error) {
          console.error('모임 요청 뱃지 계산 실패:', error);
        }

        await messaging.send(message);  // admin.messaging()으로 수정
        console.log('푸시 알림 전송 성공');
    } catch (error) {
        console.error('푸시 알림 전송 실패:', error);
    }

    return null;
});

exports.updateLocationTrackingStatus = onSchedule('every 1 minutes', async (event) => {
    const currentDate = new Date();
    const koreaTimeOffset = 9 * 60; // UTC+9 (한국 시간)
    currentDate.setMinutes(currentDate.getMinutes() + currentDate.getTimezoneOffset() + koreaTimeOffset);

    try {
        const meetingsSnapshot = await db.collection('meetings').get();

        await Promise.all(meetingsSnapshot.docs.map(async (doc) => {
            const meetingData = doc.data();

            if (!meetingData.meetingDate || !meetingData.meetingDate.toDate) {
                console.log(`meetingDate가 올바르지 않음: ${JSON.stringify(meetingData)}`);
                return;
            }

            const meetingDate = meetingData.meetingDate.toDate();
            const meetingDateKST = new Date(meetingDate);
            meetingDateKST.setMinutes(meetingDateKST.getMinutes() + meetingDateKST.getTimezoneOffset() + koreaTimeOffset);

            const trackingStart = new Date(meetingDateKST);
            trackingStart.setHours(trackingStart.getHours() - 3); // 모임 3시간 전

            const trackingEnd = new Date(meetingDateKST);
            trackingEnd.setHours(trackingEnd.getHours() + 1); // 모임 1시간 후

            // 위치 추적 범위에 있는지 확인
            if (currentDate >= trackingStart && currentDate <= trackingEnd) {
                // ✅ 위치 추적이 꺼져 있다면 활성화하고, 그때만 알림 전송
                if (!meetingData.isLocationTrackingEnabled) {
                    await doc.ref.update({ isLocationTrackingEnabled: true });
                    console.log(`모임 ${doc.id}: 위치 추적 활성화 (true)`);

                    // 🔹 위치 추적이 켜진 순간이므로 알림 전송
                    const meetingName = meetingData.meetingName || "알 수 없는 모임";
                    const meetingMembers = meetingData.meetingMembers || [];

                    if (meetingMembers.length === 0) {
                        console.log(`⚠️ 모임 ${doc.id}에 멤버가 없습니다.`);
                        return;
                    }

                    let tokens = [];

                    // FCM 토큰 가져오기
                    await Promise.all(meetingMembers.map(async (memberUID) => {
                        try {
                            const userDoc = await db.collection("users").doc(memberUID).get();
                            if (!userDoc.exists) {
                                console.log(`⚠️ 사용자 ${memberUID}의 데이터가 존재하지 않음`);
                                return;
                            }

                            const fcmToken = userDoc.data()?.fcmToken;
                            if (fcmToken) {
                                tokens.push(fcmToken);  // FCM 토큰 수집
                            } else {
                                console.log(`⚠️ 사용자 ${memberUID}의 FCM 토큰이 없음`);
                            }
                        } catch (error) {
                            console.error(`❌ 사용자 ${memberUID} 데이터 가져오기 실패:`, error);
                        }
                    }));

                    if (tokens.length === 0) {
                        console.log(`⚠️ 모임 ${doc.id} 멤버들에게 보낼 FCM 토큰이 없음`);
                        return;
                    }

                    // 이미 알림이 전송된 경우 추가로 알림을 보내지 않도록 처리
                    if (meetingData.isNotificationSent) {
                        console.log(`⚠️ 모임 ${doc.id}: 이미 알림이 전송되었습니다.`);
                        return;  // 알림을 이미 전송했으므로 더 이상 보내지 않음
                    }

                    // 각 멤버에게 FCM 메시지 전송
                    const message = {
                      notification: {
                        title: "웨어유",
                        body: `지금부터 ${meetingName} 멤버의 위치 조회가 가능합니다!`,
                      },
                      data: {
                        route: "meetingView",
                        meetingId: doc.id
                      },
                    };

                    try {
                        // 각 멤버에게 개별적으로 메시지 전송
                        for (const token of tokens) {
                            message.token = token;  // 각 토큰에 대해 메시지 전송
                            await messaging.send(message);
                        }

                        console.log(`✅ 모임 ${doc.id} - 푸시 알림 전송 성공`);
                        await doc.ref.update({ isNotificationSent: true }); // 알림 전송 후 상태 업데이트
                    } catch (error) {
                        console.error(`❌ 모임 ${doc.id} - 푸시 알림 전송 실패:`, error);
                    }
                }
            } else {
                // 위치 추적 범위를 벗어나면 위치 추적 비활성화
                if (meetingData.isLocationTrackingEnabled) {
                    await doc.ref.update({ isLocationTrackingEnabled: false });
                    console.log(`모임 ${doc.id}: 위치 추적 비활성화 (false)`);
                }

                // 위치 추적 비활성화 상태에서 isNotificationSent 필드 리셋 (필요에 따라)
                if (meetingData.isNotificationSent) {
                    await doc.ref.update({ isNotificationSent: false });
                    console.log(`모임 ${doc.id}: 알림 상태 리셋`);
                }
            }
        }));
    } catch (error) {
        console.error('Firestore에서 모임 정보를 가져오는 중 오류 발생:', error);
    }

    return null;
});

// ✅ 모임에 새로운 멤버가 추가되었을 때 알림 전송
exports.notifyMemberAdded = functions.firestore.onDocumentUpdated(
    { document: 'meetings/{meetingId}' }, // Firestore 문서 변경 감지
    async (event) => {
        const beforeData = event.data.before.data();
        const afterData = event.data.after.data();

        const beforeMembers = beforeData?.meetingMembers || [];
        const afterMembers = afterData?.meetingMembers || [];

        const newMembers = afterMembers.filter(member => !beforeMembers.includes(member));

        if (newMembers.length === 0) {
            console.log('새로운 멤버가 없습니다.');
            return null;
        }

        const existingMembers = afterMembers.filter(member => !newMembers.includes(member));
        const meetingName = afterData.meetingName || '알 수 없는 모임';

        const fcmTokens = [];

        for (const memberId of existingMembers) {
            try {
                const userDoc = await db.collection('users').doc(memberId).get();
                if (!userDoc.exists) continue;
                const fcmToken = userDoc.data()?.fcmToken;
                if (fcmToken) fcmTokens.push(fcmToken);
            } catch (error) {
                console.error(`사용자 ${memberId} 데이터 가져오기 실패:`, error);
            }
        }

        if (fcmTokens.length === 0) {
            console.log('❌ FCM 토큰이 없어 알림을 전송할 수 없습니다.');
            return null;
        }

        try {
            // ✅ UID를 사용자 이름으로 변환
            const newMemberNames = await Promise.all(
                newMembers.map(async (uid) => {
                    try {
                        const userDoc = await db.collection('users').doc(uid).get();
                        return userDoc.exists ? userDoc.data().name : uid; // 이름이 없으면 UID 그대로
                    } catch (error) {
                        console.error(`사용자 ${uid} 데이터 가져오기 실패:`, error);
                        return uid; // 에러 발생 시 UID 그대로 반환
                    }
                })
            );

            // ✅ FCM 토큰을 500개씩 나누어 전송 (Firebase 제한)
            const chunkSize = 500;
            for (let i = 0; i < fcmTokens.length; i += chunkSize) {
                const tokenChunk = fcmTokens.slice(i, i + chunkSize);

                for (const token of tokenChunk) {
                    const message = {
                      token: token,
                      notification: {
                        title: '웨어유',
                        body: `${newMemberNames.join(', ')}님이 ${meetingName} 모임에 참여하였습니다!`,
                      },
                      data: {
                        route: "meetingView",
                        meetingId: event.params.meetingId
                      }
                    };

                    // ✅ `send` 사용 (단건 메시지 전송)
                    const response = await messaging.send(message);
                    console.log(`✅ 푸시 알림 전송 성공 (Token: ${token}):`, response);
                }
            }
        } catch (error) {
            console.error('❌ 푸시 알림 전송 실패:', error);
        }

        return null;
    }
);

// ✅ 모임 정보 수정 시 알림 전송
exports.notifyMeetingUpdated = functions.firestore.onDocumentUpdated(
    { document: 'meetings/{meetingId}' },
    async (event) => {
        const beforeData = event.data.before.data();
        const afterData = event.data.after.data();

        // 변경 감지할 필드
        const fieldsToCheck = ['meetingAddress', 'meetingDate', 'meetingLocation'];
        const hasChanged = fieldsToCheck.some(field =>
            JSON.stringify(beforeData[field]) !== JSON.stringify(afterData[field])
        );

        if (!hasChanged) {
            console.log('📌 변경된 모임 정보가 없습니다.');
            return null;
        }

        const meetingName = afterData.meetingName || '알 수 없는 모임';
        const meetingMaster = afterData.meetingMaster;
        const meetingMembers = afterData.meetingMembers || [];

        // 모임장 제외한 멤버 필터링
        const targetMembers = meetingMembers.filter(uid => uid !== meetingMaster);
        if (targetMembers.length === 0) {
            console.log('📌 알림을 보낼 대상 멤버가 없습니다.');
            return null;
        }

        let tokens = [];
        
        // 🔹 FCM 토큰 가져오기
        await Promise.all(targetMembers.map(async (memberUID) => {
            try {
                const userDoc = await db.collection("users").doc(memberUID).get();
                if (!userDoc.exists) {
                    console.log(`⚠️ 사용자 ${memberUID}의 데이터가 존재하지 않음`);
                    return;
                }

                const fcmToken = userDoc.data()?.fcmToken;
                if (fcmToken) {
                    tokens.push(fcmToken);  // FCM 토큰 수집
                } else {
                    console.log(`⚠️ 사용자 ${memberUID}의 FCM 토큰이 없음`);
                }
            } catch (error) {
                console.error(`❌ 사용자 ${memberUID} 데이터 가져오기 실패:`, error);
            }
        }));

        if (tokens.length === 0) {
            console.log('⚠️ 전송할 FCM 토큰이 없습니다.');
            return null;
        }

        // 🔹 FCM 메시지 생성
        const message = {
          notification: {
            title: '웨어유',
            body: `${meetingName} 모임의 정보가 수정되었습니다!`,
          },
          data: {
            route: "meetingView",
            meetingId: event.params.meetingId
          },
        };

        try {
            // 🔹 각 멤버에게 개별적으로 메시지 전송
            for (const token of tokens) {
                message.token = token;
                await messaging.send(message);
            }

            console.log(`✅ '${meetingName}' 모임 - 푸시 알림 전송 성공`);
        } catch (error) {
            console.error(`❌ '${meetingName}' 모임 - 푸시 알림 전송 실패:`, error);
        }

        return null;
    }
);

exports.deleteExpiredMeetings = onSchedule("every 1 minutes", async (event) => {
    const currentDate = new Date();
    const koreaTimeOffset = 9 * 60; // UTC+9
    currentDate.setMinutes(currentDate.getMinutes() + currentDate.getTimezoneOffset() + koreaTimeOffset);

    try {
        // Firestore에서 모임들을 조회하고, meetingDate가 현재 시간보다 2시간 이전인 모임들 찾기
        const meetingsSnapshot = await db.collection("meetings").get();

        if (meetingsSnapshot.empty) {
            console.log("🔍 삭제할 만료된 모임 없음");
            return;
        }

        // 모든 모임을 검사하여, meetingDate + 2시간이 지나면 삭제
        await Promise.all(meetingsSnapshot.docs.map(async (doc) => {
            const meetingDate = doc.data().meetingDate.toDate(); // Firestore에서 가져온 meetingDate 변환 (UTC)
            const meetingDateKorea = new Date(meetingDate.getTime() + koreaTimeOffset * 60 * 1000); // 한국 시간으로 변환
            const deleteThreshold = new Date(meetingDateKorea); // 한국 시간 기준으로 2시간 후
            deleteThreshold.setHours(deleteThreshold.getHours() + 2); // 모임시간에 2시간 추가

            console.log("현재 시간:", currentDate);
            console.log("삭제 기준 시간 (meetingDate + 2시간):", deleteThreshold);

            // currentDate가 deleteThreshold보다 크면 삭제
            if (currentDate >= deleteThreshold) {
                const meetingId = doc.id;
 
                // Realtime Database 문서 삭제
                try {
                    await admin.database().ref(`meetings/${meetingId}`).remove();
                } catch (err) {
                    console.error(`❌ RealtimeDB 모임 삭제 실패 (${meetingId}):`, err);
                }
 
             // Firestore의 meetingRequests 컬렉션에서 관련 요청 삭제
             try {
                 const meetingRequestsSnapshot = await db.collection("meetingRequests")
                     .where("meetingID", "==", meetingId)
                     .get();
 
                 for (const requestDoc of meetingRequestsSnapshot.docs) {
                     await requestDoc.ref.delete();
                     console.log(`🗑 Firestore meetingRequests에서 요청 ${requestDoc.id} 삭제 완료`);
                 }
             } catch (err) {
                 console.error(`❌ Firestore meetingRequests 삭제 실패 (${meetingId}):`, err);
             }
 
                // Firestore 문서 삭제
                await doc.ref.delete();
                console.log(`🗑 Firestore에서 모임 ${meetingId} 삭제 완료`);
            }
        }));

    } catch (error) {
        console.error("❌ Firestore에서 모임 삭제 중 오류 발생:", error);
    }

    return null;
});


// 5분 지난 임시 계정 중 이메일이 없는 계정 삭제
exports.deleteUnlinkedTempAccounts = onSchedule("every 5 minutes", async (event) => {
    const now = new Date();
    const koreaTimeOffset = 9 * 60;
    now.setMinutes(now.getMinutes() + now.getTimezoneOffset() + koreaTimeOffset / (60 * 1000));

    const threshold = new Date(now.getTime() - 5 * 60 * 1000); // 5분 전

    try {
        const snapshot = await db.collection("tempUsers").get();

        for (const doc of snapshot.docs) {
            const data = doc.data();
            const createdAt = data.createdAt?.toDate?.();

            if (!createdAt || createdAt > threshold) continue;

            const uid = doc.id;

            const userRecord = await admin.auth().getUser(uid);

            // 이메일이 없으면 (링크 안됐으면) 삭제
            if (!userRecord.email) {
                await admin.auth().deleteUser(uid);
                await db.collection("tempUsers").doc(uid).delete();
                console.log(`🗑️ 임시 계정 삭제됨: ${uid}`);
            }
        }
    } catch (error) {
        console.error("❌ 임시 계정 삭제 중 오류 발생:", error);
    }

    return null;
});

// ✅ 멤버가 강퇴되면 RTDB 좌표 삭제
exports.removeKickedMemberLocation = functions.firestore.onDocumentUpdated(
  { document: 'meetings/{meetingId}' },
  async (event) => {
    const meetingId = event.params.meetingId;

    const beforeData = event.data.before.data() || {};
    const afterData  = event.data.after.data()  || {};

    const beforeMembers = beforeData.meetingMembers || [];
    const afterMembers  = afterData.meetingMembers  || [];

    // Firestore 배열에서 제거된 멤버 계산
    const removedMembers = beforeMembers.filter((m) => !afterMembers.includes(m));

    if (removedMembers.length === 0) {
      console.log(`제거된 멤버 없음: meetingId=${meetingId}`);
      return null;
    }

    console.log(`RTDB 좌표 정리 시작: meetingId=${meetingId}, removedMembers=${removedMembers.join(', ')}`);

    // 각 제거된 멤버의 RTDB 좌표 삭제
    for (const uid of removedMembers) {
      try {
        const ref = admin.database().ref(`meetings/${meetingId}/locations/${uid}`);
        const snap = await ref.get();
        if (snap.exists()) {
          await ref.remove();
          console.log(`✅ RTDB 좌표 삭제 완료: meetingId=${meetingId}, uid=${uid}`);
        } else {
          console.log(`ℹ️ RTDB 좌표 없음(스킵): meetingId=${meetingId}, uid=${uid}`);
        }
      } catch (err) {
        console.error(`❌ RTDB 좌표 삭제 실패: meetingId=${meetingId}, uid=${uid}`, err);
      }
    }

    return null;
  }
);
