//
//  MarkdownTextEditing.swift
//  Vole
//

import SwiftUI

/// 编辑器中可执行的 Markdown 格式化操作。
enum MarkdownEditAction: Equatable {
    case heading(Int)
    case bold
    case italic
    case strikethrough
    case inlineCode
    case codeBlock
    case quote
    case bulletList
    case numberedList
    case taskList
    case horizontalRule
    case link(title: String, url: String)
    case image(alt: String, url: String)
}

/// 格式化后的文本与新的选区。
struct MarkdownEdit {
    let text: String
    let selection: TextSelection
}

/// 对纯文本应用 Markdown 格式。
///
/// 行内格式（粗体、斜体等）再次执行会取消；整行格式（标题、引用、列表）
/// 作用于选区覆盖的所有行，全部已带该格式时取消。
enum MarkdownTextEditing {
    static func apply(
        _ action: MarkdownEditAction,
        to text: String,
        selection: TextSelection?
    ) -> MarkdownEdit {
        let chars = Array(text)
        let range = selectedRange(in: text, selection: selection)

        switch action {
        case .heading(let level):
            return toggleLines(.heading(level), chars: chars, range: range)
        case .bold:
            return toggleWrap(chars: chars, range: range, delimiter: "**")
        case .italic:
            return toggleWrap(chars: chars, range: range, delimiter: "*")
        case .strikethrough:
            return toggleWrap(chars: chars, range: range, delimiter: "~~")
        case .inlineCode:
            return toggleWrap(chars: chars, range: range, delimiter: "`")
        case .codeBlock:
            let selected = String(chars[range])
            if selected.isEmpty {
                return insertBlock("```\n\n```", chars: chars, range: range, cursor: 4)
            }
            return insertBlock("```\n\(selected)\n```", chars: chars, range: range)
        case .quote:
            return toggleLines(.quote, chars: chars, range: range)
        case .bulletList:
            return toggleLines(.bullet, chars: chars, range: range)
        case .numberedList:
            return toggleLines(.numbered, chars: chars, range: range)
        case .taskList:
            return toggleLines(.task, chars: chars, range: range)
        case .horizontalRule:
            // 分隔线前必须有空行，否则会被解析为上一行的二级标题。
            return insertBlock("---", chars: chars, range: range, blankLines: true)
        case .link(let title, let url):
            let label = title.isEmpty ? url : title
            let markdown = "[\(label)](\(url))"
            return replace(chars, range, with: markdown, selecting: markdown.count..<markdown.count)
        case .image(let alt, let url):
            return insertBlock("![\(alt)](\(url))", chars: chars, range: range)
        }
    }

    /// 当前选中的文本。
    static func selectedText(in text: String, selection: TextSelection?) -> String {
        let range = selectedRange(in: text, selection: selection)
        return String(Array(text)[range])
    }

    // MARK: - 列表续写

    /// 在列表、任务或引用行末按回车后调用：新行自动续上同样的前缀，
    /// 有序列表序号加 1；在只有前缀的空项上按回车则结束列表。
    ///
    /// - Parameter newlineOffset: 刚输入的换行符在 `text` 中的字符偏移。
    /// - Returns: 需要调整时返回新的文本与光标；不需要时返回 nil。
    static func continueList(in text: String, afterNewlineAt newlineOffset: Int) -> MarkdownEdit? {
        let chars = Array(text)
        guard newlineOffset >= 0, newlineOffset < chars.count, chars[newlineOffset] == "\n" else {
            return nil
        }

        var lineStart = newlineOffset
        while lineStart > 0, chars[lineStart - 1] != "\n" { lineStart -= 1 }

        // 代码块内的回车保持原样。
        let fenceCount = String(chars[..<lineStart])
            .components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
            .count
        guard fenceCount.isMultiple(of: 2) else { return nil }

        let line = String(chars[lineStart..<newlineOffset])
        guard let marker = listMarker(of: line) else { return nil }

        if marker.isEmptyItem {
            // 空项：去掉这一行的前缀和刚输入的换行，结束列表。
            return replace(
                chars,
                lineStart..<(newlineOffset + 1),
                with: "",
                selecting: 0..<0
            )
        }

        let insertAt = newlineOffset + 1
        return replace(
            chars,
            insertAt..<insertAt,
            with: marker.next,
            selecting: marker.next.count..<marker.next.count
        )
    }

    private struct ListMarker {
        /// 下一行要使用的前缀。
        let next: String
        /// 这一行除前缀外没有内容。
        let isEmptyItem: Bool
    }

