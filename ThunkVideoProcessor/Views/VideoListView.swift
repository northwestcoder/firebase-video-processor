import SwiftUI
import AVKit
import Combine

@MainActor
class VideoListViewModel: ObservableObject {
    @Published var records: [VideoRecord] = []
    private var firebaseManager: FirebaseManager
    
    init(firebaseManager: FirebaseManager) {
        self.firebaseManager = firebaseManager
        setupFirebaseListener()
    }
    
    private func setupFirebaseListener() {
        // Initial load
        records = firebaseManager.videoRecords.sorted { $0.createdAt > $1.createdAt }
        
        // Listen for changes
        firebaseManager.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.records = self.firebaseManager.videoRecords.sorted { $0.createdAt > $1.createdAt }
                debugPrint("📊 ViewModel updated with \(self.records.count) records")
                self.records.forEach { record in
                    debugPrint("- Record \(record.id): status=\(record.status.rawValue), URL=\(record.videoURL)")
                }
            }
        }.store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}


struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.body)
        }
    }
}

struct VideoListView: View {
    @EnvironmentObject private var firebaseManager: FirebaseManager
    @State private var showSignIn = false
    @State private var showNewVideo = false
    @State private var showError = false
    @State private var showAbout = false
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            Text("My Videos")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppColors.background)
            
            // Scrollable content
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack {
                    List {
                        if firebaseManager.videoRecords.isEmpty {
                            Text("No videos yet")
                                .foregroundColor(.secondary)
                                .listRowBackground(AppColors.background)
                        } else {
                            ForEach(firebaseManager.videoRecords.sorted(by: { $0.createdAt > $1.createdAt })) { record in
                                VideoRow(record: record)
                                    .id("\(record.id)-\(record.status.rawValue)-\(record.videoURL)")
                                    .listRowBackground(AppColors.background)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task {
                                                try? await firebaseManager.deleteVideo(record)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppColors.background)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Button(action: { try? firebaseManager.signOut() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    
                    Spacer()
                    
                    Button(action: { showNewVideo = true }) {
                        Image(systemName: "plus")
                    }
                    
                    Spacer()
                    
                    Button(action: { showAbout = true }) {
                        Image(systemName: "info.circle")
                    }
                    
                    Spacer()
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showNewVideo) {
            VideoRecordingView()
                .environmentObject(firebaseManager)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(firebaseManager)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                firebaseManager.error = nil
                showError = false
            }
        } message: {
            if let error = firebaseManager.error {
                Text(error.localizedDescription)
            } else {
                Text("Unknown error")
            }
        }
        .onReceive(firebaseManager.objectWillChange) {
            if firebaseManager.error != nil {
                showError = true
            }
            print("📊 Firebase update received: \(firebaseManager.videoRecords.count) records")
            firebaseManager.videoRecords.forEach { record in
                print("- Record \(record.id): status=\(record.status.rawValue), URL=\(record.videoURL)")
            }
        }
        .sheet(isPresented: $showSignIn) {
            LoginView()
                .environmentObject(firebaseManager)
        }
        .onAppear {
            if !firebaseManager.isSignedIn {
                showSignIn = true
            }
            firebaseManager.fetchVideoRecords()
        }
    }
}

struct VideoRow: View {
    let record: VideoRecord
    @EnvironmentObject private var firebaseManager: FirebaseManager
    
    var body: some View {
        NavigationLink(destination: VideoDetailView(videoId: record.id)) {
            HStack {
                VStack(alignment: .leading) {
                    Text(record.title)
                        .font(.headline)
                    Text(record.createdAt.formatted())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if record.status == .failed {
                        Text("Upload failed - tap to retry")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                Group {
                    switch record.status {
                    case .pending:
                        Text("Pending...")
                            .foregroundColor(.orange)
                    case .uploading:
                        ProgressView()
                            .scaleEffect(0.8)
                    case .failed:
                        Button(action: {
                            if let localURL = record.localURL {
                                Task {
                                    try? await firebaseManager.retryUpload(record: record, localURL: URL(fileURLWithPath: localURL))
                                }
                            }
                        }) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                        }
                    case .completed:
                        if !record.videoURL.isEmpty {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                        }
                    case .uploaded:
                        if !record.videoURL.isEmpty {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                        }
                    case .processedByThunk:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .disabled(record.status != .completed && record.status != .uploaded && record.status != .processedByThunk || record.videoURL.isEmpty)
    }
}

#Preview {
    VideoListView()
        .environmentObject(FirebaseManager())
} 
