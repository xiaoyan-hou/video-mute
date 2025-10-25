//
//  VideoSaver.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import Foundation
import Photos
import UIKit
import Combine
import AVFoundation

class VideoSaver: ObservableObject {
    @Published var isSaving = false
    @Published var saveStatus: SaveStatus = .idle
    
    private var activeSaveOperations: [String: URL] = [:]
    private let saveQueue = DispatchQueue(label: "video.save", qos: .userInitiated)
    private let lock = NSLock()
    
    enum SaveStatus: Equatable {
        case idle
        case saving
        case success
        case error(String)
        
        static func == (lhs: SaveStatus, rhs: SaveStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.saving, .saving), (.success, .success):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    func saveVideoToPhotos(url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let operationId = UUID().uuidString
        
        // Check if already saving this file
        lock.lock()
        if activeSaveOperations.values.contains(url) {
            lock.unlock()
            DispatchQueue.main.async {
                completion(.failure(VideoSaverError.saveFailed))
            }
            return
        }
        activeSaveOperations[operationId] = url
        lock.unlock()
        
        DispatchQueue.main.async {
            self.isSaving = true
            self.saveStatus = .saving
        }
        
        // Check if file exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.cleanupOperation(operationId: operationId)
            DispatchQueue.main.async {
                self.isSaving = false
                self.saveStatus = .error("Video file not found")
                completion(.failure(VideoSaverError.fileNotFound))
            }
            return
        }
        
