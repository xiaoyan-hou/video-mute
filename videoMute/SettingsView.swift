//
//  SettingsView.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import SwiftUI

struct SettingsView: View {
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Configure your preferences")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Settings Items
                    VStack(spacing: 12) {
                        SettingsItemView(
                            title: "Contact Us",
                            subtitle: "Send feedback or report issues",
                            icon: "envelope"
                        ) {
                            showToastMessage("Contact form would open here")
                        }
                        
                        SettingsItemView(
                            title: "Privacy Policy",
                            subtitle: "How we handle your data",
                            icon: "hand.raised"
                        ) {
                            showToastMessage("Privacy policy would open here")
                        }
                        
                        SettingsItemView(
                            title: "Terms of Use",
                            subtitle: "Usage guidelines",
                            icon: "doc.text"
                        ) {
                            showToastMessage("Terms of use would open here")
                        }
                        
                        SettingsItemView(
                            title: "About",
                            subtitle: "App information & version",
                            icon: "info.circle"
                        ) {
                            showToastMessage("App version: 1.0.0")
                        }
                    }
                    .padding(.horizontal)
                    
                    // App Info
                    VStack(spacing: 16) {
                        Image(systemName: "app.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.9))
                        
                        VStack(spacing: 4) {
                            Text("SoundSilence")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Version 1.0.0")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Free video audio processing tool")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Settings")
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

struct SettingsItemView: View {
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
    SettingsView()
}