    private static func listMarker(of line: String) -> ListMarker? {
        if let match = line.prefixMatch(of: taskContinuationPattern) {
            return ListMarker(
                next: "\(match.1)\(match.2) [ ] ",
                isEmptyItem: line[match.range.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty
            )
        }
        if let match = line.prefixMatch(of: bulletContinuationPattern) {
            return ListMarker(
                next: "\(match.1)\(match.2) ",
                isEmptyItem: line[match.range.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty
            )
        }
        if let match = line.prefixMatch(of: numberedContinuationPattern),
            let number = Int(match.2)
        {
            return ListMarker(
                next: "\(match.1)\(number + 1)\(match.3) ",
                isEmptyItem: line[match.range.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty
            )
        }
        if let match = line.prefixMatch(of: quoteContinuationPattern) {
            return ListMarker(
                next: "\(match.1)> ",
                isEmptyItem: line[match.range.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty
            )
        }
        return nil
    }

    private nonisolated(unsafe) static let taskContinuationPattern = #/( *)([-*+]) +\[[ xX]\] ?/#
    private nonisolated(unsafe) static let bulletContinuationPattern = #/( *)([-*+]) +/#
    private nonisolated(unsafe) static let numberedContinuationPattern = #/( *)(\d{1,9})([.)]) +/#
    private nonisolated(unsafe) static let quoteContinuationPattern = #/( {0,3})> ?/#

    // MARK: - 选区

    /// 选区对应的字符偏移范围；没有选区时视为光标在末尾。
    private static func selectedRange(in text: String, selection: TextSelection?) -> Range<Int> {
        let end = text.count..<text.count
        guard let selection else { return end }

        let range: Range<String.Index>?
        switch selection.indices {
        case .selection(let selected):
            range = selected
        case .multiSelection(let selected):
            range = selected.ranges.first
        @unknown default:
            range = nil
        }

        guard let range,
            range.lowerBound >= text.startIndex,
            range.upperBound <= text.endIndex
        else { return end }

        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        let upper = text.distance(from: text.startIndex, to: range.upperBound)
        return lower..<upper
    }

    /// 用 `replacement` 替换 `range`，并选中替换内容中的 `inner` 范围。
    private static func replace(
        _ chars: [Character],
        _ range: Range<Int>,
        with replacement: String,
        selecting inner: Range<Int>
    ) -> MarkdownEdit {
        var result = chars
        result.replaceSubrange(range, with: Array(replacement))
        let text = String(result)
        let selected = (range.lowerBound + inner.lowerBound)..<(range.lowerBound + inner.upperBound)
        return MarkdownEdit(text: text, selection: makeSelection(in: text, range: selected))
    }

    private static func makeSelection(in text: String, range: Range<Int>) -> TextSelection {
        let count = text.count
        let lower = text.index(text.startIndex, offsetBy: min(range.lowerBound, count))
        guard !range.isEmpty else { return TextSelection(insertionPoint: lower) }
        let upper = text.index(text.startIndex, offsetBy: min(range.upperBound, count))
        return TextSelection(range: lower..<upper)
    }

    // MARK: - 行内格式

    private static func toggleWrap(
        chars: [Character],
        range: Range<Int>,
        delimiter: String
    ) -> MarkdownEdit {
        let mark = Array(delimiter)
        let selected = Array(chars[range])

        // 选区本身包含标记：去掉标记。
        if selected.count >= mark.count * 2,
            Array(selected.prefix(mark.count)) == mark,
            Array(selected.suffix(mark.count)) == mark
        {
            let inner = String(selected.dropFirst(mark.count).dropLast(mark.count))
            return replace(chars, range, with: inner, selecting: 0..<inner.count)
        }

        // 选区两侧紧挨着标记：去掉两侧的标记。
        let outer = (range.lowerBound - mark.count)..<(range.upperBound + mark.count)
        if outer.lowerBound >= 0, outer.upperBound <= chars.count,
            Array(chars[outer.lowerBound..<range.lowerBound]) == mark,
            Array(chars[range.upperBound..<outer.upperBound]) == mark,
            !isPartOfLongerMark(chars, outer, mark)
        {
            let inner = String(selected)
            return replace(chars, outer, with: inner, selecting: 0..<inner.count)
        }

        let inner = String(selected)
        return replace(
            chars,
            range,
            with: delimiter + inner + delimiter,
            selecting: mark.count..<(mark.count + inner.count)
        )
    }

    /// 避免把 `**粗体**` 两侧的 `*` 误认为斜体标记。
    private static func isPartOfLongerMark(
        _ chars: [Character],
        _ outer: Range<Int>,
        _ mark: [Character]
    ) -> Bool {
        guard mark.count == 1, let symbol = mark.first else { return false }
        let before = outer.lowerBound > 0 && chars[outer.lowerBound - 1] == symbol
        let after = outer.upperBound < chars.count && chars[outer.upperBound] == symbol
        return before || after
    }

    // MARK: - 整行格式

    private enum LineStyle {
        case heading(Int)
        case quote
        case bullet
        case numbered
        case task
    }

    private static func toggleLines(
        _ style: LineStyle,
        chars: [Character],
        range: Range<Int>
    ) -> MarkdownEdit {
        // 扩展到完整的行；选区结尾恰好在换行符之后时，不包含下一行。
        var start = range.lowerBound
        while start > 0, chars[start - 1] != "\n" { start -= 1 }
        var end = range.upperBound
        if !range.isEmpty, end > start, chars[end - 1] == "\n" { end -= 1 }
        while end < chars.count, chars[end] != "\n" { end += 1 }

        let lines = String(chars[start..<end]).components(separatedBy: "\n")
        let isBlank = { (line: String) in line.trimmingCharacters(in: .whitespaces).isEmpty }
        let contentLines = lines.filter { !isBlank($0) }
        let isAlreadyStyled = !contentLines.isEmpty && contentLines.allSatisfy { has(style, $0) }

        var number = 0
        let formatted = lines.map { line -> String in
            if lines.count > 1, isBlank(line) { return line }
            let stripped = strip(style, from: line)
            if isAlreadyStyled { return stripped }
            number += 1
            return prefix(for: style, number: number) + stripped
        }
        let replacement = formatted.joined(separator: "\n")

        // 只有光标没有选区时，保持光标相对行尾的位置。
        if range.isEmpty, lines.count == 1 {
            let distanceToLineEnd = end - range.lowerBound
            let cursor = max(0, replacement.count - distanceToLineEnd)
            return replace(chars, start..<end, with: replacement, selecting: cursor..<cursor)
        }
        return replace(chars, start..<end, with: replacement, selecting: 0..<replacement.count)
    }

    private static func has(_ style: LineStyle, _ line: String) -> Bool {
        switch style {
        case .heading(let level):
            let trimmed = line.drop { $0 == " " }
            let hashes = trimmed.prefix { $0 == "#" }.count
            return hashes == level && trimmed.dropFirst(hashes).first == " "
        case .quote:
            return line.prefixMatch(of: quotePattern) != nil
        case .bullet:
            return line.prefixMatch(of: bulletPattern) != nil
                && line.prefixMatch(of: taskPattern) == nil
        case .numbered:
            return line.prefixMatch(of: numberedPattern) != nil
        case .task:
            return line.prefixMatch(of: taskPattern) != nil
        }
    }

    /// 去掉同类的已有标记：标题替换级别，三种列表之间互相切换。
    private static func strip(_ style: LineStyle, from line: String) -> String {
        switch style {
        case .heading:
            return line.replacing(headingPattern, with: "", maxReplacements: 1)
        case .quote:
            return line.replacing(quotePattern, with: "", maxReplacements: 1)
        case .bullet, .numbered, .task:
            for pattern in [taskPattern, bulletPattern, numberedPattern]
            where line.prefixMatch(of: pattern) != nil {
                return line.replacing(pattern, with: "", maxReplacements: 1)
            }
            return line
        }
    }

    private static func prefix(for style: LineStyle, number: Int) -> String {
        switch style {
        case .heading(let level):
            return String(repeating: "#", count: level) + " "
        case .quote:
            return "> "
        case .bullet:
            return "- "
        case .numbered:
            return "\(number). "
        case .task:
            return "- [ ] "
        }
    }

    private nonisolated(unsafe) static let headingPattern = #/^ {0,3}#{1,6}\s+/#
    private nonisolated(unsafe) static let quotePattern = #/^ {0,3}>\s?/#
    private nonisolated(unsafe) static let taskPattern = #/^\s*[-*+]\s+\[[ xX]\]\s+/#
    private nonisolated(unsafe) static let bulletPattern = #/^\s*[-*+]\s+/#
    private nonisolated(unsafe) static let numberedPattern = #/^\s*\d+[.)]\s+/#

    // MARK: - 块级内容

    /// 插入独占一行的内容，必要时在前后补换行。
    private static func insertBlock(
        _ block: String,
        chars: [Character],
        range: Range<Int>,
        blankLines: Bool = false,
        cursor: Int? = nil
    ) -> MarkdownEdit {
        let needed = blankLines ? 2 : 1
        let before = chars[..<range.lowerBound]
        let after = chars[range.upperBound...]

        var leading = ""
        if !before.isEmpty {
            let existing = before.reversed().prefix { $0 == "\n" }.count
            leading = String(repeating: "\n", count: max(0, needed - existing))
        }

        let trailing: String
        if after.isEmpty {
            trailing = "\n"
        } else {
            let existing = after.prefix { $0 == "\n" }.count
            trailing = String(repeating: "\n", count: max(0, needed - existing))
        }

        let replacement = leading + block + trailing
        let position = cursor.map { leading.count + $0 } ?? replacement.count
        return replace(chars, range, with: replacement, selecting: position..<position)
    }
}
