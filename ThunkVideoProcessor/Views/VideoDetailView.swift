import SwiftUI
import AVKit
import Combine
import FirebaseFirestore

struct VideoDetailView: View {
    let videoId: String
    @EnvironmentObject private var firebaseManager: FirebaseManager
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var player: AVPlayer?
    @State private var showingShareConfirmation = false
    @State private var isSharing = false
    @State private var webhookResponse: (code: Int, body: String)?
    
    private var video: VideoRecord? {
        firebaseManager.videoRecords.first { $0.id == videoId }
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if let video = video {
                VStack(alignment: .leading, spacing: 2) {
                    if let url = URL(string: video.videoURL) {
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(height: 300)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(video.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(video.createdAt.formatted(date: .numeric, time: .standard))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("Video ID: \(video.id)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("User: \(video.userEmail)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Status: \(video.status.rawValue)")
                            .font(.caption)
                            .foregroundColor(video.status == .processedByThunk ? .green : .gray)
                            .padding(.top, -6)
                        
                        Button(action: {
                            webhookResponse = nil
                            showingShareConfirmation = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text(video.status == .processedByThunk ? "Process Again!" : "Send to Thunk.AI")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isSharing)
                        
                        if let response = webhookResponse {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Response Code: \(response.code)")
                                    .font(.caption)
                                    .foregroundColor(response.code == 200 ? .green : .red)
                                
                                Text("Response Body:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(response.body)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                            .animation(.easeInOut, value: webhookResponse != nil)
                        }
                        
                    }
                    .padding()
                }
            } else {
                Text("Video not found")
                    .foregroundColor(.gray)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Share with Thunk.AI", isPresented: $showingShareConfirmation, actions: {
            Button("Cancel", role: .cancel) { }
            Button("Share") { shareWithThunk() }
        }, message: {
            Text("Send this video content to Thunk.AI?")
        })
    }
    
    private func shareWithThunk() {
        guard let video = video else { return }
        
        isSharing = true
        webhookResponse = nil
        
        guard let webhookURL = URL(string: settingsManager.webhookURL) else {
            debugPrint("Invalid webhook URL")
            isSharing = false
            return
        }
        
        // Create ISO8601 date formatter
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: video.createdAt)
        
        let payload: [String: Any] = [
            "createdAt": dateString,
            "id": video.id,
            "userId": video.userId,
            "title": video.title,
            "videoURL": video.videoURL
        ]
        
        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            debugPrint("Error creating request body: \(error)")
            isSharing = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isSharing = false
                
                if let error = error {
                    debugPrint("Error sharing with Thunk.AI: \(error)")
                    webhookResponse = (500, error.localizedDescription)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
                    debugPrint("Thunk.AI response status: \(httpResponse.statusCode)")
                    debugPrint("Response body: \(responseBody)")
                    webhookResponse = (httpResponse.statusCode, responseBody)
                    
                    // If successful, update Firebase status
                    if httpResponse.statusCode == 200 {
                        Task {
                            do {
                                try await updateVideoStatus()
                            } catch {
                                debugPrint("Error updating video status: \(error)")
                            }
                        }
                    }
                }
            }
        }.resume()
    }
    
    private func updateVideoStatus() async throws {
        guard let userId = firebaseManager.currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userId).collection("videos").document(videoId)
        try await docRef.updateData([
            "status": UploadStatus.processedByThunk.rawValue
        ])
        debugPrint("✅ Updated video status to processedByThunk")
    }
}

#Preview {
    VideoDetailView(videoId: "test-id")
        .environmentObject(FirebaseManager())
}

