//
//  VoleApp.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import SwiftData
import SwiftUI

//var v2ex: V2exAPI = V2exAPI()

@main
struct VoleApp: App {
    //    var sharedModelContainer: ModelContainer = {
    //        let schema = Schema([
    //            Item.self,
    //        ])
    //        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    //
    //        do {
    //            return try ModelContainer(for: schema, configurations: [modelConfiguration])
    //        } catch {
    //            fatalError("Could not create ModelContainer: \(error)")
    //        }
    //    }()

    @AppStorage("appTheme") private var appTheme: AppTheme = .blue
    @StateObject private var store = StoreKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await store.loadProducts()
                }
                .tint(appTheme.color)
        }
        //        .modelContainer(sharedModelContainer)
    }
}
