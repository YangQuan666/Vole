//
//  DateConverter.swift
//  Vole
//
//  Created by 杨权 on 11/23/25.
//

import Foundation

enum DateConverter {

    /// 复用的 ISO8601 解析器，避免每次调用都创建
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        // sov2ex 返回的时间不带时区后缀，明确列出需要的组件
        formatter.formatOptions = [
            .withYear,
            .withMonth,
            .withDay,
            .withTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
        ]
        return formatter
    }()

    /// 解析 ISO8601 时间字符串，失败返回 nil
    static func date(isoDateString: String) -> Date? {
        isoFormatter.date(from: isoDateString)
    }
}
