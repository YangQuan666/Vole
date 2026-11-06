import StoreKit
import SwiftUI

struct SettingView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .blue

    @State private var showStore = false
    @State private var purchasingProductID: String?
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var siteConfigurationStore = SiteConfigurationStore.shared
    @ObservedObject private var iconManager = AppIconManager.shared

    private var appVersion: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "1.0"
        let build =
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    private let appID = "6756212194"
    private let contactEmail = "quark.yeung@icloud.com"

    private var appStoreURL: URL? {
        URL(string: "itms-apps://apps.apple.com/app/id\(appID)")
    }

    private var contactURL: URL? {
        URL(
            string: "mailto:\(contactEmail)?subject=App反馈&body=你好，我想反馈"
                .addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed
                ) ?? ""
        )
    }

    private var discordURL: URL {
        URL(string: "https://discord.gg/4vnEBzrW3d")!
    }

    private var projectURL: URL {
        URL(string: "https://github.com/YangQuan666/Vole")!
    }

    private var selectedSiteHost: String {
        URL(string: siteConfigurationStore.selectedBaseURL)?.host
            ?? siteConfigurationStore.selectedBaseURL
    }

    private var savedSiteSummary: String {
        "已保存 \(siteConfigurationStore.baseURLs.count) 个站点"
    }

    var body: some View {
        List {
            Section("偏好设置") {
                themeRow

                NavigationLink {
                    AppIconSettingsView()
                } label: {
                    SettingRow(
                        systemImage: "app.badge",
                        tint: .indigo,
                        title: "应用图标",
                        subtitle: "更换主屏幕上的 App 图标"
                    ) {
                        Text(iconManager.currentIcon.title)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                NavigationLink {
                    HomeNodeListSettingsView()
                } label: {
                    SettingRow(
                        systemImage: "list.bullet.rectangle.portrait",
                        tint: .orange,
                        title: "首页列表",
                        subtitle: "管理首页展示的节点列表"
                    )
                }

                NavigationLink {
                    SiteBaseURLSettingsView(store: siteConfigurationStore)
                } label: {
                    SettingRow(
                        systemImage: "network",
                        tint: .green,
                        title: "站点地址",
                        subtitle: savedSiteSummary
                    ) {
                        Text(selectedSiteHost)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Section("支持与反馈") {
                Button {
                    showStore = true
                } label: {
                    SettingRow(
                        systemImage: "cup.and.heat.waves",
                        tint: .orange,
                        title: "请我喝咖啡",
                        subtitle: "为爱发电，感谢支持"
                    ) {
                        Text("支持一下")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    guard let contactURL else { return }
                    openURL(contactURL)
                } label: {
                    SettingRow(
                        systemImage: "envelope",
                        tint: .blue,
                        title: "联系我们",
                        subtitle: contactEmail
                    ) {
                        SettingExternalAccessory()
                    }
                }
                .buttonStyle(.plain)

                Link(destination: discordURL) {
                    SettingRow(
                        systemImage: "bubble.left.and.exclamationmark.bubble.right",
                        tint: .indigo,
                        title: "问题反馈",
                        subtitle: "加入 Discord 社区"
                    ) {
                        SettingExternalAccessory()
                    }
                }
                .buttonStyle(.plain)
            }

            Section("关于项目") {
                Button {
                    guard let appStoreURL else { return }
                    openURL(appStoreURL)
                } label: {
                    SettingRow(
                        systemImage: "info.circle",
                        tint: .gray,
                        title: "版本号",
                        subtitle: "查看 App Store 页面"
                    ) {
                        Text(appVersion)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Link(destination: projectURL) {
                    SettingRow(
                        systemImage: "folder",
                        tint: .brown,
                        title: "项目地址",
                        subtitle: "YangQuan666/Vole"
                    ) {
                        SettingExternalAccessory()
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    LicenseContentView()
                } label: {
                    SettingRow(
                        systemImage: "doc.text",
                        tint: .teal,
                        title: "许可协议",
                        subtitle: "查看项目 License"
                    )
                }

                NavigationLink {
                    OpenSourceListView()
                } label: {
                    SettingRow(
                        systemImage: "square.stack.3d.up",
                        tint: .mint,
                        title: "开源软件声明",
                        subtitle: "查看第三方依赖与来源"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showStore) {
            CoffeeSupportDialog(
                products: storeManager.products,
                purchasingProductID: purchasingProductID,
                onPurchase: { product in
                    purchase(product)
                },
                onDismiss: {
                    showStore = false
                }
            )
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
        }
        .task {
            await storeManager.loadProducts()
        }
    }

    private func purchase(_ product: Product) {
        guard purchasingProductID == nil else { return }
        purchasingProductID = product.id

        Task {
            let success = await storeManager.purchase(product)
            purchasingProductID = nil

            if success {
                showStore = false
            }
        }
    }

    private var themeRow: some View {
        SettingRow(
            systemImage: "paintpalette",
            tint: selectedTheme.color,
            title: "主题色",
            subtitle: "点击切换 App 的强调色"
        ) {
            Picker("主题色", selection: $selectedTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue)
                        .tag(theme)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(selectedTheme.color)
        }
    }
}

private struct CoffeeSupportDialog: View {
    let products: [Product]
    let purchasingProductID: String?
    let onPurchase: (Product) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                CoffeeIcon()

                VStack(spacing: 8) {
                    Text("可以请我喝杯咖啡吗？")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text("如果 Vole 对你有帮助，可以用一杯咖啡支持后续维护。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                if products.isEmpty {
                    CoffeeLoadingView()
                } else {
                    ForEach(products, id: \.id) { product in
                        CoffeeProductButton(
                            product: product,
                            isPurchasing: purchasingProductID == product.id
                        ) {
                            onPurchase(product)
                        }
                        .disabled(purchasingProductID != nil)
                    }
                }
            }

            Button("稍后再说") {
                onDismiss()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .disabled(purchasingProductID != nil)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
    }
}

private struct CoffeeIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.14))
                .frame(width: 58, height: 58)

            Image(systemName: "cup.and.heat.waves")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.orange)
        }
    }
}

private struct CoffeeLoadingView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("正在准备咖啡选项")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct CoffeeProductButton: View {
    let product: Product
    let isPurchasing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("支持维护")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.orange)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.orange.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingRow<Accessory: View>: View {
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: String?
    @ViewBuilder var accessory: () -> Accessory

    init(
        systemImage: String,
        tint: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 14) {
            SettingRowIcon(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            accessory()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct SettingRowIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(tint.opacity(0.14))
            .frame(width: 34, height: 34)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
    }
}

private struct ThemeValuePill: View {
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(theme.color)
                .frame(width: 8, height: 8)

            Text(theme.rawValue)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(theme.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(theme.color.opacity(0.12))
        )
    }
}

private struct SettingExternalAccessory: View {
    var body: some View {
        Image(systemName: "arrow.up.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

struct SiteBaseURLSettingsView: View {
    @ObservedObject var store: SiteConfigurationStore
    @State private var isAddSheetPresented = false

    var body: some View {
        List {
            Section {
                ForEach(
                    Array(store.baseURLs.enumerated()),
                    id: \.element
                ) { _, baseURL in
                    Button {
                        store.select(baseURL)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(baseURL)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                if baseURL.caseInsensitiveCompare(
                                    SiteConfiguration.defaultBaseURL
                                ) == .orderedSame {
                                    Text("默认站点")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if baseURL.caseInsensitiveCompare(
                                store.selectedBaseURL
                            ) == .orderedSame {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        if store.canDelete(baseURL) {
                            Button(role: .destructive) {
                                store.remove(baseURL)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("已保存站点")
            } footer: {
                Text("点击任意地址即可切换。左滑可删除，至少会保留一个地址。")
            }
        }
        .navigationTitle("站点地址")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddSheetPresented) {
            AddSiteBaseURLSheet(store: store)
        }
    }
}

private struct AddSiteBaseURLSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: SiteConfigurationStore

    @State private var input = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("输入站点地址", text: $input)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Base URL")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        Text("支持直接输入域名，未带协议时会自动补成 https://。")
                    }
                }
            }
            .navigationTitle("添加站点")
            .navigationBarTitleDisplayMode(.inline)
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
                }
            }
        }
    }

    private func save() {
        do {
            try store.add(input)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 主应用许可协议内容视图
struct LicenseContentView: View {
    @State private var licenseText: String = "加载中..."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(licenseText)
                    .font(.system(.caption, design: .monospaced))  // 使用等宽字体展示协议文本
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("许可协议")
        .onAppear {
            loadLicenseFile()
        }
    }

    private func loadLicenseFile() {
        // 1. 尝试读取名为 "License" 的文件
        if let url = Bundle.main.url(
            forResource: "LICENSE",
            withExtension: ""
        ) {
            do {
                licenseText = try String(contentsOf: url, encoding: .utf8)
            } catch {
                licenseText =
                    "无法加载项目许可协议文件 (License.txt)。错误: \(error.localizedDescription)"
                print("Error loading License.txt file: \(error)")
            }
        }
        // 2. 最终未找到文件
        else {
            licenseText =
                "未找到名为 'License.txt', 'LICENSE.txt' 或 'License' 的项目许可协议文件。请确保文件已添加到 Bundle 资源中。"
        }
    }
}

// 开源软件列表视图
struct OpenSourceListView: View {
    var body: some View {
        List {
            Section {
                ForEach(OpenSourceItem.defaultItems) { item in
                    Link(destination: item.url) {
                        OpenSourceRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("第三方项目")
            } footer: {
                Text("感谢这些开源项目为 Vole 提供基础能力。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("开源声明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OpenSourceItem: Identifiable {
    var id: String { name }
    let name: String
    let repository: String
    let url: URL
    let license: String
    let systemImage: String
    let tint: Color
}

private extension OpenSourceItem {
    static let defaultItems: [OpenSourceItem] = [
        OpenSourceItem(
            name: "MarkdownView",
            repository: "LiYanan2004/MarkdownView",
            url: URL(string: "https://github.com/LiYanan2004/MarkdownView")!,
            license: "MIT",
            systemImage: "text.alignleft",
            tint: .blue
        ),
        OpenSourceItem(
            name: "SwiftSoup",
            repository: "scinfu/SwiftSoup",
            url: URL(string: "https://github.com/scinfu/SwiftSoup")!,
            license: "MIT",
            systemImage: "curlybraces",
            tint: .orange
        ),
        OpenSourceItem(
            name: "Kingfisher",
            repository: "onevcat/Kingfisher",
            url: URL(string: "https://github.com/onevcat/Kingfisher")!,
            license: "MIT",
            systemImage: "photo",
            tint: .indigo
        ),
        OpenSourceItem(
            name: "SOV2EX",
            repository: "bynil/sov2ex",
            url: URL(string: "https://github.com/bynil/sov2ex")!,
            license: "MIT",
            systemImage: "magnifyingglass",
            tint: .teal
        ),
        OpenSourceItem(
            name: "V2exAPI",
            repository: "isaced/V2exAPI",
            url: URL(string: "https://github.com/isaced/V2exAPI")!,
            license: "MIT",
            systemImage: "network",
            tint: .green
        ),
    ]
}

private struct OpenSourceRow: View {
    let item: OpenSourceItem

    var body: some View {
        HStack(spacing: 14) {
            SettingRowIcon(systemImage: item.systemImage, tint: item.tint)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    OpenSourceLicenseBadge(text: item.license)
                }

                Text(item.repository)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            SettingExternalAccessory()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct OpenSourceLicenseBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
    }
}

// 预览
#Preview {
    NavigationView {
        SettingView()
    }
}
