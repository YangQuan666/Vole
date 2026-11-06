//
//  AppIconSettingsView.swift
//  Vole
//

import SwiftUI

struct AppIconSettingsView: View {
    @ObservedObject private var iconManager = AppIconManager.shared

    @State private var switchingIcon: AppIcon?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(AppIcon.allCases) { icon in
                    Button {
                        select(icon)
                    } label: {
                        row(for: icon)
                    }
                    .foregroundStyle(.primary)
                    .disabled(switchingIcon != nil)
                }
            } footer: {
                if !iconManager.supportsAlternateIcons {
                    Text("当前设备不支持更换应用图标。")
                }
            }
        }
        .navigationTitle("应用图标")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "无法更换图标",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func row(for icon: AppIcon) -> some View {
        HStack(spacing: 16) {
            AppIconPreview(icon: icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(icon.title)
                Text(icon.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if switchingIcon == icon {
                ProgressView()
            } else if iconManager.currentIcon == icon {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(iconManager.currentIcon == icon ? .isSelected : [])
    }

    private func select(_ icon: AppIcon) {
        guard iconManager.supportsAlternateIcons,
            icon != iconManager.currentIcon,
            switchingIcon == nil
        else { return }

        switchingIcon = icon
        Task {
            do {
                try await iconManager.setIcon(icon)
            } catch {
                errorMessage = error.localizedDescription
            }
            switchingIcon = nil
        }
    }
}

/// 图标预览：两款图标都使用 Icon Composer 的自动填充背景，这里用浅色渐变近似
struct AppIconPreview: View {
    let icon: AppIcon
    var size: CGFloat = 60

    var body: some View {
        Image(icon.previewImageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [.white, Color(white: 0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        AppIconSettingsView()
    }
}
