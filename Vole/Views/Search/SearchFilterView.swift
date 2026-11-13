//
//  SearchFilterView.swift
//  Vole
//
//  Created by 杨权 on 12/3/25.
//

import Kingfisher
import SwiftUI

struct SearchNodeFilterSheet: View {
    @Binding var nodeName: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @State private var tempNodeName: String
    @StateObject private var nodeManager = NodeManager.shared
    @State private var exactMatch: NodeSuggestionItem?
    @State private var suggestionItems: [NodeSuggestionItem] = []
    @FocusState private var isNodeFieldFocused: Bool

    init(
        nodeName: Binding<String>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._nodeName = nodeName
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self._tempNodeName = State(initialValue: nodeName.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchField
                contentView
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .navigationTitle("筛选节点")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if nodeManager.nodes.isEmpty {
                    await nodeManager.refreshNodes(force: false)
                }
                refreshSuggestionState()
                isNodeFieldFocused = true
            }
            .onChange(of: tempNodeName) { _, _ in
                refreshSuggestionState()
            }
            .onChange(of: nodeManager.nodes) { _, _ in
                refreshSuggestionState()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }

                if hasActiveNodeFilter {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("清除") {
                            clearAndDismiss()
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch contentState {
        case .empty:
            emptyHintView
            Spacer(minLength: 0)
        case .activeFilterHint:
            activeFilterHintView
            Spacer(minLength: 0)
        case .loading:
            loadingView
            Spacer(minLength: 0)
        case .loadFailed:
            loadFailedView
            Spacer(minLength: 0)
        case .suggestions:
            suggestionsList
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索节点名称或别名", text: $tempNodeName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isNodeFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    applyNodeSelection(submittedNodeName)
                }

            if !tempNodeName.isEmpty {
                Button {
                    tempNodeName = ""
                    isNodeFieldFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var emptyHintView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.quaternary)
            Text("输入节点名称后显示建议")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("支持 name、标题和别名")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var activeFilterHintView: some View {
        VStack(spacing: 14) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.quaternary)

            VStack(spacing: 6) {
                Text("当前已筛选节点")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(currentNodeDisplayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("继续输入可切换节点，或点右上角“清除”")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("节点列表加载中…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadFailedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(nodeManager.loadErrorMessage ?? "节点列表加载失败")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await nodeManager.refreshNodes(force: true) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var suggestionsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let exactMatch {
                    suggestionRow(item: exactMatch) {
                        applyNodeSelection(exactMatch.node.name)
                    }
                }

                ForEach(Array(suggestionItems.enumerated()), id: \.element.id) { index, item in
                    if index > 0 || exactMatch != nil {
                        Divider()
                            .padding(.leading, 56)
                    }

                    suggestionRow(item: item) {
                        applyNodeSelection(item.node.name)
                    }
                }

                if suggestionItems.isEmpty && exactMatch == nil {
                    noResultRow
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.2), lineWidth: 0.8)
            )
        }
        .scrollIndicators(.hidden)
    }

    private var noResultRow: some View {
        suggestionActionRow(
            icon: "arrow.up.left.circle",
            title: "使用当前输入的节点名",
            subtitle: trimmedNodeName,
            tint: .secondary
        ) {
            applyNodeSelection(trimmedNodeName)
        }
    }

    private func suggestionRow(
        item: NodeSuggestionItem,
        action: @escaping () -> Void
    ) -> some View {
        let isCurrentSelection = isCurrentSelectedNode(item.node)

        return Button(action: action) {
            HStack(spacing: 12) {
                suggestionAvatar(for: item.node)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.primaryText)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.secondaryText)
                            .foregroundStyle(.secondary)
                        if let aliasText = item.aliasText {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(aliasText)
                                .foregroundStyle(.secondary)
                        }
                    }
                        .font(.caption)
                        .lineLimit(1)
                }

                Spacer()

                suggestionBadge(for: item, isCurrentSelection: isCurrentSelection)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isCurrentSelection
                            ? Color.accentColor.opacity(0.08)
                            : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isCurrentSelection
                            ? Color.accentColor.opacity(0.22)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, isCurrentSelection ? 8 : 0)
        .padding(.vertical, isCurrentSelection ? 4 : 0)
    }

    @ViewBuilder
    private func suggestionBadge(
        for item: NodeSuggestionItem,
        isCurrentSelection: Bool
    ) -> some View {
        if isCurrentSelection {
            Text("当前")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
        } else if let topicsText = item.topicsText {
            Text(topicsText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
        }
    }

    private func suggestionActionRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(tint)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func suggestionAvatar(for node: Node) -> some View {
        if let avatarPath = node.getHighestQualityAvatar(),
            let url = makeFullURL(from: avatarPath)
        {
            KFImage(url)
                .fade(duration: 0.12)
                .cacheOriginalImage()
                .placeholder {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                }
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "number.square")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var trimmedNodeName: String {
        tempNodeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var contentState: NodeFilterContentState {
        if trimmedNodeName.isEmpty {
            return hasActiveNodeFilter ? .activeFilterHint : .empty
        }

        if !nodeManager.nodes.isEmpty { return .suggestions }
        if nodeManager.isLoading || !nodeManager.didAttemptLoad { return .loading }
        return .loadFailed
    }

    private var hasActiveNodeFilter: Bool {
        !currentSelectedNodeName.isEmpty
    }

    private var currentSelectedNodeName: String {
        nodeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentNodeDisplayName: String {
        if let currentNode = nodeManager.getNode(currentSelectedNodeName) {
            return currentNode.title ?? currentNode.name
        }
        return currentSelectedNodeName
    }

    private var submittedNodeName: String {
        exactMatch?.node.name ?? trimmedNodeName
    }

    private func isCurrentSelectedNode(_ node: Node) -> Bool {
        !currentSelectedNodeName.isEmpty
            && node.name.caseInsensitiveCompare(currentSelectedNodeName)
                == .orderedSame
    }

    private func applyNodeSelection(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        nodeName = trimmed
        onConfirm()
    }

    private func clearAndDismiss() {
        nodeName = ""
        tempNodeName = ""
        onConfirm()
    }

    private func makeFullURL(from path: String) -> URL? {
        SiteConfiguration.makeSiteURL(from: path)
    }

    private func matchInfo(for node: Node, keyword: String) -> NodeSuggestionItem? {
        let name = node.name.lowercased()
        let title = node.title?.lowercased()
        let aliases = node.aliases ?? []
        let lowercasedAliases = aliases.map { $0.lowercased() }

        let exactName = name == keyword
        let exactAlias = lowercasedAliases.contains(keyword)
        let exactTitle = title == keyword

        let prefixName = name.hasPrefix(keyword)
        let prefixAlias = lowercasedAliases.contains { $0.hasPrefix(keyword) }
        let prefixTitle = title?.hasPrefix(keyword) ?? false

        let containsName = name.contains(keyword)
        let containsAlias = lowercasedAliases.contains { $0.contains(keyword) }
        let containsTitle = title?.contains(keyword) ?? false

        let priority: Int
        if exactName {
            priority = 0
        } else if exactAlias {
            priority = 1
        } else if exactTitle {
            priority = 2
        } else if prefixName {
            priority = 3
        } else if prefixAlias {
            priority = 4
        } else if prefixTitle {
            priority = 5
        } else if containsName {
            priority = 6
        } else if containsAlias {
            priority = 7
        } else if containsTitle {
            priority = 8
        } else {
            return nil
        }

        let matchedAlias = aliases.first { alias in
            alias.localizedCaseInsensitiveContains(trimmedNodeName)
        }

        let matchedLength =
            matchedAlias?.count
            ?? node.title?.count
            ?? node.name.count

        return NodeSuggestionItem(
            node: node,
            priority: priority,
            matchLength: matchedLength,
            matchedAlias: matchedAlias
        )
    }

    private func refreshSuggestionState() {
        guard !trimmedNodeName.isEmpty else {
            exactMatch = nil
            suggestionItems = []
            return
        }

        let keyword = trimmedNodeName.lowercased()
        var seenNames = Set<String>()

        let allSuggestions = nodeManager.nodes
            .filter { seenNames.insert($0.name).inserted }
            .compactMap { node in
                matchInfo(for: node, keyword: keyword)
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }

                if lhs.matchLength != rhs.matchLength {
                    return lhs.matchLength < rhs.matchLength
                }

                if lhs.topicCount != rhs.topicCount {
                    return lhs.topicCount > rhs.topicCount
                }

                return lhs.node.name.localizedCaseInsensitiveCompare(rhs.node.name)
                    == .orderedAscending
            }

        let exactMatch = allSuggestions.first(where: \.isExactMatch)
        self.exactMatch = exactMatch
        suggestionItems = Array(
            allSuggestions
                .filter { item in
                    guard let exactMatch else { return true }
                    return item.id != exactMatch.id
                }
                .prefix(7)
        )
    }
}

private enum NodeFilterContentState {
    case empty
    case activeFilterHint
    case loading
    case loadFailed
    case suggestions
}

private struct NodeSuggestionItem: Identifiable, Equatable {
    let node: Node
    let priority: Int
    let matchLength: Int
    let matchedAlias: String?

    var id: String {
        node.name
    }

    var isExactMatch: Bool {
        priority <= 2
    }

    var primaryText: String {
        node.title ?? node.name
    }

    var secondaryText: String {
        node.name
    }

    var aliasText: String? {
        guard let matchedAlias, !matchedAlias.isEmpty else { return nil }
        return matchedAlias
    }

    var topicCount: Int {
        node.topics ?? 0
    }

    var topicsText: String? {
        guard topicCount > 0 else { return nil }
        return topicCount.formattedCount
    }
}

#Preview {
    //    SearchNodeFilterSheet()
}
