const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');
const { getFirestore } = require("firebase-admin/firestore");
const { onSchedule } = require('firebase-functions/scheduler'); // V2에서는 onSchedule 사용
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');

admin.initializeApp(); // Firebase Admin SDK 초기화
const db = admin.firestore(); // Firestore 인스턴스 가져오기
const messaging = admin.messaging(); // Firebase Cloud Messaging 인스턴스 가져오기

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
            token: fcmToken,
        };

        await messaging.send(message);  // admin.messaging()으로 수정
        console.log('푸시 알림 전송 성공');
    } catch (error) {
        console.error('푸시 알림 전송 실패:', error);
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
            token: fcmToken,
        };

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
                await doc.ref.delete();
                console.log(`🗑 모임 ${doc.id} 삭제 완료`);
            }
        }));

    } catch (error) {
        console.error("❌ Firestore에서 모임 삭제 중 오류 발생:", error);
    }

    return null;
});
