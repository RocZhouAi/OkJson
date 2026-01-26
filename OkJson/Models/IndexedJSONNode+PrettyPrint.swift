//
//  IndexedJSONNode+PrettyPrint.swift
//  OkJson
//
//  Extension for generating pretty-printed JSON
//

import Foundation

extension IndexedJSONNode {
    
    /// Generates a pretty-printed JSON string from the node tree
    func prettyJSONString(indentation: Int = 2) -> String {
        return generateString(indentLevel: 0, indentationSpy: indentation)
    }
    
    private func generateString(indentLevel: Int, indentationSpy: Int) -> String {
        let indent = String(repeating: " ", count: indentLevel * indentationSpy)
        
        switch type {
        case .object:
            if childCount == 0 { return "{}" }
            
            var result = "{\n"
            let childIndent = String(repeating: " ", count: (indentLevel + 1) * indentationSpy)
            
            // childrenIndices respects shouldSortKeys
            let count = childCount
            for (index, _) in (0..<count).enumerated() {
                guard let child = child(at: index), let key = child.key else { continue }
                
                result += childIndent
                result += "\"\(key)\": "
                result += child.generateString(indentLevel: indentLevel + 1, indentationSpy: indentationSpy)
                
                if index < count - 1 {
                    result += ","
                }
                result += "\n"
            }
            
            result += indent + "}"
            return result
            
        case .array:
            if childCount == 0 { return "[]" }
            
            var result = "[\n"
            let childIndent = String(repeating: " ", count: (indentLevel + 1) * indentationSpy)
            
            let count = childCount
            for (index, _) in (0..<count).enumerated() {
                guard let child = child(at: index) else { continue }
                
                result += childIndent
                result += child.generateString(indentLevel: indentLevel + 1, indentationSpy: indentationSpy)
                
                if index < count - 1 {
                    result += ","
                }
                result += "\n"
            }
            
            result += indent + "]"
            return result
            
        case .string:
            // Ensure strings are properly escaped
            return "\"\(displayValue)\""
            
        case .number, .boolean, .null:
            return displayValue
        }
    }
}
