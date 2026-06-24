//  LineColumnConverter.swift
//  OkJson
//
//  UTF-16 偏移 ↔ (行,列) 双向换算。位置单位为 UTF-16 code unit，
//  与 NSString / NSRange / NSTextView 一致。行以 \n 分隔，行列均 1-based。

import Foundation

struct LineColumnConverter {
    /// 每行起始处的 UTF-16 偏移（lineStarts[0] == 0）
    private let lineStarts: [Int]
    private let totalLength: Int

    init(text: String) {
        let ns = text as NSString
        let len = ns.length
        var starts: [Int] = [0]
        var i = 0
        while i < len {
            if ns.character(at: i) == 10 { // \n
                starts.append(i + 1)
            }
            i += 1
        }
        self.lineStarts = starts
        self.totalLength = len
    }

    /// UTF-16 偏移 → (行,列)，均 1-based；越界偏移夹紧到合法范围。
    func lineColumn(at utf16Offset: Int) -> (line: Int, column: Int) {
        let offset = max(0, min(utf16Offset, totalLength))
        var lo = 0
        var hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= offset { lo = mid } else { hi = mid - 1 }
        }
        return (lo + 1, offset - lineStarts[lo] + 1)
    }

    /// (行,列) → UTF-16 偏移；越界输入夹紧。
    func utf16Offset(line: Int, column: Int) -> Int {
        let lineIdx = max(0, min(line - 1, lineStarts.count - 1))
        let offset = lineStarts[lineIdx] + max(0, column - 1)
        return max(0, min(offset, totalLength))
    }
}
