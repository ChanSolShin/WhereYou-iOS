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

// ✅ 1분마다 실행하여 모임 시간을 확인하고, 위치 추적 활성화 여부를 변경 및 알림 전송
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

            if (currentDate >= trackingStart && currentDate <= trackingEnd) {
                // ✅ 3시간 전 ~ 1시간 후: 위치 추적 활성화
                if (!meetingData.isLocationTrackingEnabled) {
                    await doc.ref.update({ isLocationTrackingEnabled: true });
                    console.log(`모임 ${doc.id}: 위치 추적 활성화 (true)`);

                    // 위치 추적 활성화 후 모임 멤버들에게 알림 전송
                    const meetingName = meetingData.meetingName || "알 수 없는 모임";
                    const meetingMembers = meetingData.meetingMembers || [];
                    const meetingAddress = meetingData.meetingAddress || "주소 정보 없음";
                    
                    if (meetingMembers.length === 0) {
                        console.log(`⚠️ 모임 ${doc.id}에 멤버가 없습니다.`);
                        return null;
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
                        return null;
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
                    } catch (error) {
                        console.error(`❌ 모임 ${doc.id} - 푸시 알림 전송 실패:`, error);
                    }
                }
            } else {
                // ❌ 범위를 벗어나면 위치 추적 비활성화
                if (meetingData.isLocationTrackingEnabled) {
                    await doc.ref.update({ isLocationTrackingEnabled: false });
                    console.log(`모임 ${doc.id}: 위치 추적 비활성화 (false)`);
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
