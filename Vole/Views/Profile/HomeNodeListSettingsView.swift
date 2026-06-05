import Kingfisher
import SwiftUI

struct HomeNodeListSettingsView: View {
    @StateObject private var collectionManager = NodeCollectionManager.shared
    @State private var showCreateSheet = false

    var body: some View {
        List {
            if collectionManager.customCollections.isEmpty {
                ContentUnavailableView(
                    "暂无自定义列表",
                    systemImage: "list.bullet.rectangle.portrait.fill",
                    description: Text("创建列表后，它会出现在首页 picker 中。")
                )
            } else {
                Section {
                    ForEach(collectionManager.customCollections) { collection in
                        NavigationLink {
                            HomeNodeCollectionEditorView(
                                mode: .edit(collection)
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.name)
                                Text("\(collection.nodeNames.count)/10 个节点")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteCollections)
                }
            }
        }
        .navigationTitle("首页列表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                HomeNodeCollectionEditorView(mode: .create)
            }
        }
    }

    private func deleteCollections(at offsets: IndexSet) {
        for index in offsets {
            let collection = collectionManager.customCollections[index]
            collectionManager.removeCustomCollection(collection)
        }
    }
}

struct HomeNodeCollectionEditorView: View {
    enum Mode {
        case create
        case edit(NodeCollection)
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @StateObject private var collectionManager = NodeCollectionManager.shared
    @StateObject private var nodeManager = NodeManager.shared

    @State private var name: String
    @State private var selectedNodeNames: Set<String>
    @State private var searchText = ""
    @State private var showLimitAlert = false

    private let maxNodeCount = 10

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _selectedNodeNames = State(initialValue: [])
        case .edit(let collection):
            _name = State(initialValue: collection.name)
            _selectedNodeNames = State(initialValue: Set(collection.nodeNames))
        }
    }

    var body: some View {
        List {
            nameSection
            selectedSection
            nodeSection
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索节点")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(!canSave)
            }
        }
        .task {
            if nodeManager.nodes.isEmpty {
                await nodeManager.refreshNodes(force: false)
            }
        }
        .alert("最多选择 \(maxNodeCount) 个节点", isPresented: $showLimitAlert) {
            Button("知道了", role: .cancel) {}
        }
    }

    private var nameSection: some View {
        Section {
            TextField("列表名称", text: $name)
        }
    }

    private var selectedSection: some View {
        Section {
            HStack {
                Text("已选择")
                Spacer()
                Text("\(selectedNodeNames.count)/\(maxNodeCount)")
                    .foregroundColor(selectionCountColor)
            }

            if !selectedNodeNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedNodes, id: \.name) { node in
                            selectedNodeChip(node)
                        }
                    }
                }
            }
        }
    }

    private var nodeSection: some View {
        Section {
            if nodeManager.nodes.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("加载节点中…")
                    Spacer()
                }
            } else {
                ForEach(filteredNodes) { node in
                    nodeRow(node)
                }
            }
        } header: {
            Text("节点")
        }
    }

    private var selectionCountColor: Color {
        selectedNodeNames.count >= maxNodeCount ? .orange : .secondary
    }

    private func selectedNodeChip(_ node: Node) -> some View {
        Text(node.title ?? node.name)
            .font(.caption)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    private func nodeRow(_ node: Node) -> some View {
        Button {
            toggle(node)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: checkmarkName(for: node))
                    .foregroundColor(checkmarkColor(for: node))

                nodeAvatar(node)

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title ?? node.name)
                        .foregroundStyle(.primary)
                    Text(node.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let topics = node.topics, topics > 0 {
                    Text("\(topics)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func nodeAvatar(_ node: Node) -> some View {
        Group {
            if let url = nodeAvatarURL(for: node) {
                KFImage(url)
                    .placeholder {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                    }
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func nodeAvatarURL(for node: Node) -> URL? {
        node.getHighestQualityAvatar().flatMap(makeFullNodeURL)
    }

    private func makeFullNodeURL(from path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        return URL(string: path, relativeTo: URL(string: "https://www.v2ex.com"))
    }

    private var navigationTitle: String {
        switch mode {
        case .create:
            return "新建列表"
        case .edit:
            return "编辑列表"
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !selectedNodeNames.isEmpty
    }

    private var filteredNodes: [Node] {
        let nodes = nodeManager.nodes.sorted {
            ($0.topics ?? 0) > ($1.topics ?? 0)
        }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !keyword.isEmpty else { return nodes }

        return nodes.filter { node in
            node.name.lowercased().contains(keyword)
                || (node.title?.lowercased().contains(keyword) ?? false)
        }
    }

    private var selectedNodes: [Node] {
        selectedNodeNames.compactMap { name in
            nodeManager.getNode(name) ?? Node.createVirtual(name: name)
        }
        .sorted { ($0.title ?? $0.name) < ($1.title ?? $1.name) }
    }

    private func toggle(_ node: Node) {
        if selectedNodeNames.contains(node.name) {
            selectedNodeNames.remove(node.name)
        } else if selectedNodeNames.count < maxNodeCount {
            selectedNodeNames.insert(node.name)
        } else {
            showLimitAlert = true
        }
    }

    private func checkmarkName(for node: Node) -> String {
        selectedNodeNames.contains(node.name) ? "checkmark.circle.fill" : "circle"
    }

    private func checkmarkColor(for node: Node) -> Color {
        selectedNodeNames.contains(node.name) ? .accentColor : .secondary
    }

    private func save() {
        let nodeNames = Array(selectedNodeNames).sorted()
        switch mode {
        case .create:
            collectionManager.addCustomCollection(
                name: trimmedName,
                nodeNames: nodeNames
            )
        case .edit(let collection):
            var updated = collection
            updated.name = trimmedName
            updated.nodeNames = nodeNames
            collectionManager.updateCustomCollection(updated)
        }
        dismiss()
    }
}
