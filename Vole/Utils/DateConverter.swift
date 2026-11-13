//
//  DateConverter.swift
//  Vole
//
//  Created by 杨权 on 11/23/25.
//

import Foundation

enum DateConverter {

    private static let isoFormat = Date.ISO8601FormatStyle(
        includingFractionalSeconds: false,
        timeZone: TimeZone(secondsFromGMT: 0)!
    )

    /// 解析 ISO8601 时间字符串，失败返回 nil
    static func date(isoDateString: String) -> Date? {
        if let date = try? isoFormat.parseStrategy.parse(isoDateString) {
            return date
        }
        return try? isoFormat.parseStrategy.parse(isoDateString + "Z")
    }
}
