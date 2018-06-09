// running on service work queue
// access from any queue

import Foundation

public class FHTTPSession {
    public enum State {
        case inited
        case connecting
        case connected
        case requestBodySend
        case responseHeaderReceive
        case responseHeaderReceived
        case responseBodyReceive
        case completed
        case failed
        case closed
    }
    
    public struct RedirectEntry {
        public var request: FHTTPRequest
        public var response: FHTTPResponse
    }
   
    public let service: FHTTPService
    private let workQueue: DispatchQueue
    public let callbackQueue: DispatchQueue
    
    public private(set) var request: FHTTPRequest
    
    public private(set) var currentRequest: FHTTPRequest {
        get {
            guard let last = redirects.last else {
                return request
            }
            return last.request
        }
        set {
            if redirects.count == 0 {
                request = newValue
                return
            }
            
            var entry = redirects.last!
            entry.request = newValue
            redirects[redirects.count - 1] = entry
        }
    }
    
    public private(set) var sentBodySize: Int
    
    public private(set) var state: State
    
    private typealias Handler = (FHTTPResponse?, Error?) -> Void
    private var handler: Handler?
    
    public private(set) var redirects: [RedirectEntry] = []
    
    public private(set) var response: FHTTPResponse?
    
    internal init(service: FHTTPService,
                  request: FHTTPRequest)
    {
        self.service = service
        self.workQueue = service.workQueue
        self.callbackQueue = DispatchQueue.main
        self.request = request
        self.state = .inited
        self.sentBodySize = 0
    }
    
    deinit {
        _close()
    }
    
    public func start(handler: @escaping (FHTTPResponse?, Error?) -> Void) {
        workQueue.sync {
            precondition(state == .inited)
            
            self.handler = handler
            state = .connecting
            
            service.onSessionStart(self)
        }
    }

    public func close() {
        workQueue.sync {
            _close()
        }
    }
    
    private func _close() {
        state = .closed
        
        service.onSessionClose(self)
        
        self.handler = nil
    }
    
    internal var connection: FHTTPConnection? {
        return service.connections.first { $0.session === self }
    }
    
    internal func isSameEndPoint(_ connection: FHTTPConnection) -> Bool {
        let request = self.currentRequest
        return request.scheme == connection.scheme &&
            request.host == connection.host &&
            request.connectingPort == connection.port
    }
    
    private func redirect(url: URL) {
        precondition(state == .completed)
        
        redirects.append(RedirectEntry(request: currentRequest, response: response!))
        
        state = .connecting
        response = nil
        sentBodySize = 0
        
        let request = FHTTPRequest(url: url)
        self.currentRequest = request
        
        service.update()
    }
    
    internal func onAttachConnection(_ connection: FHTTPConnection) {
        log("attach: \(connection.endPointString)")
        precondition(state == .connecting)
        
        state = .connected
    }

    internal func onRequestHeaderSend() throws -> Data {
//        print("onRequestHeaderSend")
        
        let request = self.currentRequest
        
        if request.postBody != nil && request.method != .post {
            throw FHTTPError.nonPostRequestHaveBody
        }
        
        var header = request.header
        
        header["Connection"] = "keep-alive"
        header["User-Agent"] = service.userAgent
        
        self.currentRequest.header = header
        
        var lines: [String] = []
        
        lines.append("\(request.method) \(request.path) HTTP/1.1")
        header.entries.forEach { entry in
            lines.append(entry.name + ": " + entry.value)
        }

        lines += ["", ""]
        
        let headerString: String = lines.joined(separator: "\r\n")
        let data = headerString.data(using: String.Encoding.utf8)!
        
        if request.postBody != nil {
            self.state = .requestBodySend
        } else {
            self.state = .responseHeaderReceive
        }
        
        return data
    }
    
    internal func onRequestBodySend(maxChunkSize: Int) -> Data? {
        let data = request.postBody!
        let chunkSize = min(data.count - sentBodySize, maxChunkSize)
        if chunkSize == 0 {
            state = .responseHeaderReceive
            return nil
        }
        
        let startSize = sentBodySize
        sentBodySize += chunkSize
        
        return data[startSize..<sentBodySize]
    }
    
    internal func onResponseHeader(_ response: FHTTPResponse) {
//        print("onResponseHeader")
        self.response = response
        self.state = .responseHeaderReceived
        
        self.state = .responseBodyReceive
        self.service.onSessionReceiveContent(self)
    }
    
    internal func onResponseBody(_ data: Data?) {
        precondition(state == .responseBodyReceive)
        
        if let data = data {
            response!.data.append(data)
            log("response: +\(data.count) => \(response!.data.count)/\(response!.header.contentLength!) bytes")
        } else {
            self.state = .completed
        }
    }
    
    internal func onDetachConnection(_ connection: FHTTPConnection) {
        log("detach: \(connection.endPointString)")

        precondition(state == .completed)
        
        let response = self.response!
        let code = response.statusCode
        
        var error: Error? = nil
        
        if 200 <= code && code < 300 {
            //
        } else if 300 <= code && code < 400 {
            if let location = response.header["Location"],
                let url = URL(string: location)
            {
                if redirects.count < 16 {
                    redirect(url: url)
                    return
                }
                
                error = FHTTPError.tooManyRedirect
            }
        } else {
            error = FHTTPError.statusCodeFailure(response)
        }
        
        callbackQueue.async {
            let handler = self.workQueue.sync {
                return self.handler
            }
            
            if let error = error {
                handler?(nil, error)
            } else {
                handler?(response, nil)
            }
            
            self.close()
        }
    }
    
    internal func onError(_ error: Error) {
        state = .failed
        
        callbackQueue.async {
            let handler = self.workQueue.sync {
                return self.handler
            }
            
            handler?(nil, error)
            
            self.close()
        }
    }
    
    private func log(_ message: String) {
        print("[FHTTPSession(\(request.url.absoluteString)]\n    \(message)")
    }
}
