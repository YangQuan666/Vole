//
//  VoleApp.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import SwiftUI
import SwiftData

//var v2ex: V2exAPI = V2exAPI()

@main
struct VoleApp: App {    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
