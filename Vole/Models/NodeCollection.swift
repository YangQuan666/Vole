//
//  NodeCollection.swift
//  Vole
//
//  Created by 杨权 on 11/15/25.
//

import Foundation
import SwiftUI

struct NodeCollection: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var systemIcon: String
    var colorHex: String
    var nodeNames: [String] = []

    var color: Color { Color(named: colorHex) }

    enum CodingKeys: String, CodingKey {
        case name
        case systemIcon
        case colorHex
        case nodeNames
        // id 不列入 keys，这样 JSON 里没有 id 也不会报错
    }
}

extension Color {
    init(named name: String) {
        switch name.lowercased() {
        case "red": self = .red
        case "blue": self = .blue
        case "orange": self = .orange
        case "green": self = .green
        case "indigo": self = .indigo
        case "purple": self = .purple
        case "cyan": self = .cyan
        case "brown": self = .brown
        case "teal": self = .teal
        case "gray": self = .gray
        case "yellow": self = .yellow
        default: self = .primary
        }
    }
}
