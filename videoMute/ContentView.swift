//
//  ContentView.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import SwiftUI
import CoreData
import AVFoundation
import PhotosUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BatchMuteView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("Batch Mute")
                }
                .tag(0)
            
            PartialMuteView()
                .tabItem {
                    Image(systemName: "scissors")
                    Text("Partial Mute")
                }
                .tag(1)
            
            HelpView()
                .tabItem {
                    Image(systemName: "questionmark.circle")
                    Text("Help")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(Color(red: 0.31, green: 0.27, blue: 0.9)) // Primary color from PRD
        .onAppear {
            // Set app name
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.first?.rootViewController?.title = "SoundSilence"
            }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
