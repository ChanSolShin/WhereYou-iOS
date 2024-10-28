//  FriendListViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/29/24.
//
import FirebaseFirestore
import FirebaseAuth
import Combine

class FriendListViewModel: ObservableObject {
    @Published var friends: [FriendModel] = []
    @Published var pendingRequests: [FriendRequestModel] = []
    
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    
    private var db = Firestore.firestore()
    private var currentUserID: String? {
        return Auth.auth().currentUser?.uid
    }
    private var currentUserName: String? // 사용자 이름을 저장할 변수
    
    init() {
        fetchCurrentUserName() // 사용자 이름 가져오기
        fetchFriends()
        fetchPendingRequests()
    }
    
    private func fetchCurrentUserName() {
        guard let userID = currentUserID else { return }
        
        db.collection("users").document(userID).getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                self.currentUserName = data?["name"] as? String // 사용자 이름 가져오기
            } else {
                print("현재 사용자 정보 가져오기 실패: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    func fetchFriends() {
        guard let userID = currentUserID else { return }
        
        db.collection("users").document(userID).getDocument { (document, error) in
            guard let document = document, document.exists else {
                print("No documents")
                return
            }
            let data = document.data()
            let friendIDs = data?["friends"] as? [String] ?? []
            
            let dispatchGroup = DispatchGroup()
            self.friends.removeAll()
            
            for friendID in friendIDs {
                dispatchGroup.enter()
                self.db.collection("users").document(friendID).getDocument { (friendDocument, error) in
                    if let friendDocument = friendDocument, friendDocument.exists {
                        let friendData = friendDocument.data()
                        let friend = FriendModel(
                            id: friendID,
                            name: friendData?["name"] as? String ?? "Unknown",
                            email: friendData?["email"] as? String ?? "",
                            phoneNumber: friendData?["phoneNumber"] as? String ?? "",
                            birthday: friendData?["birthday"] as? String ?? ""
                        )
                        self.friends.append(friend)
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.friends.sort { $0.name < $1.name } // 친구 이름 정렬
            }
        }
    }
    
    func fetchPendingRequests() {
        guard let userID = currentUserID else { return }
        
        db.collection("friendRequests")
            .whereField("toUserID", isEqualTo: userID) // 현재 사용자에게 온 요청만 필터링
            .whereField("status", isEqualTo: "pending")
            .getDocuments { (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("No pending requests")
                    return
                }
                self.pendingRequests = documents.compactMap { queryDocumentSnapshot -> FriendRequestModel? in
                    let data = queryDocumentSnapshot.data()
                    let id = queryDocumentSnapshot.documentID
                    let fromUserID = data["fromUserID"] as? String ?? ""
                    let fromUserName = data["fromUserName"] as? String ?? "Unknown"
                    let toUserID = data["toUserID"] as? String ?? ""
                    let status = data["status"] as? String ?? "pending"
                    // 요청이 현재 사용자에게 온 경우만 반환
                    return toUserID == userID ? FriendRequestModel(id: id, fromUserID: fromUserID, fromUserName: fromUserName, toUserID: toUserID, status: status) : nil
                }
            }
    }
    
    func sendFriendRequest(toEmail email: String) {
        guard let userID = currentUserID, let userName = currentUserName else { return }
        
        // 자신에게 친구 요청을 보낼 수 없는 경우
        if email == Auth.auth().currentUser?.email {
            DispatchQueue.main.async {
                self.alertMessage = "자신에게 친구 요청을 보낼 수 없습니다."
                self.showAlert = true
            }
            return
        }
        
        // 이미 친구인 경우
        if friends.contains(where: { $0.email == email }) {
            DispatchQueue.main.async {
                self.alertMessage = "이미 등록된 친구입니다."
                self.showAlert = true
            }
            return
        }
        
        // 가입된 회원을 찾기 위해 users 컬렉션 조회
        db.collection("users").whereField("email", isEqualTo: email).getDocuments { (snapshot, error) in
            guard let document = snapshot?.documents.first else {
                DispatchQueue.main.async {
                    self.alertMessage = "회원정보를 찾을 수 없습니다."
                    self.showAlert = true
                }
                return
            }
            let recipientID = document.documentID
            
            // 친구 요청이 이미 보내진 경우 확인
            self.db.collection("friendRequests")
                .whereField("fromUserID", isEqualTo: userID)
                .whereField("toUserID", isEqualTo: recipientID)
                .whereField("status", isEqualTo: "pending")
                .getDocuments { (snapshot, error) in
                    if let documents = snapshot?.documents, !documents.isEmpty {
                        DispatchQueue.main.async {
                            self.alertMessage = "해당 사용자에게 친구 요청을 보낸 상태입니다."
                            self.showAlert = true
                        }
                        return
                    }
                    
                    // 상대방이 보낸 친구 요청이 있는 경우 확인
                    self.db.collection("friendRequests")
                        .whereField("fromUserID", isEqualTo: recipientID)
                        .whereField("toUserID", isEqualTo: userID)
                        .whereField("status", isEqualTo: "pending")
                        .getDocuments { (snapshot, error) in
                            if let documents = snapshot?.documents, !documents.isEmpty {
                                DispatchQueue.main.async {
                                    self.alertMessage = "해당 사용자에게 친구 요청이 온 상태입니다."
                                    self.showAlert = true
                                }
                                return
                            }
                            
                            // 친구 요청 추가
                            self.db.collection("friendRequests").addDocument(data: [
                                "fromUserID": userID,
                                "fromUserName": userName,
                                "toUserID": recipientID,
                                "status": "pending"
                            ]) { error in
                                if let error = error {
                                    print("친구 요청 전송에 실패했습니다: \(error)")
                                } else {
                                    DispatchQueue.main.async {
                                        self.alertMessage = "친구 요청을 보냈습니다!"
                                        self.showAlert = true
                                    }
                                }
                            }
                        }
                }
        }
    }
    
    func acceptFriendRequest(requestID: String, fromUserID: String) {
        guard let userID = currentUserID else { return }
        
        let group = DispatchGroup()
        
        // 현재 사용자 친구 목록에 추가
        group.enter()
        db.collection("users").document(userID).updateData([
            "friends": FieldValue.arrayUnion([fromUserID])
        ]) { error in
            if let error = error {
                print("친구 목록에 추가하는 데 실패했습니다: \(error)")
            }
            group.leave()
        }
        
        // 상대방 친구 목록에 추가
        group.enter()
        db.collection("users").document(fromUserID).updateData([
            "friends": FieldValue.arrayUnion([userID])
        ]) { error in
            if let error = error {
                print("상대방 친구 목록에 추가하는 데 실패했습니다: \(error)")
            }
            group.leave()
        }
        
        // 친구 요청 상태 업데이트 및 삭제
        group.notify(queue: .main) {
            // 친구 요청 상태 업데이트
            self.db.collection("friendRequests").document(requestID).updateData([
                "status": "accepted"
            ]) { error in
                if let error = error {
                    print("친구 요청 상태 업데이트에 실패했습니다: \(error)")
                } else {
                    // 친구 요청 삭제
                    self.db.collection("friendRequests").document(requestID).delete() { error in
                        if let error = error {
                            print("친구 요청 삭제에 실패했습니다: \(error)")
                        } else {
                            // 친구 목록 갱신
                            self.fetchFriends()
                        }
                    }
                }
            }
        }
    }
    
    func rejectFriendRequest(requestID: String) {
        db.collection("friendRequests").document(requestID).updateData([
            "status": "rejected"
        ])
    }
    
    // 친구 삭제
    func removeFriend(friendID: String) {
        guard let userID = currentUserID else { return }
        
        let group = DispatchGroup()
        
        // 현재 사용자 친구 목록에서 삭제
        group.enter()
        db.collection("users").document(userID).updateData([
            "friends": FieldValue.arrayRemove([friendID])
        ]) { error in
            if let error = error {
                print("친구 목록에서 삭제하는 데 실패했습니다: \(error)")
            }
            group.leave()
        }
        
        // 삭제당한 친구의 친구 목록에서 현재 사용자 제거
        group.enter()
        db.collection("users").document(friendID).updateData([
            "friends": FieldValue.arrayRemove([userID])
        ]) { error in
            if let error = error {
                print("상대방 친구 목록에서 삭제하는 데 실패했습니다: \(error)")
            }
            group.leave()
        }
        
        // 모든 작업이 완료되면 친구 목록 갱신
        group.notify(queue: .main) {
            self.fetchFriends()
        }
    }
}
