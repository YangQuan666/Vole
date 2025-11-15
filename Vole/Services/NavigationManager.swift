//
//  NavigationManager.swift
//  Vole
//
//  Created by 杨权 on 11/12/25.
//

import Foundation
import SwiftUI

final class NavigationManager: ObservableObject {
    @Published var homePath = NavigationPath()
    @Published var nodePath = NavigationPath()
    @Published var notifyPath = NavigationPath()
    @Published var searchPath = NavigationPath()
}

enum Route: Hashable {
    case topicId(Int)   // topicId
    case node(Node)  // Node节点
    case nodeName(String)  // NodeName节点
    case nodeCollect(NodeCollection)  // 多个节点
    case moreNode(NodeGroup)  // 分组
}
