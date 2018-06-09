public enum FHTTPError : Error, CustomStringConvertible {
    case tooLargeResponseHeader
    case noResponseHeader
    case invalidResponseHeader
    case responseHasNoContentLength
    case protocolViolation
    case abnormalTermination
    case connectionClosed
    case statusCodeFailure(FHTTPResponse)
    case tooManyRedirect
    case nonPostRequestHaveBody
    
    public var description: String {
        switch self {
        case .tooLargeResponseHeader:
            return "response header is too large"
        case .noResponseHeader:
            return "no response header"
        case .invalidResponseHeader:
            return "response header is invalid format"
        case .responseHasNoContentLength:
            return "response header has no content length"
        case .protocolViolation:
            return "server violates protocol"
        case .abnormalTermination:
            return "abnormal termination"
        case .connectionClosed:
            return "connection closed"
        case .statusCodeFailure(let response):
            return "\(response.statusCode) \(response.statusMessage)"
        case .tooManyRedirect:
            return "too many redirect"
        case .nonPostRequestHaveBody:
            return "non post request have body"
        }
    }
}
