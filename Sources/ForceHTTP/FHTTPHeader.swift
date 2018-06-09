import Foundation

public struct FHTTPHeader : CustomStringConvertible {
    public struct Entry {
        public var name: String
        public var value: String
    }
    
    public var entries: [Entry]
    
    public var description: String {
        return entries.map { $0.name + ": " + $0.value }
            .joined(separator: "\n")
    }
    
    public init() {
        self.entries = []
    }
    
    public init(from string: String) {
        var entries: [Entry] = []
        
        let lines: [String] = string.components(separatedBy: "\r\n")
        
        lines.forEach { line in
            guard let range = line.range(of: ":") else {
                return
            }
            
            let name: String = line[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let value: String = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            
            entries.append(Entry(name: name, value: value))
        }
        
        self.entries = entries
    }

    
    public subscript(name: String) -> String? {
        get {
            guard let index = (entries.firstIndex { $0.name == name }) else {
                return nil
            }
            return entries[index].value
        }
        set {
            guard let newValue = newValue else {
                entries.removeAll { $0.name == name }
                return
            }
      
            guard let index = (entries.firstIndex { $0.name == name }) else {
                entries.append(Entry(name: name, value: newValue))
                return
            }
            
            entries[index].value = newValue
        }
    }
    
    public var contentLength: Int? {
        get {
            guard let str = self["Content-Length"],
                let value = Int(str), value >= 0 else {
                    return nil
            }
            return value
        }
        set {
            self["Content-Length"] = newValue.map { String($0) }
        }
    }
}
