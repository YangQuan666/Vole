//
//  Setting.swift
//  Vole
//
//  Created by 杨权 on 12/3/25.
//

import Foundation
import SwiftUI

// 定义应用主题色枚举
enum AppTheme: String, CaseIterable, Identifiable {
    case blue = "蓝色"
    case purple = "紫色"
    case orange = "橙色"
    case green = "绿色"

    var id: String { self.rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .orange: return .orange
        case .green: return .green
        }
    }
}
