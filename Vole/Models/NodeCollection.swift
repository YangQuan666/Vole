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
