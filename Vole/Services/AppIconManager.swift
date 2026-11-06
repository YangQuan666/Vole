//
//  AppIconManager.swift
//  Vole
//

import SwiftUI
import UIKit

/// 可切换的应用图标。
///
/// 新增图标：
/// 1. 用 Icon Composer 制作 `xxx.icon` 放到 `Vole/AppIcons/` 目录（文件名需唯一）；
/// 2. 在 Build Settings 的 `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` 中加入 `xxx`；
/// 3. 在下面添加 case，并在 Assets.xcassets 中提供预览图。
enum AppIcon: String, CaseIterable, Identifiable {
    case v2ex
    case vole

    var id: String { rawValue }

    /// 传给 `setAlternateIconName` 的名称，主图标为 nil
    var alternateIconName: String? {
        switch self {
        case .v2ex: return nil
        case .vole: return "vole"
        }
    }

    var title: String {
        switch self {
        case .vole: return "Vole"
        case .v2ex: return "V2EX"
        }
    }

    var subtitle: String {
        switch self {
        case .v2ex: return "默认图标"
        case .vole: return "Vole 小熊"
        }
    }

    var previewImageName: String {
        switch self {
        case .vole: return "AppIconPreviewVole"
        case .v2ex: return "AppIconPreviewV2EX"
        }
    }

    init(alternateIconName: String?) {
        self =
            Self.allCases.first { $0.alternateIconName == alternateIconName }
            ?? .v2ex
    }
}

@MainActor
final class AppIconManager: ObservableObject {
    static let shared = AppIconManager()

    @Published private(set) var currentIcon: AppIcon

    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    private init() {
        currentIcon = AppIcon(
            alternateIconName: UIApplication.shared.alternateIconName
        )
    }

    func setIcon(_ icon: AppIcon) async throws {
        guard icon != currentIcon else { return }
        try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
        currentIcon = icon
    }
}
