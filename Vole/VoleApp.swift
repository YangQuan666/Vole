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

    @AppStorage("appTheme") private var appTheme: AppTheme = .blue
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @State private var showWelcome: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(appTheme.color)
                .onAppear {
                    // 首次启动
                    if !hasLaunchedBefore {
                        showWelcome = true
                        hasLaunchedBefore = true
                    }
                }
                .sheet(isPresented: $showWelcome) {
                    WelcomePage {
                        showWelcome = false
                    }
                }
        }
    }
}
