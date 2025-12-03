//
//  Search.swift
//  Vole
//
//  Created by 杨权 on 12/3/25.
//

import Foundation

enum SearchTimeRange: String, CaseIterable, Identifiable {
    case all = "所有时间"
    case oneMonth = "近一个月"
    case sixMonths = "近半年"
    case oneYear = "近一年"

    var id: String { rawValue }

    // 计算起始时间戳 (gte)
    var startTimeStamp: Int? {
        let now = Date()
        let calendar = Calendar.current
        switch self {
        case .all: return nil
        case .oneMonth:
            return Int(
                calendar.date(byAdding: .month, value: -1, to: now)?
                    .timeIntervalSince1970 ?? 0
            )
        case .sixMonths:
            return Int(
                calendar.date(byAdding: .month, value: -6, to: now)?
                    .timeIntervalSince1970 ?? 0
            )
        case .oneYear:
            return Int(
                calendar.date(byAdding: .year, value: -1, to: now)?
                    .timeIntervalSince1970 ?? 0
            )
        }
    }
}

enum SearchSortType: String, CaseIterable, Identifiable {
    case weight = "权重"
    case timeDesc = "最新"
    case timeAsc = "最早"

    var id: String { rawValue }
}

struct SearchFilterOptions: Equatable {
    var timeRange: SearchTimeRange = .all
    var nodeName: String = ""
    var sortType: SearchSortType = .weight
}
