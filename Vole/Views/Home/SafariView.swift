//
//  SafariView.swift
//  Vole
//
//  Created by 杨权 on 9/17/25.
//

import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(
        _ uiViewController: SFSafariViewController,
        context: Context
    ) {}
}

struct AppOpenURLKey: EnvironmentKey {
    static let defaultValue: (URL) -> Void = { url in
        // 默认行为：直接系统打开
        UIApplication.shared.open(url)
    }
}

extension EnvironmentValues {
    var appOpenURL: (URL) -> Void {
        get { self[AppOpenURLKey.self] }
        set { self[AppOpenURLKey.self] = newValue }
    }
}
#Preview {
    if let safariURL = URL(string: "https://www.apple.com") {
        SafariView(url: safariURL)
    }
}
