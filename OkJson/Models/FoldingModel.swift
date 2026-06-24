//  FoldingModel.swift
//  OkJson
//
//  从 JSON 文本计算代码折叠区间：每个跨多行的 {} / [] 产生一个区间。
//  纯文本括号配对扫描，跳过字符串内部括号；不依赖 JSON 是否完全合法。

import Foundation

struct FoldRange: Equatable {
    let startLine: Int
    let endLine: Int
}

enum FoldingModel {
    static func foldRanges(in text: String) -> [FoldRange] {
        let ns = text as NSString
        let len = ns.length
        var ranges: [FoldRange] = []
        var stack: [Int] = []   // 开括号所在行号
        var line = 1
        var i = 0
        var inString = false

        while i < len {
            let c = ns.character(at: i)
            if inString {
                if c == 92 { i += 2; continue }       // \ 跳过转义的下一个字符
                if c == 34 { inString = false }       // 闭引号
                else if c == 10 { line += 1 }         // 字符串内换行也计行
                i += 1
                continue
            }
            switch c {
            case 34: inString = true                  // "
            case 123, 91: stack.append(line)          // { [
            case 125, 93:                              // } ]
                if let openLine = stack.popLast(), line > openLine {
                    ranges.append(FoldRange(startLine: openLine, endLine: line))
                }
            case 10: line += 1                         // \n
            default: break
            }
            i += 1
        }

        return ranges.sorted {
            $0.startLine != $1.startLine ? $0.startLine < $1.startLine : $0.endLine < $1.endLine
        }
    }
}
