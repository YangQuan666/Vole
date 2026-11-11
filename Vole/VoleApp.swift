//
//  VoleApp.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import SwiftData
import SwiftUI

@main
struct VoleApp: App {

    @AppStorage("appTheme") private var appTheme: AppTheme = .blue
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @AppStorage("acceptedEULA") private var acceptedEULA: Bool = false

    @State private var showWelcome = false
    @State private var showEULA = false

    init() {
        ImageCacheConfiguration.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(appTheme.color)
                .onAppear { handleStartupFlow() }
                .task {
                    await UserManager.shared.refreshStoredTokenDetails()
                }
                .sheet(isPresented: $showWelcome, onDismiss: {
                    // Welcome 关闭（点击继续或下滑）后 → 若未同意 EULA 则弹 EULA
                    if !acceptedEULA { showEULA = true }
                }) {
                    WelcomePage {
                        showWelcome = false
                    }
                }
                .sheet(isPresented: $showEULA) {
                    NavigationStack {
                        EULAView(onAgree: {
                            acceptedEULA = true
                            showEULA = false
                        })
                    }
                    .interactiveDismissDisabled(true)
                }
        }
    }

    // 启动逻辑处理
    private func handleStartupFlow() {
        // 第一次启动 → 必弹 Welcome
        if !hasLaunchedBefore {
            hasLaunchedBefore = true
            showWelcome = true
            return
        }

        // 启动过但未接受协议 → 单独弹出 EULA
        if !acceptedEULA {
            showEULA = true
        }
    }
}
