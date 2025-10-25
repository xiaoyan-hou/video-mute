//
//  PartialMuteView.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct PartialMuteView: View {
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var videoDuration: TimeInterval = 0
    @State private var currentTime: TimeInterval = 0
    @State private var muteStartTime: TimeInterval = 0
    @State private var muteEndTime: TimeInterval = 30
    @State private var isPlaying = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var player: AVPlayer?
    @StateObject private var videoProcessor = VideoProcessor()
    @StateObject private var videoSaver = VideoSaver()
    @State private var showSaveConfirmation = false
    @State private var processedVideoURL: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Partial Audio Muting")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Mute specific segments of your video")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Video Preview Section
                    VStack(spacing: 16) {
                        // Video Player Area
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .aspectRatio(16/9, contentMode: .fit)
                            
                            if videoURL != nil {
                                VideoPlayerView(player: player)
                                    .cornerRadius(12)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "play.circle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No video selected")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Video Selection Button
                        PhotosPicker(
                            selection: $selectedVideo,
                            matching: .videos
                        ) {
                            Text("Select a Video")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.31, green: 0.27, blue: 0.9))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    if videoURL != nil {
                        // Timeline Control Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Mute Segments")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                // Timeline Slider
                                VStack(spacing: 8) {
                                    GeometryReader { geometry in
                                        let timelineWidth = geometry.size.width
                                        
                                        ZStack(alignment: .leading) {
                                            // Background track
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(.systemGray5))
                                                .frame(height: 8)
                                            
                                            // Mute segment
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(red: 0.31, green: 0.27, blue: 0.9))
                                                .frame(width: CGFloat((muteEndTime - muteStartTime) / videoDuration) * timelineWidth, height: 8)
                                                .offset(x: CGFloat(muteStartTime / videoDuration) * timelineWidth)
                                            
                                            // Start handle
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 16, height: 16)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color(red: 0.31, green: 0.27, blue: 0.9), lineWidth: 2)
                                                )
                                                .offset(x: CGFloat(muteStartTime / videoDuration) * timelineWidth - 8)
                                                .gesture(
                                                    DragGesture()
                                                        .onChanged { value in
                                                            let newTime = max(0, min(muteEndTime - 1, value.location.x / timelineWidth * videoDuration))
                                                            muteStartTime = newTime
                                                        }
                                                )
                                            
                                            // End handle
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 16, height: 16)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color(red: 0.31, green: 0.27, blue: 0.9), lineWidth: 2)
                                                )
                                                .offset(x: CGFloat(muteEndTime / videoDuration) * timelineWidth - 8)
                                                .gesture(
                                                    DragGesture()
                                                        .onChanged { value in
                                                            let newTime = max(muteStartTime + 1, min(videoDuration, value.location.x / timelineWidth * videoDuration))
                                                            muteEndTime = newTime
                                                        }
                                                )
                                        }
                                    }
                                    .frame(height: 16)
                                    .padding(.horizontal)
                                    
                                    // Time labels
                                    HStack {
                                        Text(formatTime(muteStartTime))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(formatTime(muteEndTime))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                }
                                
                                // Time markers
                                HStack {
                                    ForEach(0..<5) { index in
                                        VStack {
                                            Text(formatTime(Double(index) * videoDuration / 4))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        if index < 4 {
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Apply Muting Button
                                VStack(spacing: 12) {
                                    Button(action: applyMuting) {
                                        HStack {
                                            if videoProcessor.isProcessing {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.8)
                                            }
                                            Text(videoProcessor.isProcessing ? "Processing..." : "Apply Muting")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(red: 0.31, green: 0.27, blue: 0.9))
                                        .cornerRadius(12)
                                    }
                                    .disabled(videoProcessor.isProcessing)
                                    
                                    if videoProcessor.isProcessing {
                                        ProgressView(value: videoProcessor.progress)
                                            .progressViewStyle(LinearProgressViewStyle())
                                            .tint(Color(red: 0.31, green: 0.27, blue: 0.9))
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Partial Mute")
            .navigationBarTitleDisplayMode(.large)
        }
        .overlay(
            Group {
                if showToast {
                    ToastView(message: toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: showToast)
                }
            }
        )
        .onChange(of: selectedVideo) { newValue in
            if let newValue = newValue {
                loadVideo(newValue)
            }
        }
        .alert("Processing Complete!", isPresented: $showSaveConfirmation) {
            Button("Save to Photos") {
                saveToPhotos()
            }
            Button("Save Later", role: .cancel) {
                // User chooses to save later, no action needed
            }
        } message: {
            Text("Video muting is complete! Would you like to save it to Photos?")
        }
    }
    
    private func loadVideo(_ item: PhotosPickerItem) {
        item.loadTransferable(type: VideoTransferable.self) { result in
            switch result {
            case .success(let video):
                if let video = video {
                    DispatchQueue.main.async {
                        self.videoURL = video.url
                        self.player = AVPlayer(url: video.url)
                        self.videoDuration = video.duration
                        self.muteEndTime = min(30, video.duration)
                        self.showToastMessage("Video loaded successfully")
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.showToastMessage("Failed to load video: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func applyMuting() {
        guard let videoURL = videoURL else {
            showToastMessage("Please select a video first")
            return
        }
        
        // Validate time range
        guard muteStartTime >= 0 && muteEndTime > muteStartTime && muteEndTime <= videoDuration else {
            showToastMessage("Invalid time range, please check mute start and end times")
            return
        }
        
        // Ensure minimum mute duration
        guard muteEndTime - muteStartTime >= 0.1 else {
            showToastMessage("Mute duration must be at least 0.1 seconds")
            return
        }
        
        videoProcessor.muteVideoSegment(
            url: videoURL,
            startTime: muteStartTime,
            endTime: muteEndTime
        ) { result in
            switch result {
            case .success(let outputURL):
                processedVideoURL = outputURL
                showSaveConfirmation = true
            case .failure(let error):
                showToastMessage("Error applying mute: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveToPhotos() {
        guard let videoURL = processedVideoURL else { 
            showToastMessage("No processed video found")
            return 
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            showToastMessage("Video file does not exist")
            return
        }
        
        videoSaver.saveVideoToPhotos(url: videoURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.showToastMessage("Video saved to Photos!")
                case .failure(let error):
                    self.showToastMessage("Failed to save to Photos: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        
        DispatchQueue.main.async {
            playerLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.player = player
            playerLayer.frame = uiView.bounds
        }
    }
}

struct VideoTransferable: Transferable {
    let url: URL
    let duration: TimeInterval
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "video_\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            
            // Calculate duration
            let asset = AVAsset(url: copy)
            let duration = asset.duration.seconds
            
            return VideoTransferable(url: copy, duration: duration)
        }
    }
}

#Preview {
    PartialMuteView()
}
