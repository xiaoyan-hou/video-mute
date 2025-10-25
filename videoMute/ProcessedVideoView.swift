//
//  ProcessedVideoView.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct ProcessedVideoView: View {
    let videoURL: URL
    @StateObject private var videoSaver = VideoSaver()
    @State private var showShareSheet = false
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Video Preview
                VideoPlayerView(player: AVPlayer(url: videoURL))
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                // Video Info
                VStack(spacing: 8) {
                    Text("Video Processed Successfully!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("File: \(videoURL.lastPathComponent)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Save to Photos Button
                    Button(action: saveToPhotos) {
                        HStack {
                            if videoSaver.isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "photo")
                            Text(videoSaver.isSaving ? "Saving..." : "Save to Photos")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.31, green: 0.27, blue: 0.9))
                        .cornerRadius(12)
                    }
                    .disabled(videoSaver.isSaving)
                    
                    // Share Button
                    Button(action: { showShareSheet = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.headline)
                        .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.9))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.31, green: 0.27, blue: 0.9).opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
            .navigationTitle("Processed Video")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [videoURL])
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
        .onChange(of: videoSaver.saveStatus) { status in
            switch status {
            case .success:
                showToastMessage("Video saved to Photos successfully!")
            case .error(let message):
                showToastMessage("Error: \(message)")
            default:
                break
            }
        }
    }
    
    private func saveToPhotos() {
        videoSaver.saveVideoToPhotos(url: videoURL) { result in
            switch result {
            case .success:
                print("Video saved successfully")
            case .failure(let error):
                print("Error saving video: \(error)")
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
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ProcessedVideoView(videoURL: URL(fileURLWithPath: "/tmp/sample.mov"))
}
