//
//  RelativeTimeText.swift
//  Vole
//

import SwiftUI

/// 相对时间文本（如“5 分钟前”），由系统按需自动刷新。
///
/// 使用 iOS 18 的 `SystemFormatStyle.DateReference`，不需要 `TimelineView`，
/// 也不会在每次渲染时创建格式化器。
struct RelativeTimeText: View {
    let date: Date

    var body: some View {
        Text(
            .currentDate,
            format: .reference(
                to: date,
                allowedFields: [.year, .month, .day, .hour, .minute],
                maxFieldCount: 1
            )
        )
        .lineLimit(1)
    }
}

extension RelativeTimeText {
    /// 秒级时间戳
    init(timestamp: Int) {
        self.init(date: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}
