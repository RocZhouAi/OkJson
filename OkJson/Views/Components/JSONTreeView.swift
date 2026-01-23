//  JSONTreeView.swift
//  OkJson
//
//  可折叠的 JSON 树形视图（优化版：支持超大型 JSON）

import SwiftUI

/// 树形行类型
enum TreeLine: Identifiable, Equatable {
    case openBrace(JSONNode)
    case closeBrace(JSONNode, Bool)
    case keyValue(JSONNode, Bool)
    case showMore(parentPath: String, currentCount: Int, totalCount: Int, depth: Int)

    var id: String {
        switch self {
        case .openBrace(let node): return "\(node.path)-open"
        case .closeBrace(let node, _): return "\(node.path)-close"
        case .keyValue(let node, _): return "\(node.path)-value"
        case .showMore(let parentPath, _, _, _): return "\(parentPath)-showMore"
        }
    }
    
    static func == (lhs: TreeLine, rhs: TreeLine) -> Bool {
        lhs.id == rhs.id
    }
}

/// JSON 树形视图（支持超大型 JSON）
struct JSONTreeView: View {
    let rootNode: JSONNode
    let colorScheme: ColorSchemeEnum
    var onKeyChange: ((JSONNode, String) -> Void)?
    
    /// 每个容器节点显示的最大子节点数
    private let defaultChildrenLimit = 50
    private let loadMoreStep = 50

    @State private var expandedPaths: Set<String>
    @State private var visibleChildrenCount: [String: Int] = [:]
    @State private var cachedLines: [TreeLine] = []
    @State private var needsRebuild: Bool = true

    init(rootNode: JSONNode, colorScheme: ColorSchemeEnum, onKeyChange: ((JSONNode, String) -> Void)? = nil) {
        self.rootNode = rootNode
        self.colorScheme = colorScheme
        self.onKeyChange = onKeyChange
        // 只展开根节点，避免遍历大型 JSON
        _expandedPaths = State(initialValue: [rootNode.path])
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(cachedLines) { line in
                    TreeLineRow(
                        line: line,
                        colorScheme: colorScheme,
                        isExpanded: isLineExpanded(line),
                        onToggle: { node in toggleExpand(node) },
                        onShowMore: { parentPath, currentCount in showMore(parentPath: parentPath, currentCount: currentCount) }
                    )
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .onAppear {
            if needsRebuild {
                rebuildCache()
                needsRebuild = false
            }
        }
    }
    
    private func toggleExpand(_ node: JSONNode) {
        if expandedPaths.contains(node.path) {
            expandedPaths.remove(node.path)
        } else {
            expandedPaths.insert(node.path)
        }
        rebuildCache()
    }
    
    private func showMore(parentPath: String, currentCount: Int) {
        visibleChildrenCount[parentPath] = currentCount + loadMoreStep
        rebuildCache()
    }
    
    private func rebuildCache() {
        var result: [TreeLine] = []
        result.reserveCapacity(200)
        generateLines(from: rootNode, index: 0, totalCount: 1, result: &result)
        cachedLines = result
    }
    
    private func isLineExpanded(_ line: TreeLine) -> Bool {
        switch line {
        case .openBrace(let node), .closeBrace(let node, _), .keyValue(let node, _):
            return expandedPaths.contains(node.path)
        case .showMore:
            return false
        }
    }

    private func generateLines(
        from node: JSONNode,
        index: Int,
        totalCount: Int,
        result: inout [TreeLine]
    ) {
        let isLast = (index == totalCount - 1)
        let needsComma = !isLast

        switch node.type {
        case .object, .array:
            result.append(.openBrace(node))
            if node.hasChildren && expandedPaths.contains(node.path) {
                let limit = visibleChildrenCount[node.path] ?? defaultChildrenLimit
                let childCount = node.children.count
                let visibleCount = min(limit, childCount)
                
                for i in 0..<visibleCount {
                    let child = node.children[i]
                    let isChildLast = (i == visibleCount - 1) && (visibleCount == childCount)
                    generateLines(from: child, index: i, totalCount: isChildLast ? visibleCount : visibleCount + 1, result: &result)
                }
                
                if visibleCount < childCount {
                    result.append(.showMore(parentPath: node.path, currentCount: visibleCount, totalCount: childCount, depth: node.depth + 1))
                }
            }
            result.append(.closeBrace(node, needsComma))
        default:
            result.append(.keyValue(node, needsComma))
        }
    }
}

/// 单行视图
private struct TreeLineRow: View, Equatable {
    let line: TreeLine
    let colorScheme: ColorSchemeEnum
    let isExpanded: Bool
    let onToggle: (JSONNode) -> Void
    let onShowMore: (String, Int) -> Void
    
