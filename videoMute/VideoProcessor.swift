//
//  VideoProcessor.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import Foundation
import AVFoundation
import PhotosUI
import Combine

class VideoProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var errorMessage: String?
    
    private var activeExportSessions: [AVAssetExportSession] = []
    private var progressTimers: [Timer] = []
    private let processingQueue = DispatchQueue(label: "video.processing", qos: .userInitiated)
    
    func muteVideo(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progress = 0.0
            self.errorMessage = nil
        }
        
        processingQueue.async {
            let asset = AVAsset(url: url)
            
            // Create composition
            let composition = AVMutableComposition()
            
            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    completion(.failure(VideoProcessingError.noVideoTrack))
                }
                return
            }
            
            // Add video track only (no audio track = completely muted)
            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    completion(.failure(VideoProcessingError.compositionError))
                }
                return
            }
            
            do {
                try compositionVideoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: asset.duration),
                    of: videoTrack,
                    at: .zero
                )
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    completion(.failure(error))
                }
                return
            }
            
            // Export the composition (video only, no audio)
            self.exportComposition(composition, completion: completion)
        }
    }
    
    func muteVideoSegment(url: URL, startTime: TimeInterval, endTime: TimeInterval, completion: @escaping (Result<URL, Error>) -> Void) {
        isProcessing = true
        progress = 0.0
        errorMessage = nil
        
        let asset = AVAsset(url: url)
        
        // Validate input parameters
        guard startTime >= 0 && endTime > startTime && endTime <= asset.duration.seconds else {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(VideoProcessingError.invalidTimeRange))
            }
            return
        }
        
        // Create composition
        let composition = AVMutableComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let audioTrack = asset.tracks(withMediaType: .audio).first else {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(VideoProcessingError.noAudioTrack))
            }
            return
        }
        
        // Add video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(VideoProcessingError.compositionError))
            }
            return
        }
        
        do {
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: asset.duration),
                of: videoTrack,
                at: .zero
            )
        } catch {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(error))
            }
            return
        }
        
        // Add audio track
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(VideoProcessingError.compositionError))
            }
            return
        }
        
        do {
            try compositionAudioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: asset.duration),
                of: audioTrack,
                at: .zero
            )
        } catch {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(error))
            }
            return
        }
        
        // Create audio mix to mute the specified segment
        let audioMix = AVMutableAudioMix()
        let audioMixParameters = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
        
        // Use a consistent timescale for all time calculations
        let timescale: CMTimeScale = 600
        let muteStartTime = CMTime(seconds: startTime, preferredTimescale: timescale)
        let muteEndTime = CMTime(seconds: endTime, preferredTimescale: timescale)
        let fadeDuration = CMTime(seconds: 0.1, preferredTimescale: timescale)
        
        // Validate that times are numeric
        guard muteStartTime.isNumeric && muteEndTime.isNumeric && fadeDuration.isNumeric else {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(VideoProcessingError.invalidTimeRange))
            }
            return
        }
        
        // Set volume ramps with proper time ranges
        do {
            // Handle fade out at the start of mute period (only if there's space before mute start)
            if startTime > 0.1 {
                let fadeOutStart = CMTimeSubtract(muteStartTime, fadeDuration)
                let fadeOutRange = CMTimeRange(start: fadeOutStart, duration: fadeDuration)
                audioMixParameters.setVolumeRamp(fromStartVolume: 1.0, toEndVolume: 0.0, timeRange: fadeOutRange)
            }
            
            // Keep muted during the mute period
            let muteRange = CMTimeRange(start: muteStartTime, end: muteEndTime)
            audioMixParameters.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: 0.0, timeRange: muteRange)
            
            // Handle fade in at the end of mute period (only if there's space after mute end)
            if endTime < asset.duration.seconds - 0.1 {
                let fadeInRange = CMTimeRange(start: muteEndTime, duration: fadeDuration)
                audioMixParameters.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: 1.0, timeRange: fadeInRange)
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(error))
            }
            return
        }
        
        audioMix.inputParameters = [audioMixParameters]
        
        // Export the composition with audio mix
        exportCompositionWithAudioMix(composition, audioMix: audioMix, completion: completion)
    }
    
    private func exportComposition(_ composition: AVMutableComposition, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(VideoProcessingError.exportError))
            }
            return
        }
        
        // Add to active sessions
        DispatchQueue.main.async {
            self.activeExportSessions.append(exportSession)
        }
        
        let outputURL = URL.documentsDirectory.appending(path: "muted_video_\(UUID().uuidString).mov")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Create progress timer
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            DispatchQueue.main.async {
                self.progress = Double(exportSession.progress)
                
                if exportSession.status != .exporting {
                    timer.invalidate()
                    self.progressTimers.removeAll { $0 == timer }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.progressTimers.append(timer)
        }
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                // Remove from active sessions
                self.activeExportSessions.removeAll { $0 == exportSession }
                
                switch exportSession.status {
                case .completed:
                    self.progress = 1.0
                    self.isProcessing = false
                    completion(.success(outputURL))
                case .failed:
                    self.errorMessage = exportSession.error?.localizedDescription
                    self.isProcessing = false
                    completion(.failure(exportSession.error ?? VideoProcessingError.exportError))
                case .cancelled:
                    self.isProcessing = false
                    completion(.failure(VideoProcessingError.cancelled))
                default:
                    self.isProcessing = false
                    completion(.failure(VideoProcessingError.unknown))
                }
            }
        }
    }
    
    private func exportCompositionWithAudioMix(_ composition: AVMutableComposition, audioMix: AVAudioMix, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(VideoProcessingError.exportError))
            }
            return
        }
        
        // Add to active sessions
        DispatchQueue.main.async {
            self.activeExportSessions.append(exportSession)
        }
        
        let outputURL = URL.documentsDirectory.appending(path: "muted_video_\(UUID().uuidString).mov")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.audioMix = audioMix
        
        // Create progress timer
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            DispatchQueue.main.async {
                self.progress = Double(exportSession.progress)
                
                if exportSession.status != .exporting {
                    timer.invalidate()
                    self.progressTimers.removeAll { $0 == timer }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.progressTimers.append(timer)
        }
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                // Remove from active sessions
                self.activeExportSessions.removeAll { $0 == exportSession }
                
                switch exportSession.status {
                case .completed:
                    self.progress = 1.0
                    self.isProcessing = false
                    completion(.success(outputURL))
                case .failed:
                    self.errorMessage = exportSession.error?.localizedDescription
                    self.isProcessing = false
                    completion(.failure(exportSession.error ?? VideoProcessingError.exportError))
                case .cancelled:
                    self.isProcessing = false
                    completion(.failure(VideoProcessingError.cancelled))
                default:
                    self.isProcessing = false
                    completion(.failure(VideoProcessingError.unknown))
                }
            }
        }
    }
    
    // MARK: - Cleanup Methods
    
    func cancelAllProcessing() {
        DispatchQueue.main.async {
            // Cancel all active export sessions
            for session in self.activeExportSessions {
                session.cancelExport()
            }
            self.activeExportSessions.removeAll()
            
            // Invalidate all timers
            for timer in self.progressTimers {
                timer.invalidate()
            }
            self.progressTimers.removeAll()
            
            self.isProcessing = false
            self.progress = 0.0
        }
    }
    
    deinit {
        cancelAllProcessing()
    }
}

enum VideoProcessingError: Error, LocalizedError {
    case noAudioTrack
    case noVideoTrack
    case compositionError
    case exportError
    case cancelled
    case unknown
    case invalidTimeRange
    
    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "No audio track found in video"
        case .noVideoTrack:
            return "No video track found in video"
        case .compositionError:
            return "Failed to create video composition"
        case .exportError:
            return "Failed to export video"
        case .cancelled:
            return "Video processing cancelled"
        case .unknown:
            return "Unknown error occurred"
        case .invalidTimeRange:
            return "Invalid time range for muting"
        }
    }
}
