//
//  BatchMuteView.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import SwiftUI
import PhotosUI
import AVFoundation
import CoreData

struct BatchMuteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var loadedVideos: [VideoTransferable] = []
    @State private var processedVideos: [ProcessedVideoInfo] = []
    @State private var selectedVideoURLs: Set<URL> = []
    @State private var processedVideoURLs: [URL] = []
    @StateObject private var videoProcessor = VideoProcessor()
    @StateObject private var videoSaver = VideoSaver()
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showSaveConfirmation = false
    @State private var hasProcessedVideos = false
    @State private var activePopoverBatch: VideoBatch? = nil
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VideoBatch.timestamp, ascending: false)],
        animation: .default)
    private var batches: FetchedResults<VideoBatch>
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 20) {
                    headerSection
                    uploadSection
                    recentBatchesSection
                }
                .padding(.vertical)
            }
            .navigationBarHidden(true)
        }
        .overlay(toastOverlay)
        .onChange(of: selectedVideos) { newVideos in
            handleVideoSelectionChange(newVideos)
        }
        .alert("Batch Processing Complete!", isPresented: $showSaveConfirmation) {
            Button("Save to Photos") {
                saveAllToPhotos()
            }
            Button("Save Later", role: .cancel) {
                // User chooses to save later, no action needed
            }
        } message: {
            Text("All videos have been muted! Would you like to save them to Photos?")
        }
    }
    
    // MARK: - Toast Overlay
    private var toastOverlay: some View {
        Group {
            if showToast {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showToast)
            }
        }
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Batch Mute Videos")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Upload and mute multiple videos simultaneously")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
    }
                    
    private var uploadSection: some View {
        VStack(spacing: 16) {
            if loadedVideos.isEmpty {
                emptyStateView
            } else {
                // 1. Video thumbnails
                videoPreviewSection
                
                // 2. Process Videos button - full width
                processVideosButton
                
                // 3. Add Videos and Remove buttons - side by side
                addRemoveButtonsRow
            }
            
            // Only show processed videos section if we haven't processed videos yet
            if !processedVideos.isEmpty && !hasProcessedVideos {
                processedVideosSection
            }
        }
        .padding(.horizontal)
    }
    
    private var emptyStateView: some View {
                        PhotosPicker(
                            selection: $selectedVideos,
                            maxSelectionCount: 10,
                            matching: .videos
                        ) {
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.31, green: 0.27, blue: 0.9).opacity(0.1))
                                        .frame(width: 64, height: 64)
                                    
                                    Image(systemName: "icloud.and.arrow.up")
                                        .font(.title)
                                        .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.9))
                                }
                                
                                Text("Tap to select videos from your device")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {}) {
                                    Text("Select Videos")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(red: 0.31, green: 0.27, blue: 0.9))
                                        .cornerRadius(12)
                                }
                                .disabled(selectedVideos.isEmpty)
                                
                                Text("Supports MP4, MOV, AVI, WMV")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(20)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
    }
    
    private var videoPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Videos")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(loadedVideos, id: \.url) { video in
                        VideoThumbnailView(
                            video: video,
                            isSelected: selectedVideoURLs.contains(video.url),
                            onSelectionChanged: { isSelected in
                                if isSelected {
                                    selectedVideoURLs.insert(video.url)
                                } else {
                                    selectedVideoURLs.remove(video.url)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            if videoProcessor.isProcessing {
                ProgressView(value: videoProcessor.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(Color(red: 0.31, green: 0.27, blue: 0.9))
                    .padding(.horizontal)
            }
        }
    }
    
    private var processVideosButton: some View {
        Button(action: processVideos) {
            HStack {
                if videoProcessor.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(videoProcessor.isProcessing ? "Processing..." : "Process Videos")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.31, green: 0.27, blue: 0.9))
            .cornerRadius(8)
        }
        .disabled(videoProcessor.isProcessing || selectedVideoURLs.isEmpty)
    }
    
    private var addRemoveButtonsRow: some View {
        HStack(spacing: 12) {
            PhotosPicker(
                selection: $selectedVideos,
                maxSelectionCount: 10,
                matching: .videos
            ) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.9))
                    
                    Text("Add Videos")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 0.31, green: 0.27, blue: 0.9).opacity(0.1))
                .cornerRadius(8)
            }
            
            Button(action: removeSelectedVideos) {
                HStack {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("Remove")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(selectedVideoURLs.isEmpty)
        }
    }
    
    private var processedVideosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processed Videos")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(processedVideos, id: \.id) { videoInfo in
                        ProcessedVideoPreviewCard(videoInfo: videoInfo)
                        }
                    }
                    .padding(.horizontal)
            }
        }
    }
                    
    private var recentBatchesSection: some View {
        Group {
            if !batches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Batches")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(batches, id: \.self) { batch in
                            BatchItemView(batch: batch, activePopoverBatch: $activePopoverBatch)
                                .onAppear {
                                    // Optional: Add any batch-specific logic here
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func handleVideoSelectionChange(_ newVideos: [PhotosPickerItem]) {
        if !newVideos.isEmpty {
            showToastMessage("Selected \(newVideos.count) videos")
            loadSelectedVideos()
        } else {
            loadedVideos.removeAll()
            processedVideos.removeAll()
            selectedVideoURLs.removeAll()
        }
    }
    
    // MARK: - Private Functions
    
    private func loadSelectedVideos() {
        loadedVideos.removeAll()
        selectedVideoURLs.removeAll()
        
        for videoItem in selectedVideos {
            videoItem.loadTransferable(type: VideoTransferable.self) { result in
                switch result {
                case .success(let video):
                    if let video = video {
                        DispatchQueue.main.async {
                            self.loadedVideos.append(video)
                            
                            // If this is the first video, select it by default
                            if self.loadedVideos.count == 1 {
                                self.selectedVideoURLs.insert(video.url)
                            }
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.showToastMessage("Failed to load video: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func processVideos() {
        // Create a new batch
        let batch = VideoBatch(context: viewContext)
        batch.timestamp = Date()
        batch.name = "Batch \(batches.count + 1)"
        batch.videoCount = Int16(selectedVideos.count)
        
        do {
            try viewContext.save()
            showToastMessage("Batch created successfully!")
            
            // Process videos
            processSelectedVideos(for: batch)
        } catch {
            showToastMessage("Error creating batch")
        }
    }
    
    private func processSelectedVideos(for batch: VideoBatch) {
        guard !selectedVideoURLs.isEmpty else { return }
        
        let group = DispatchGroup()
        var processedCount = 0
        var processedURLs: [URL] = []
        var newProcessedVideos: [ProcessedVideoInfo] = []
        let lock = NSLock() // Add thread safety
        
        // Only process selected videos
        let videosToProcess = loadedVideos.filter { selectedVideoURLs.contains($0.url) }
        
        for video in videosToProcess {
            group.enter()
            
            self.videoProcessor.muteVideo(url: video.url) { result in
                lock.lock()
                defer { lock.unlock() }
                
                processedCount += 1
                
                switch result {
                case .success(let outputURL):
                    print("Video processed successfully: \(outputURL)")
                    processedURLs.append(outputURL)
                    
                    DispatchQueue.main.async {
                        self.processedVideoURLs.append(outputURL)
                    }
                    
                    // Create processed video info
                    let processedVideoInfo = ProcessedVideoInfo(
                        originalURL: video.url,
                        processedURL: outputURL,
                        name: video.url.lastPathComponent,
                        duration: video.duration,
                        isProcessed: true
                    )
                    newProcessedVideos.append(processedVideoInfo)
                    
                case .failure(let error):
                    print("Error processing video: \(error)")
                    DispatchQueue.main.async {
                        self.showToastMessage("Error processing video: \(error.localizedDescription)")
                    }
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Save processed URLs to the batch
            batch.processedVideoURLs = processedURLs
            
            do {
                try self.viewContext.save()
            } catch {
                print("Error saving processed URLs: \(error)")
            }
            
            // Update processed videos for preview
            self.processedVideos = newProcessedVideos
            
            // Mark that we have processed videos
            self.hasProcessedVideos = true
            
            if !self.processedVideoURLs.isEmpty {
                self.showSaveConfirmation = true
            } else {
                self.showToastMessage("All videos processed successfully!")
            }
        }
    }
    
    private func removeSelectedVideos() {
        // Remove selected videos from loadedVideos
        loadedVideos.removeAll { selectedVideoURLs.contains($0.url) }
        
        // Clear selected URLs
        selectedVideoURLs.removeAll()
        
        // If no videos left, clear everything
        if loadedVideos.isEmpty {
            selectedVideos.removeAll()
            processedVideos.removeAll()
            processedVideoURLs.removeAll()
            hasProcessedVideos = false
        }
        
        showToastMessage("Selected videos removed")
    }
    
    private func saveAllToPhotos() {
        guard !processedVideoURLs.isEmpty else { 
            showToastMessage("No processed videos found")
            return 
        }
        
        let group = DispatchGroup()
        var savedCount = 0
        var failedCount = 0
        
        for videoURL in processedVideoURLs {
            // Check if file exists before attempting to save
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                failedCount += 1
                continue
            }
            
            group.enter()
            
            videoSaver.saveVideoToPhotos(url: videoURL) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        savedCount += 1
                    case .failure(let error):
                        failedCount += 1
                        print("Error saving video: \(error)")
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if savedCount > 0 {
                self.showToastMessage("Saved \(savedCount) videos to Photos!")
            }
            if failedCount > 0 {
                self.showToastMessage("\(failedCount) videos failed to save")
            }
            self.processedVideoURLs.removeAll()
        }
    }
}

struct BatchItemView: View {
    let batch: VideoBatch
    @Binding var activePopoverBatch: VideoBatch?
    @StateObject private var videoSaver = VideoSaver()
    @State private var showToast = false
    @State private var toastMessage = ""
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        ZStack {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 28)
                    
                    Image(systemName: "film")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(batch.name ?? "Unnamed Batch")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(formatDate(batch.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(batch.videoCount) videos")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    activePopoverBatch = batch
                }) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .overlay(
                Group {
                    if showToast {
                        ToastView(message: toastMessage)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: showToast)
                    }
                }
            )
            .id(batch.objectID)
            
            .popover(isPresented: Binding(
                get: { activePopoverBatch == batch },
                set: { if !$0 { activePopoverBatch = nil } }
            ), arrowEdge: .top) {
                VStack(spacing: 0) {
                    // Header with close button
                    HStack {
                        Text("Actions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            activePopoverBatch = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    Divider()
                        .background(Color(.systemGray5))
                    
                    Button(action: {
                        activePopoverBatch = nil
                        saveBatchToPhotos()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .frame(width: 20, height: 20)
                            Text("Save to Photos")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minWidth: 140)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .background(Color(.systemGray5))
                    
                    Button(action: {
                        activePopoverBatch = nil
                        deleteBatch()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .frame(width: 20, height: 20)
                            Text("Delete Record")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minWidth: 140)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
            }
        }
    }
    
    private func saveBatchToPhotos() {
        guard let processedURLs = batch.processedVideoURLs, !processedURLs.isEmpty else {
            showToastMessage("No processed videos found")
            return
        }
        
        let group = DispatchGroup()
        var savedCount = 0
        var failedCount = 0
        
        for videoURL in processedURLs {
            // Check if file exists before attempting to save
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                failedCount += 1
                continue
            }
            
            group.enter()
            
            videoSaver.saveVideoToPhotos(url: videoURL) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        savedCount += 1
                    case .failure(let error):
                        failedCount += 1
                        print("Error saving video: \(error)")
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if savedCount > 0 {
                self.showToastMessage("Saved \(savedCount) videos to Photos!")
            }
            if failedCount > 0 {
                self.showToastMessage("\(failedCount) videos failed to save")
            }
        }
    }
    
    private func deleteBatch() {
        // Delete associated video files first
        if let processedURLs = batch.processedVideoURLs {
            for videoURL in processedURLs {
                try? FileManager.default.removeItem(at: videoURL)
            }
        }
        
        // Delete the batch from Core Data
        viewContext.delete(batch)
        
        do {
            try viewContext.save()
            showToastMessage("Batch record deleted")
        } catch {
            showToastMessage("Delete failed: \(error.localizedDescription)")
        }
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ProcessedVideoPreviewCard: View {
    let videoInfo: ProcessedVideoInfo
    @State private var thumbnail: UIImage?
    @State private var showVideoPlayer = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(width: 120)
                
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 67.5)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture {
                            showVideoPlayer = true
                        }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "video")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(videoInfo.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
                
                Text(formatDuration(videoInfo.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
            }
        }
        .frame(width: 120)
        .onAppear {
            generateThumbnail()
        }
        .sheet(isPresented: $showVideoPlayer) {
            VideoPlayerSheet(video: VideoTransferable(url: videoInfo.processedURL, duration: videoInfo.duration))
        }
    }
    
    private func generateThumbnail() {
        let asset = AVAsset(url: videoInfo.processedURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 600)
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
            DispatchQueue.main.async {
                if let image = image {
                    self.thumbnail = UIImage(cgImage: image)
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VideoThumbnailView: View {
    let video: VideoTransferable
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        VStack {
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 67.5)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 67.5)
                        .cornerRadius(8)
                }
                
                // Selection overlay
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.31, green: 0.27, blue: 0.9), lineWidth: 3)
                        .frame(width: 120, height: 67.5)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Color(red: 0.31, green: 0.27, blue: 0.9))
                                .clipShape(Circle())
                                .padding(4)
                        }
                        Spacer()
                    }
                }
                
                // Tap gesture for selection
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectionChanged(!isSelected)
                    }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(video.url.lastPathComponent)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
                
                Text(formatDuration(video.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
            }
        }
        .frame(width: 120)
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        let asset = AVAsset(url: video.url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 600)
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
            DispatchQueue.main.async {
                if let image = image {
                    self.thumbnail = UIImage(cgImage: image)
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VideoPlayerSheet: View {
    let video: VideoTransferable
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                VideoPlayerView(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .onTapGesture {
                        togglePlayPause()
                    }
                
                HStack {
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(formatDuration(video.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle(video.url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func setupPlayer() {
        player = AVPlayer(url: video.url)
        
        // Add observer for player status
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
        }
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


struct ToastView: View {
    let message: String
    
    var body: some View {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
            .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
            .padding(.horizontal)
    }
}

struct ProcessedVideoInfo: Identifiable {
    let id = UUID()
    let originalURL: URL
    let processedURL: URL
    let name: String
    let duration: TimeInterval
    let isProcessed: Bool
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

