//
//  ChatterGPTApp.swift
//  ChatterGPT
//
//  Created by Alex Moumoulides on 26/02/23.
//

import SwiftUI

@main
struct ChatterGPTApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
