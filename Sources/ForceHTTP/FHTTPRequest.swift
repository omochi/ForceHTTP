public struct FHTTPRequest {
    public var url: URL
    public var method: FHTTPMethod
    public var header: FHTTPHeader
    
    public private(set) var postBody: Data?
    
    public init(url: URL,
                method: FHTTPMethod = .get) {
        self.url = url
        self.method = method
        self.header = FHTTPHeader()
        
        header["Host"] = requestHeaderHost
    }
    
    public func session(service: FHTTPService = FHTTPService.shared)
        -> FHTTPSession
    {
        return FHTTPSession(service: service, request: self)
    }
    
    public mutating func setPostBody(contentType: String, data: Data) {
        self.header["Content-Type"] = contentType
        self.header["Content-Length"] = String(data.count)
        self.postBody = data
    }

    internal var scheme: FHTTPScheme {
        guard let schemeStr = url.scheme else {
            fatalError("invalid URL: no scheme")
        }
        guard let scheme = FHTTPScheme(rawValue: schemeStr) else {
            fatalError("invalid URL: unsupported scheme (\(schemeStr))")
        }
        return scheme
    }
    
    internal var host: String {
        guard let host = url.host else {
            fatalError("invalid URL: no host")
        }
        return host
    }
    
    internal var specifiedPort: UInt16? {
        guard let portInt = url.port else {
            return nil
        }
        
        guard let port = UInt16(exactly: portInt) else {
            fatalError("invalid port: \(portInt)")
        }
        return port
    }

    internal var connectingPort: UInt16 {
        return specifiedPort ?? scheme.defaultPort
    }
    
    internal var requestHeaderHost: String {
        var host: String = self.host
        
        if connectingPort != scheme.defaultPort {
            host += ":" + String(connectingPort)
        }
        
        return host
    }
    
    internal var path: String {
        var path: String = url.path
        if path == "" {
            path = "/"
        }
        
        if let query = url.query {
            path += "?" + query
        }
        
        return path
    }
}
