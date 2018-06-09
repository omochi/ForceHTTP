public enum FHTTPMethod : String, CustomStringConvertible {
    case get = "GET"
    case post = "POST"
    
    public var description: String {
        return self.rawValue
    }
}
