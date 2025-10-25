//
//  Video_MuteApp.swift
//  Video Mute
//
//  Created by 狒狒 on 2025/10/23.
//

import SwiftUI
import CoreData

@main
struct Video_MuteApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
