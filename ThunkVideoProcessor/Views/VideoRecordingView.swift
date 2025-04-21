import SwiftUI
import AVFoundation

struct VideoTitleSheet: View {
    @Binding var videoTitle: String
    @Environment(\.dismiss) private var dismiss
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 256/255, green: 252/255, blue: 228/255)
                    .ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Video Title", text: $videoTitle)
                    }
                    .listRowBackground(Color(red: 256/255, green: 252/255, blue: 228/255))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Video")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    onSave()
                    dismiss()
                }
                .disabled(videoTitle.isEmpty)
            )
        }
    }
}

class CameraViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isFlashOn = false
    @Published var isCameraReady = false
    @Published var error: Error?
    @Published var recordedVideoURL: URL?
    
    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let movieFileOutput = AVCaptureMovieFileOutput()
    private var currentPosition: AVCaptureDevice.Position = .back
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    private func checkPermissions() {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            checkMicrophonePermission()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.checkMicrophonePermission()
                } else {
                    Task { @MainActor in
                        self?.error = CameraError.permissionDenied
                    }
                }
            }
        default:
            error = CameraError.permissionDenied
        }
    }
    
    private func checkMicrophonePermission() {
        let audioPermission = AVAudioApplication.shared.recordPermission
        switch audioPermission {
        case .granted:
            setupSession()
        case .denied:
            error = NSError(domain: "VideoRecordingView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphone access denied"])
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                if granted {
                    self?.setupSession()
                } else {
                    self?.error = NSError(domain: "VideoRecordingView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphone access denied"])
                }
            }
        @unknown default:
            error = NSError(domain: "VideoRecordingView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown microphone permission status"])
        }
    }
    
    private func setupSession() {
        Task {
            do {
                // Configure audio session
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                
                try await setupCamera()
                await MainActor.run {
                    isCameraReady = true
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    private func setupCamera() async throws {
        // Run session configuration on a background thread
        try await Task.detached(priority: .userInitiated) {
            self.session.beginConfiguration()
            
            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition) else {
                throw CameraError.deviceNotFound
            }
            
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard self.session.canAddInput(videoInput) else {
                throw CameraError.inputError
            }
            
            self.session.addInput(videoInput)
            self.videoDeviceInput = videoInput
            
            // Add audio input
            guard let audioDevice = AVCaptureDevice.default(for: .audio),
                  let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
                  self.session.canAddInput(audioInput) else {
                throw CameraError.audioError
            }
            
            self.session.addInput(audioInput)
            
            // Add movie output
            guard self.session.canAddOutput(self.movieFileOutput) else {
                throw CameraError.outputError
            }
            
            self.session.addOutput(self.movieFileOutput)
            
            // Configure video connection
            if let connection = self.movieFileOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                if connection.isVideoRotationAngleSupported(0) {
                    connection.videoRotationAngle = 0
                }
            }
            
            // Configure audio connection
            if let connection = self.movieFileOutput.connection(with: .audio) {
                connection.isEnabled = true
            }
            
            self.session.commitConfiguration()
        }.value
        
        // Start running on a background thread
        await Task.detached(priority: .userInitiated) {
            self.session.startRunning()
        }.value
        
        await MainActor.run {
            isCameraReady = true
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Verify connections are active
        guard let videoConnection = movieFileOutput.connection(with: .video),
              let audioConnection = movieFileOutput.connection(with: .audio),
              videoConnection.isEnabled,
              audioConnection.isEnabled else {
            error = CameraError.connectionError
            return
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        
        // Start recording on a background thread
        Task.detached(priority: .userInitiated) {
            self.movieFileOutput.startRecording(to: tempURL, recordingDelegate: self)
            await MainActor.run {
                self.isRecording = true
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop recording on a background thread
        Task.detached(priority: .userInitiated) {
            self.movieFileOutput.stopRecording()
            await MainActor.run {
                self.isRecording = false
            }
        }
    }
    
    func switchCamera() {
        guard let currentInput = videoDeviceInput else { return }
        
        // Switch camera on a background thread
        Task.detached(priority: .userInitiated) {
            self.session.beginConfiguration()
            self.session.removeInput(currentInput)
            
            self.currentPosition = self.currentPosition == .back ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice),
                  self.session.canAddInput(newInput) else {
                self.session.commitConfiguration()
                return
            }
            
            self.session.addInput(newInput)
            self.videoDeviceInput = newInput
            self.session.commitConfiguration()
        }
    }
    
    func toggleFlash() {
        guard let device = videoDeviceInput?.device,
              device.hasTorch,
              device.isTorchAvailable else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .off ? .on : .off
            isFlashOn = device.torchMode == .on
            device.unlockForConfiguration()
        } catch {
            self.error = error
        }
    }
}

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            self.error = error
        } else {
            Task { @MainActor in
                self.recordedVideoURL = outputFileURL
            }
        }
    }
}

enum CameraError: LocalizedError {
    case deviceNotFound
    case inputError
    case outputError
    case audioError
    case permissionDenied
    case microphonePermissionDenied
    case connectionError
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Camera device not found"
        case .inputError:
            return "Failed to setup camera input"
        case .outputError:
            return "Failed to setup camera output"
        case .audioError:
            return "Failed to setup audio input"
        case .permissionDenied:
            return "Camera permission denied. Please enable camera access in Settings."
        case .microphonePermissionDenied:
            return "Microphone permission denied. Please enable microphone access in Settings."
        case .connectionError:
            return "Failed to setup camera connections"
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // No need to update the preview layer as it's handled by the PreviewView
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
}

struct VideoRecordingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CameraViewModel()
    @EnvironmentObject private var firebaseManager: FirebaseManager
    @State private var showTitleSheet = false
    @State private var videoTitle = ""
    
    var body: some View {
        ZStack {
            if viewModel.isCameraReady {
                CameraPreviewView(session: viewModel.session)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                        
                        Spacer()
                        
                        Button(action: { viewModel.toggleFlash() }) {
                            Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button(action: { viewModel.switchCamera() }) {
                            Image(systemName: "camera.rotate")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        
                        Spacer()
                        
                        // Main record button
                        Button(action: {
                            if viewModel.isRecording {
                                viewModel.stopRecording()
                            } else {
                                viewModel.startRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 4)
                                    .frame(width: 80, height: 80)
                                
                                if viewModel.isRecording {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red)
                                        .frame(width: 30, height: 30)
                                } else {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 70, height: 70)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Placeholder to balance the layout
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 60, height: 60)
                        
                        Spacer()
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .alert("Camera Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "Unknown error")
        }
        .onChange(of: viewModel.recordedVideoURL) { oldValue, newValue in
            if newValue != nil {
                showTitleSheet = true
            }
        }
        .sheet(isPresented: $showTitleSheet, onDismiss: {
            if videoTitle.isEmpty {
                viewModel.recordedVideoURL = nil
            }
        }) {
            VideoTitleSheet(videoTitle: $videoTitle) {
                uploadVideo()
            }
        }
    }
    
    private func uploadVideo() {
        guard let url = viewModel.recordedVideoURL, !videoTitle.isEmpty else { return }
        
        Task {
            do {
                try await firebaseManager.uploadVideo(url, title: videoTitle)
            } catch {
                debugPrint("Upload error: \(error)")
                await MainActor.run {
                    firebaseManager.error = error
                }
            }
        }
        
        dismiss()
    }
} 

