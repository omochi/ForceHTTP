internal enum FHTTPScheme : String {
    case http = "http"
    case https = "https"
    
    var defaultPort: UInt16 {
        switch self {
        case .http: return 80
        case .https: return 443
        }
    }
}
