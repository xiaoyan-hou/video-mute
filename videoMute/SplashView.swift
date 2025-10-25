//
//  SplashView.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            VStack {
                VStack(spacing: 20) {
                    // App Icon
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.31, green: 0.27, blue: 0.9))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "speaker.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    
                    // App Name
                    Text("SoundSilence")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.9))
                    
                    // Tagline
                    Text("Free Video Audio Tool")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.2)) {
                        self.size = 0.9
                        self.opacity = 1.0
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