        // Check file size to avoid memory issues
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = fileAttributes[.size] as? NSNumber, fileSize.intValue > 500 * 1024 * 1024 { // 500MB limit
                self.cleanupOperation(operationId: operationId)
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.saveStatus = .error("Video file too large")
                    completion(.failure(VideoSaverError.saveFailed))
                }
                return
            }
        } catch {
            self.cleanupOperation(operationId: operationId)
            DispatchQueue.main.async {
                self.isSaving = false
                self.saveStatus = .error("Cannot access video file")
                completion(.failure(VideoSaverError.fileNotFound))
            }
            return
        }
        
        saveQueue.async {
            self.requestPhotoLibraryPermission { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    self.performSave(url: url, operationId: operationId, completion: completion)
                case .failure(let error):
                    self.cleanupOperation(operationId: operationId)
                    DispatchQueue.main.async {
                        self.isSaving = false
                        self.saveStatus = .error(error.localizedDescription)
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func requestPhotoLibraryPermission(completion: @escaping (Result<Void, Error>) -> Void) {
        let currentStatus = PHPhotoLibrary.authorizationStatus()
        
        switch currentStatus {
        case .authorized, .limited:
            completion(.success(()))
        case .denied, .restricted:
            completion(.failure(VideoSaverError.accessDenied))
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized, .limited:
                    completion(.success(()))
                case .denied, .restricted:
                    completion(.failure(VideoSaverError.accessDenied))
                case .notDetermined:
                    completion(.failure(VideoSaverError.accessNotDetermined))
                @unknown default:
                    completion(.failure(VideoSaverError.unknown))
                }
            }
        @unknown default:
            completion(.failure(VideoSaverError.unknown))
        }
    }
    
    private func performSave(url: URL, operationId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("Starting save operation for: \(url.lastPathComponent)")
        
        // First try to save directly
        self.saveVideoDirectly(url: url, operationId: operationId, completion: completion)
    }
    
    private func saveVideoDirectly(url: URL, operationId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Create a temporary copy with proper format
        let tempURL = createTempVideoCopy(from: url)
        print("Created temp file: \(tempURL.lastPathComponent)")
        
        // Ensure we're on the main thread for PHPhotoLibrary operations
        DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges({
                print("Creating asset change request for: \(tempURL.lastPathComponent)")
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
                print("Asset change request created successfully")
            }) { [weak self] success, error in
                guard let self = self else { 
                    print("VideoSaver deallocated during save operation")
                    return 
                }
                
                print("Save operation completed. Success: \(success)")
                if let error = error {
                    print("Save error: \(error.localizedDescription)")
                }
                
                self.cleanupOperation(operationId: operationId)
                
                DispatchQueue.main.async {
                    self.isSaving = false
                    
                    // Clean up temp file
                    if tempURL != url {
                        do {
                            try FileManager.default.removeItem(at: tempURL)
                            print("Cleaned up temp file: \(tempURL.lastPathComponent)")
                        } catch {
                            print("Failed to clean up temp file: \(error)")
                        }
                    }
                    
                    if success {
                        self.saveStatus = .success
                        print("Video saved successfully to photo library")
                        completion(.success(()))
                    } else {
                        let errorMessage = error?.localizedDescription ?? "Unknown error"
                        self.saveStatus = .error(errorMessage)
                        print("Failed to save video: \(errorMessage)")
                        completion(.failure(error ?? VideoSaverError.saveFailed))
                    }
                }
            }
        }
    }
    
    private func saveVideoWithExport(url: URL, operationId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("Attempting to save with export for: \(url.lastPathComponent)")
        
        let asset = AVAsset(url: url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            self.cleanupOperation(operationId: operationId)
            DispatchQueue.main.async {
                self.isSaving = false
                self.saveStatus = .error("Cannot create export session")
                completion(.failure(VideoSaverError.saveFailed))
            }
            return
        }
        
        let outputURL = URL.documentsDirectory.appending(path: "exported_video_\(UUID().uuidString).mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    print("Export completed successfully")
                    self.saveVideoDirectly(url: outputURL, operationId: operationId) { result in
                        // Clean up exported file
                        try? FileManager.default.removeItem(at: outputURL)
                        completion(result)
                    }
                case .failed:
                    print("Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                    self.cleanupOperation(operationId: operationId)
                    self.isSaving = false
                    self.saveStatus = .error("Export failed")
                    completion(.failure(exportSession.error ?? VideoSaverError.saveFailed))
                case .cancelled:
                    print("Export cancelled")
                    self.cleanupOperation(operationId: operationId)
                    self.isSaving = false
                    self.saveStatus = .error("Export cancelled")
                    completion(.failure(VideoSaverError.saveFailed))
                default:
                    print("Export status: \(exportSession.status.rawValue)")
                    self.cleanupOperation(operationId: operationId)
                    self.isSaving = false
                    self.saveStatus = .error("Export failed")
                    completion(.failure(VideoSaverError.saveFailed))
                }
            }
        }
    }
    
    private func cleanupOperation(operationId: String) {
        lock.lock()
        activeSaveOperations.removeValue(forKey: operationId)
        lock.unlock()
    }
    
    private func createTempVideoCopy(from sourceURL: URL) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("temp_video_\(UUID().uuidString).mp4")
        
        do {
            // Ensure source file is accessible
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                print("Source file does not exist: \(sourceURL.path)")
                return sourceURL
            }
            
            // Check if source file is readable
            guard FileManager.default.isReadableFile(atPath: sourceURL.path) else {
                print("Source file is not readable: \(sourceURL.path)")
                return sourceURL
            }
            
            // Get file attributes
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            if let fileSize = fileAttributes[.size] as? NSNumber {
                print("Source file size: \(fileSize.intValue) bytes")
            }
            
            // Copy file to temp location
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)
            print("Successfully copied file to: \(tempURL.path)")
            
            // Verify the copy was successful
            guard FileManager.default.fileExists(atPath: tempURL.path) else {
                print("Temp file was not created successfully")
                return sourceURL
            }
            
            // Verify the copy is readable
            guard FileManager.default.isReadableFile(atPath: tempURL.path) else {
                print("Temp file is not readable")
                try? FileManager.default.removeItem(at: tempURL)
                return sourceURL
            }
            
            return tempURL
        } catch {
            print("Failed to create temp copy: \(error)")
            // If copy fails, return original URL
            return sourceURL
        }
    }
    
    // MARK: - Cleanup Methods
    
    func cancelAllSaves() {
        lock.lock()
        activeSaveOperations.removeAll()
        lock.unlock()
        
        DispatchQueue.main.async {
            self.isSaving = false
            self.saveStatus = .idle
        }
    }
    
    deinit {
        cancelAllSaves()
    }
}

enum VideoSaverError: Error, LocalizedError {
    case accessDenied
    case accessNotDetermined
    case saveFailed
    case fileNotFound
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo library access denied"
        case .accessNotDetermined:
            return "Photo library access not determined"
        case .saveFailed:
            return "Failed to save video to photos"
        case .fileNotFound:
            return "Video file not found"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}
