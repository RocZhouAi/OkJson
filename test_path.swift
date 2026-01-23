import Foundation

let json = """
{
    "user": {
        "name": "Alice",
        "age": 25
    }
}
"""

let data = json.data(using: .utf8)!
let obj = try! JSONSerialization.jsonObject(with: data, options: [])

func printKeys(_ value: Any, path: String = "") {
    if let dict = value as? [String: Any] {
        for (k, v) in dict.sorted(by: { $0.key < $1.key }) {
            let newPath = path.isEmpty ? k : "\(path).\(k)"
            print("Path: \(newPath), Key: \(k)")
            printKeys(v, path: newPath)
        }
    }
}

printKeys(obj, path: "$")
