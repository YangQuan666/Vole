//
//  NotifyView.swift
//  Vole
//
//  Created by 杨权 on 8/25/25.
//

import SwiftUI

struct NotifyView: View {
    var body: some View {
        Button(action: {
            print("按钮点击了")
        }) {
            Text("点击我")
                .font(.headline)                   // 字体大小/样式
                .foregroundColor(.primary)           // 字体颜色
                .padding(.vertical, 12)            // 上下内边距
                .padding(.horizontal, 12)          // 左右内边距
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondary)          // 背景色
                )
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2) // 阴影，可选
        }
    }
}

#Preview {
    NotifyView()
}
