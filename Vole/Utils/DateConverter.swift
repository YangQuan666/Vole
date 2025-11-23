//
//  DateConverter.swift
//  Vole
//
//  Created by 杨权 on 11/23/25.
//

import Foundation

class DateConverter {
    
    // 时间戳转为相对时间
    static func relativeTimeString(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // iso时间转为相对时间
    static func relativeTimeString(isoDateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        
        // 关键修改：移除 .withInternetDateTime，并明确列出所有需要的组件
        isoFormatter.formatOptions = [
            .withYear,
            .withMonth,
            .withDay,
            .withTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime
        ]
    
        guard let date = isoFormatter.date(from: isoDateString) else {
            return ""
        }
        
        // 使用 RelativeDateTimeFormatter 格式化
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
