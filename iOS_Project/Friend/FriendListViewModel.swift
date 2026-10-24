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
    @Published private(set) var isLoadingFriends = true
    @Published private(set) var friendsLoadError: String?
    @Published var pendingRequests: [FriendRequestModel] = []
    @Published var friendEmailInput: String = ""
    @Published var friendPhoneNumberInput: String = ""
    @Published var selectedCountry: CountryCode?
    
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    
    private var db = Firestore.firestore()
    public var currentUserID: String? {
        return Auth.auth().currentUser?.uid
    }
    var currentUserName: String?
    
    private var requestListener: ListenerRegistration?

    func getCurrentUserID() -> String? {
           return currentUserID
       }
    
    private var friendListener: ListenerRegistration?
    private var friendLoadGeneration = 0
    
    init() {
        fetchCurrentUserName()
        observeFriends()
        observePendingRequests()
    }

    func resetFriendEmailInput() {
        friendEmailInput = ""
    }

    func resetFriendPhoneInput() {
        friendPhoneNumberInput = ""
        selectedCountry = nil
    }
    
    private func fetchCurrentUserName() {
        guard let userID = currentUserID else { return }
        
        db.collection("users").document(userID).getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                self.currentUserName = data?["name"] as? String
            } else {
                print("현재 사용자 정보 가져오기 실패: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    func observeFriends() {
        friendListener?.remove()
        friendLoadGeneration += 1
        guard let userID = currentUserID else {
            friends = []
            isLoadingFriends = false
            friendsLoadError = "로그인 후 친구 목록을 확인할 수 있습니다."
            return
        }

        isLoadingFriends = friends.isEmpty
        friendsLoadError = nil

        friendListener = db.collection("users").document(userID).addSnapshotListener { [weak self] (snapshot, error) in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.friendLoadGeneration += 1
                let generation = self.friendLoadGeneration

                guard error == nil, let document = snapshot, document.exists else {
                    self.isLoadingFriends = false
                    self.friendsLoadError = "친구 목록을 불러오지 못했습니다."
                    return
                }

                let friendIDs = Array(Set(document.data()?["friends"] as? [String] ?? []))
                guard !friendIDs.isEmpty else {
                    self.friends = []
                    self.isLoadingFriends = false
                    self.friendsLoadError = nil
                    return
                }

                let dispatchGroup = DispatchGroup()
                var loadedFriends: [FriendModel] = []
                var failedToLoadFriend = false

                for friendID in friendIDs {
                    dispatchGroup.enter()
                    self.db.collection("users").document(friendID).getDocument { (friendDocument, error) in
                        DispatchQueue.main.async {
                            if error != nil {
                                failedToLoadFriend = true
                            } else if let friendDocument, friendDocument.exists {
                                let friendData = friendDocument.data()
                                loadedFriends.append(FriendModel(
                                    id: friendID,
                                    name: friendData?["name"] as? String ?? "Unknown",
                                    email: friendData?["email"] as? String ?? "",
                                    phoneNumber: friendData?["phoneNumber"] as? String ?? "",
                                    birthday: friendData?["birthday"] as? String ?? ""
                                ))
                            }
                            dispatchGroup.leave()
                        }
                    }
                }

                dispatchGroup.notify(queue: .main) { [weak self] in
                    guard let self, self.friendLoadGeneration == generation else { return }
                    if failedToLoadFriend {
                        self.friendsLoadError = "일부 친구를 불러오지 못했습니다."
                    } else {
                        self.friendsLoadError = nil
                    }
                    self.friends = loadedFriends.sorted { $0.name < $1.name }
                    self.isLoadingFriends = false
                }
            }
        }
    }

    deinit {
        friendListener?.remove()
        requestListener?.remove()
    }
    
    func observePendingRequests() {
        guard let userID = currentUserID else { return }

        requestListener?.remove()

        requestListener = db.collection("friendRequests")
            .whereField("toUserID", isEqualTo: userID)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("No pending requests or error: \(error?.localizedDescription ?? "nil")")
                    return
                }
                self.pendingRequests = documents.compactMap { queryDocumentSnapshot -> FriendRequestModel? in
                    let data = queryDocumentSnapshot.data()
                    let id = queryDocumentSnapshot.documentID
                    let fromUserID = data["fromUserID"] as? String ?? ""
                    let fromUserName = data["fromUserName"] as? String ?? "Unknown"
                    let toUserID = data["toUserID"] as? String ?? ""
                    let status = data["status"] as? String ?? "pending"
                    return toUserID == userID ? FriendRequestModel(id: id, fromUserID: fromUserID, fromUserName: fromUserName, toUserID: toUserID, status: status) : nil
                }
            }
    }
    
    func sendFriendRequest(toEmail email: String) {
        guard let userID = currentUserID, let userName = currentUserName else { return }
        
        if email == Auth.auth().currentUser?.email {
            DispatchQueue.main.async {
                self.alertMessage = "자신에게 친구 요청을 보낼 수 없습니다."
                self.showAlert = true
            }
            return
        }
        
        if friends.contains(where: { $0.email == email }) {
            DispatchQueue.main.async {
                self.alertMessage = "이미 등록된 친구입니다."
                self.showAlert = true
            }
            return
        }
        
        db.collection("users").whereField("email", isEqualTo: email).getDocuments { (snapshot, error) in
            guard let document = snapshot?.documents.first else {
                DispatchQueue.main.async {
                    self.alertMessage = "회원정보를 찾을 수 없습니다."
                    self.showAlert = true
                }
                return
            }
            let recipientID = document.documentID
            
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
                                        self.resetFriendEmailInput()
                                    }
                                }
                            }
                        }
                }
        }
    }

    func sendFriendRequest(toPhoneNumber phoneNumber: String) {
        guard let userID = currentUserID, let userName = currentUserName else { return }

        let formattedPhone = phoneNumber.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        
        if let currentUserPhone = Auth.auth().currentUser?.phoneNumber?.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: ""),
           currentUserPhone == formattedPhone {
            DispatchQueue.main.async {
                self.alertMessage = "자신에게 친구 요청을 보낼 수 없습니다."
                self.showAlert = true
            }
            return
        }
        
        db.collection("users").whereField("phoneNumber", isEqualTo: formattedPhone).getDocuments { (snapshot, error) in
            guard let document = snapshot?.documents.first else {
                DispatchQueue.main.async {
                    self.alertMessage = "회원정보를 찾을 수 없습니다."
                    self.showAlert = true
                }
                return
            }

            let recipientID = document.documentID

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
                                        self.resetFriendPhoneInput()
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
        
        group.enter()
        db.collection("users").document(userID).updateData([
            "friends": FieldValue.arrayUnion([fromUserID])
        ]) { error in
            if let error = error {
                print("친구 목록에 추가하는 데 실패했습니다: \(error)")
            }
            group.leave()
        }
        
        group.enter()
        db.collection("users").document(fromUserID).updateData([
            "friends": FieldValue.arrayUnion([userID])
        ]) { error in
            if let error = error {
                print("상대방 친구 목록에 추가하는 데 실패했습니다: \(error)")
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.db.collection("friendRequests").document(requestID).updateData([
                "status": "accepted"
            ]) { error in
                if let error = error {
                    print("친구 요청 상태 업데이트에 실패했습니다: \(error)")
                } else {
                    self.db.collection("friendRequests").document(requestID).delete() { error in
                        if let error = error {
                            print("친구 요청 삭제에 실패했습니다: \(error)")
                        } else {
                            self.observeFriends()
                        }
                    }
                }
            }
        }
    }
    
    func rejectFriendRequest(requestID: String) {
        let db = Firestore.firestore()
        
        db.collection("friendRequests").document(requestID).updateData([
            "status": "rejected"
        ]) { error in
            if let error = error {
                print("친구 요청 거절 실패: \(error.localizedDescription)")
            } else {
                print("친구 요청 거절 완료")
                
                // 상태 업데이트가 완료되면 해당 문서를 삭제
                self.deleteRequest(requestID: requestID)
            }
        }
    }

    private func deleteRequest(requestID: String) {
        let db = Firestore.firestore()
        
        // 해당 문서 삭제
        db.collection("friendRequests").document(requestID).delete { error in
            if let error = error {
                print("친구 요청 삭제 실패: \(error.localizedDescription)")
            } else {
                print("친구 요청 삭제 성공")
            }
        }
    }
    func removeFriend(friendID: String) {
        guard let userID = currentUserID else { return }
        
        let group = DispatchGroup()
        
        group.enter()
        db.collection("users").document(userID).updateData([
            "friends": FieldValue.arrayRemove([friendID])
        ]) { error in
            if let error = error {
                print("친구 목록에서 삭제하는 데 실패했습니다: \(error)")
            }
            group.leave()
        }
        
        group.enter()
        db.collection("users").document(friendID).updateData([
            "friends": FieldValue.arrayRemove([userID])
        ]) { error in
            if let error = error {
                print("상대방 친구 목록에서 삭제하는 데 실패했습니다: \(error)")
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.observeFriends()
        }
    }
}
