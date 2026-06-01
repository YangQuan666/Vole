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
        case id
        case name
        case systemIcon
        case colorHex
        case nodeNames
    }

    init(
        id: UUID = UUID(),
        name: String,
        systemIcon: String,
        colorHex: String,
        nodeNames: [String] = []
    ) {
        self.id = id
        self.name = name
        self.systemIcon = systemIcon
        self.colorHex = colorHex
        self.nodeNames = nodeNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        systemIcon = try container.decode(String.self, forKey: .systemIcon)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        nodeNames =
            try container.decodeIfPresent([String].self, forKey: .nodeNames)
            ?? []
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
