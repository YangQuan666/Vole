import SwiftUI

struct SettingView: View {
    // 主题色
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .blue

    @State private var showStore = false
    @StateObject private var store = StoreKitManager.shared

    // 获取 App 版本号
    private var appVersion: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "1.0"
        let build =
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    // App Store ID (请替换为你真实的 App ID)
    private let appID = "123456789"
    private let contactEmail = "quark.yeung@icloud.com"

    var body: some View {
        List {
            // 外观设置
            Section {
                HStack {
                    Label("主题色", systemImage: "paintpalette.fill")
                    Spacer()
                    Picker("主题色", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.menu)  // 下拉菜单样式，显得更简洁
                    .tint(selectedTheme.color)  // 让文字显示当前选中的颜色
                }
            } header: {
                Text("外观")
            }

            // 基本信息
            Section {
                // 点击跳转 App Store
                HStack {
                    Label("版本号", systemImage: "info.circle.fill")
                    Spacer()
                    Button {
                        if let url = URL(
                            string:
                                "itms-apps://itunes.apple.com/app/id\(appID)"
                        ) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text(appVersion)
                    }
                }

                // 请喝咖啡
                HStack {
                    Button {
                        showStore = true
                    } label: {
                        HStack {
                            Label("请我喝咖啡", systemImage: "cup.and.saucer.fill")
                            Spacer()
                            Text("为爱发电感谢支持~")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("信息")
            }

            // 关于与法律
            Section {
                // 联系我们 (打开邮件)
                HStack {
                    Label("联系我们", systemImage: "envelope.fill")
                    Spacer()
                    Button {
                        let mailToString =
                            "mailto:\(contactEmail)?subject=App反馈&body=你好，我想反馈..."
                        if let mailUrl = URL(
                            string: mailToString.addingPercentEncoding(
                                withAllowedCharacters: .urlQueryAllowed
                            ) ?? ""
                        ) {
                            if UIApplication.shared.canOpenURL(mailUrl) {
                                UIApplication.shared.open(mailUrl)
                            } else {
                                // 这里可以弹窗提示未配置邮件账户，为简化仅打印
                                print("无法打开邮件客户端")
                            }
                        }
                    } label: {
                        Text(contactEmail)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                // 许可协议
                NavigationLink {
                    LicenseContentView()
                } label: {
                    Label("许可协议", systemImage: "doc.text.fill")
                }

                // 开源软件声明
                NavigationLink {
                    OpenSourceListView()
                } label: {
                    Label("开源软件声明", systemImage: "square.stack.3d.up.fill")
                }
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showStore) {
            CoffeeStoreView(products: store.products)
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
    // 状态变量的类型为 OpenSourceItem
    @State private var items: [OpenSourceItem] = []

    var body: some View {
        List {
            // 使用 Link 打开外部 URL
            ForEach(items) { item in
                Link(
                    destination: URL(string: item.url) ?? URL(
                        string: "about:blank"
                    )!
                ) {
                    HStack {
                        Text(item.name)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "link")  // 外部链接图标
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("开源声明")
        .onAppear {
            loadOpenSourceProjects()
        }
    }

    // MARK: - 加载 JSON 逻辑
    private func loadOpenSourceProjects() {
        // 尝试从 Bundle 中查找 opensource.json 文件
        guard
            let url = Bundle.main.url(
                forResource: "opensource",
                withExtension: "json"
            )
        else {
            print("Error: opensource.json file not found in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            // 使用 JSONDecoder 解析数据，类型为 OpenSourceItem
            let decodedItems = try JSONDecoder().decode(
                [OpenSourceItem].self,
                from: data
            )
            self.items = decodedItems
        } catch {
            print("Error decoding or loading opensource.json: \(error)")
        }
    }
}

struct OpenSourceItem: Identifiable, Codable {
    // 使用 name 作为 id
    var id: String { name }
    let name: String
    let url: String
}

// 预览
#Preview {
    NavigationView {
        SettingView()
    }
}