    static func == (lhs: TreeLineRow, rhs: TreeLineRow) -> Bool {
        lhs.line.id == rhs.line.id && lhs.isExpanded == rhs.isExpanded
    }

    var body: some View {
        switch line {
        case .showMore(let parentPath, let currentCount, let totalCount, let depth):
            showMoreRow(parentPath: parentPath, currentCount: currentCount, totalCount: totalCount, depth: depth)
        default:
            normalRow
        }
    }
    
    private var normalRow: some View {
        let node = nodeFor(line)!
        let indent = String(repeating: " ", count: node.depth * 2)

        return HStack(alignment: .top, spacing: 0) {
            Text(indent)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.clear)

            if case .openBrace = line, node.hasChildren {
                Button(action: { onToggle(node) }) {
                    Text(isExpanded ? "▼" : "▶")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 16)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 14)
            }

            lineContent(node: node)
        }
    }
    
    private func showMoreRow(parentPath: String, currentCount: Int, totalCount: Int, depth: Int) -> some View {
        let remaining = totalCount - currentCount
        let indent = String(repeating: " ", count: depth * 2)
        
        return HStack(alignment: .center, spacing: 0) {
            Text(indent)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.clear)
            
            Color.clear.frame(width: 14)
            
            Button(action: {
                onShowMore(parentPath, currentCount)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12))
                    Text("显示更多 (\(formatNumber(remaining)) 项)")
                        .font(.system(size: 12))
                }
                .foregroundColor(.accentColor)
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    @ViewBuilder
    private func lineContent(node: JSONNode) -> some View {
        switch line {
        case .openBrace:
            let brace = node.type == .object ? "{" : "["
            HStack(spacing: 0) {
                if let key = node.key {
                    Text("\"\(key)\"")
                        .foregroundColor(colorFor(.key))
                    Text(": ")
                        .foregroundColor(colorFor(.key))
                }
                Text(brace)
                    .foregroundColor(colorFor(.key))
                
                if !isExpanded && node.hasChildren {
                    Text(" \(formatNumber(node.children.count)) 项 ")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(node.type == .object ? "}" : "]")
                        .foregroundColor(colorFor(.key))
                }
            }
            .font(.system(.body, design: .monospaced))

        case .closeBrace(_, let needsComma):
            let brace = node.type == .object ? "}" : "]"
            let comma = needsComma ? "," : ""
            Text("\(brace)\(comma)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

        case .keyValue(_, let needsComma):
            HStack(alignment: .top, spacing: 0) {
                if let key = node.key {
                    Text("\"\(key)\"")
                        .foregroundColor(colorFor(.key))
                    Text(": ")
                        .foregroundColor(colorFor(.key))
                }
                valueText(for: node, needsComma: needsComma)
            }
            .font(.system(.body, design: .monospaced))
            
        case .showMore:
            EmptyView()
        }
    }

    @ViewBuilder
    private func valueText(for node: JSONNode, needsComma: Bool) -> some View {
        let comma = needsComma ? "," : ""
        switch node.type {
        case .string:
            if let str = node.value as? String {
                Text("\"\(str)\"\(comma)")
                    .foregroundColor(colorFor(.string))
            }
        case .number:
            Text("\(node.displayValue)\(comma)")
                .foregroundColor(colorFor(.number))
        case .boolean:
            Text("\(node.displayValue)\(comma)")
                .foregroundColor(colorFor(.boolean))
        case .null:
            Text("null\(comma)")
                .foregroundColor(colorFor(.null))
        default:
            EmptyView()
        }
    }

    private func colorFor(_ token: TokenType) -> Color {
        OkJson.colorFor(token: token, scheme: colorScheme)
    }

    private func nodeFor(_ line: TreeLine) -> JSONNode? {
        switch line {
        case .openBrace(let node), .closeBrace(let node, _), .keyValue(let node, _):
            return node
        case .showMore:
            return nil
        }
    }
}

#Preview {
    let node = JSONNode(
        type: .object,
        children: [
            JSONNode(type: .string, key: "name", value: "张三", depth: 1),
            JSONNode(type: .number, key: "age", value: 25, depth: 1)
        ],
        depth: 0
    )
    JSONTreeView(rootNode: node, colorScheme: .default)
        .frame(width: 500, height: 400)
}
