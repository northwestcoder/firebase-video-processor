import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import GoogleSignIn

enum UploadStatus: String, Codable {
    case pending
    case uploading
    case completed
    case failed
    case uploaded
    case processedByThunk
}
struct VideoRecord: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let videoURL: String
    let createdAt: Date
    let userId: String
    let userEmail: String
    let status: UploadStatus
    let localURL: String?
    let error: String?
    
    static func == (lhs: VideoRecord, rhs: VideoRecord) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.videoURL == rhs.videoURL
    }
}

// Helper method for Firebase Storage upload
extension StorageReference {
    func putFileAsync(from url: URL, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            let uploadTask = self.putFile(from: url, metadata: metadata)
            
            uploadTask.observe(.success) { snapshot in
                continuation.resume(returning: snapshot.metadata ?? StorageMetadata())
            }
            
            uploadTask.observe(.failure) { snapshot in
                continuation.resume(throwing: snapshot.error ?? NSError(domain: "FirebaseStorage", code: -1))
            }
            
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    print("Upload progress: \(progress.completedUnitCount)/\(progress.totalUnitCount)")
                }
            }
        }
    }
}

@MainActor
class FirebaseManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var currentUser: User?
    @Published var videoRecords: [VideoRecord] = []
    @Published var error: Error? {
        didSet {
            if error != nil {
                objectWillChange.send()
            }
        }
    }
    
    private let db = Firestore.firestore()
    private let storage: Storage
    private var snapshotListener: ListenerRegistration?
    
    init() {
        storage = Storage.storage()
        setupAuthStateListener()
    }
    
    deinit {
        snapshotListener?.remove()
    }
    
    private func setupAuthStateListener() {
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            Task { @MainActor in
                await self.handleAuthStateChange(user)
            }
        }
    }
    
    private func handleAuthStateChange(_ user: User?) async {
        isSignedIn = user != nil
        currentUser = user
        
        if user != nil {
            setupSnapshotListener()
        } else {
            videoRecords = []
            snapshotListener?.remove()
        }
    }
    
    private func uploadProgress(_ progress: Progress) {
        debugPrint("Upload progress: \(progress.completedUnitCount)/\(progress.totalUnitCount)")
    }
    
    private func setupSnapshotListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        debugPrint("🔄 Setting up snapshot listener for user: \(userId)")
        
        // Remove existing listener if any
        snapshotListener?.remove()
        
        let query = db.collection("users").document(userId).collection("videos")
        
        snapshotListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                debugPrint("❌ Error fetching records: \(error)")
                return
            }
            
            guard let snapshot = snapshot else {
                debugPrint("❌ No snapshot received")
                return
            }
            
            debugPrint("📥 Received snapshot with \(snapshot.documentChanges.count) changes")
            
            // Process each change
            for change in snapshot.documentChanges {
                if let data = try? change.document.data(as: VideoRecord.self) {
                    debugPrint("📄 Document \(change.document.documentID) changed: \(change.type.rawValue)")
                    debugPrint("📊 New data: \(data)")
                    
                    // Create a new record instead of modifying the let constant
                    let record = VideoRecord(
                        id: change.document.documentID,
                        title: data.title,
                        videoURL: data.videoURL,
                        createdAt: data.createdAt,
                        userId: data.userId,
                        userEmail: data.userEmail,
                        status: data.status,
                        localURL: data.localURL,
                        error: data.error
                    )
                    
                    // Update local array based on change type
                    switch change.type {
                    case .added:
                        debugPrint("📝 Created record with status: \(record.status.rawValue), URL: \(record.videoURL)")
                        
                        // Check if record already exists
                        if !self.videoRecords.contains(where: { $0.id == record.id }) {
                            debugPrint("➕ Adding new record: \(record.id)")
                            self.videoRecords.append(record)
                            debugPrint("✅ Added record to array")
                        } else {
                            debugPrint("⚠️ Record already exists, updating instead")
                            if let index = self.videoRecords.firstIndex(where: { $0.id == record.id }) {
                                self.videoRecords[index] = record
                                debugPrint("✅ Updated existing record")
                            }
                        }
                    case .modified:
                        debugPrint("🔄 Modifying record: \(record.id)")
                        if let index = self.videoRecords.firstIndex(where: { $0.id == record.id }) {
                            debugPrint("📊 Found record at index \(index), updating status from \(self.videoRecords[index].status) to \(record.status)")
                            self.videoRecords[index] = record
                            debugPrint("✅ Updated record in array")
                        } else {
                            debugPrint("⚠️ Record not found in array, adding it")
                            self.videoRecords.append(record)
                        }
                    case .removed:
                        debugPrint("❌ Removing record: \(record.id)")
                        self.videoRecords.removeAll(where: { $0.id == record.id })
                        debugPrint("✅ Removed record from array")
                    }
                }
            }
            
            // Remove any records that no longer exist in Firestore
            let currentIds = Set(snapshot.documents.map { $0.documentID })
            let localIds = Set(self.videoRecords.map { $0.id })
            let idsToRemove = localIds.subtracting(currentIds)
            
            if !idsToRemove.isEmpty {
                debugPrint("🗑️ Removing records that no longer exist: \(idsToRemove)")
                self.videoRecords.removeAll(where: { idsToRemove.contains($0.id) })
            }
            
            debugPrint("📊 Current records array state:")
            for record in self.videoRecords {
                debugPrint("- Record \(record.id): status=\(record.status.rawValue), URL=\(record.videoURL)")
            }
        }
    }
    
    func fetchVideoRecords() {
        setupSnapshotListener()
    }
    
    func signIn() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        guard let idToken = result.user.idToken?.tokenString else { return }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                     accessToken: result.user.accessToken.tokenString)
        
        let authResult = try await Auth.auth().signIn(with: credential)
        self.currentUser = authResult.user
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }
    
    func deleteVideo(_ record: VideoRecord) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        // Delete from Firestore first
        debugPrint("Original video URL: \(record.videoURL)")
        
        let videoRef = db.collection("users").document(userId).collection("videos").document(record.id)
        try await videoRef.delete()
        debugPrint("Successfully deleted from Firestore")
        
        // Then try to delete from Storage if URL exists
        if !record.videoURL.isEmpty {
            // Extract the storage path from the URL
            if let storagePath = extractStoragePath(from: record.videoURL) {
                debugPrint("Extracted storage path: \(storagePath)")
                let storageRef = Storage.storage().reference().child(storagePath)
                
                do {
                    try await storageRef.delete()
                    debugPrint("Successfully deleted from storage")
                } catch {
                    debugPrint("Warning: Could not delete from storage: \(error.localizedDescription)")
                }
            } else {
                debugPrint("Warning: Could not parse storage path from URL")
            }
        }
    }
    
    func uploadVideo(_ localURL: URL, title: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        let recordId = UUID().uuidString
        debugPrint("📝 Starting upload process with ID: \(recordId)")
        
        // Create initial Firestore record
        let record = VideoRecord(
            id: recordId,
            title: title,
            videoURL: "",
            createdAt: Date(),
            userId: userId,
            userEmail: Auth.auth().currentUser?.email ?? "unknown",
            status: .pending,
            localURL: localURL.path,
            error: nil
        )
        
        // Add to Firestore first
        let docRef = db.collection("users").document(userId).collection("videos").document(recordId)
        try await docRef.setData(from: record)
        debugPrint("✅ Firestore record created successfully")
        
        // Start upload process
        try await uploadVideoToStorage(localURL: localURL, recordId: recordId)
        debugPrint("✅ Upload process completed successfully")
    }
    
    private func uploadVideoToStorage(localURL: URL, recordId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        let videoRef = Storage.storage().reference().child("users/\(userId)/videos/\(recordId).mp4")
        
        // Update status to uploading
        try await updateRecordStatus(recordId: recordId, status: .uploading)
        
        // Upload the file
        _ = try await videoRef.putFileAsync(from: localURL, metadata: nil) { progress in
            if let progress = progress {
                debugPrint("Upload progress: \(progress.completedUnitCount)/\(progress.totalUnitCount)")
            }
        }
        
        // Update status to uploaded
        try await updateRecordStatus(recordId: recordId, status: .uploaded)
        debugPrint("✅ Upload completed successfully")
        
        // Get download URL
        do {
            let downloadURL = try await videoRef.downloadURL()
            debugPrint("✅ Got download URL: \(downloadURL.absoluteString)")
            
            // Update Firestore with URL and completed status
            let docRef = db.collection("users").document(userId).collection("videos").document(recordId)
            try await docRef.updateData([
                "videoURL": downloadURL.absoluteString,
                "status": UploadStatus.completed.rawValue
            ])
        } catch {
            debugPrint("❌ Error getting download URL: \(error.localizedDescription)")
            
            // Update status to failed
            try await updateRecordStatus(recordId: recordId, status: .failed, error: error.localizedDescription)
            throw error
        }
    }
    
    private func updateRecordStatus(recordId: String, status: UploadStatus, error: String? = nil) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let docRef = db.collection("users").document(userId).collection("videos").document(recordId)
        var data: [String: Any] = ["status": status.rawValue]
        if let error = error {
            data["error"] = error
        }
        try await docRef.updateData(data)
    }
    
    func retryUpload(record: VideoRecord, localURL: URL) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        
        let videoRef = Storage.storage().reference().child("users/\(userId)/videos/\(record.id).mp4")
        
        // Update status to uploading
        try await updateRecordStatus(recordId: record.id, status: .uploading)
        
        // Upload the file
        _ = try await videoRef.putFileAsync(from: localURL, metadata: nil) { progress in
            if let progress = progress {
                debugPrint("Retry upload progress: \(progress.completedUnitCount)/\(progress.totalUnitCount)")
            }
        }
        
        // Update status to uploaded
        try await updateRecordStatus(recordId: record.id, status: .uploaded)
        debugPrint("✅ Retry upload completed successfully")
        
        // Get download URL
        do {
            let downloadURL = try await videoRef.downloadURL()
            debugPrint("✅ Got download URL: \(downloadURL.absoluteString)")
            
            // Update Firestore with URL and completed status
            let docRef = db.collection("users").document(userId).collection("videos").document(record.id)
            try await docRef.updateData([
                "videoURL": downloadURL.absoluteString,
                "status": UploadStatus.completed.rawValue,
                "error": FieldValue.delete()
            ])
        } catch {
            debugPrint("❌ Error getting download URL: \(error.localizedDescription)")
            
            // Update status to failed
            try await updateRecordStatus(recordId: record.id, status: .failed, error: error.localizedDescription)
            throw error
        }
    }
    
    private func extractStoragePath(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host,
              host.contains("firebasestorage.googleapis.com") else {
            return nil
        }
        
        let components = url.path.components(separatedBy: "/o/")
        guard components.count > 1 else { return nil }
        
        let encodedPath = components[1]
        let path = encodedPath.removingPercentEncoding ?? encodedPath
        
        return path
    }
} 
