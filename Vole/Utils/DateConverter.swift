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
}
