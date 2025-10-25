//
//  HelpView.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import SwiftUI

struct HelpView: View {
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Help & Support")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Get assistance with using SoundSilence")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Help Items
                    VStack(spacing: 12) {
                        HelpItemView(
                            title: "How to use Batch Muting",
                            subtitle: "Step-by-step guide",
                            icon: "folder.fill"
                        ) {
                            showToastMessage("Batch muting guide would open here")
                        }
                        
                        HelpItemView(
                            title: "Partial Muting Tutorial",
                            subtitle: "Learn to mute specific parts",
                            icon: "scissors"
                        ) {
                            showToastMessage("Partial muting tutorial would open here")
                        }
                        
                        HelpItemView(
                            title: "Supported Formats",
                            subtitle: "List of compatible video types",
                            icon: "doc.text"
                        ) {
                            showToastMessage("Supported formats: MP4, MOV, AVI, WMV")
                        }
                        
                        HelpItemView(
                            title: "Contact Support",
                            subtitle: "Get help with issues",
                            icon: "envelope"
                        ) {
                            showToastMessage("Contact form would open here")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Free Declaration
                    VStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.9))
                        
                        Text("SoundSilence is completely free with no ads or premium features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(Color(red: 0.31, green: 0.27, blue: 0.9).opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Help")
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
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
}

struct HelpItemView: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.9))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HelpView()
}
