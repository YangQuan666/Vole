//
//  OpenURL+InApp.swift
//  Vole
//

import SwiftUI

extension URL {
    /// 仅网页链接适合在应用内浏览器中打开。
    var isWebURL: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

extension OpenURLAction {
    /// 打开链接；iOS 26 起网页链接优先在应用内浏览器中打开，
    /// iOS 18.6 上交给系统默认处理。
    @MainActor
    func openPreferringInApp(_ url: URL) {
        if #available(iOS 26.0, *), url.isWebURL {
            callAsFunction(url, prefersInApp: true)
        } else {
            callAsFunction(url)
        }
    }
}

extension OpenURLAction.Result {
    /// 交给系统打开链接；iOS 26 起网页链接优先在应用内浏览器中打开。
    static func systemActionPreferringInApp(_ url: URL) -> Self {
        if #available(iOS 26.0, *), url.isWebURL {
            return .systemAction(url, prefersInApp: true)
        }
        return .systemAction(url)
    }
}
