import Foundation

// A URLProtocol that serves canned responses keyed by request URL string, so
// source clients can be tested without hitting the network. Register it on an
// ephemeral URLSessionConfiguration and inject the resulting session.
final class StubURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let data: Data
    }

    // Matching is performed by the leading portion of the absolute URL string so
    // tests can register a single stub per host/path even when query items vary.
    nonisolated(unsafe) private static var stubs: [(prefix: String, stub: Stub)] = []
    private static let lock = NSLock()

    static func register(
        urlPrefix: String,
        statusCode: Int = 200,
        json: String,
    ) {
        register(
            urlPrefix: urlPrefix,
            statusCode: statusCode,
            data: Data(json.utf8))
    }

    static func register(
        urlPrefix: String,
        statusCode: Int = 200,
        data: Data,
    ) {
        lock.lock()
        defer { lock.unlock() }
        stubs.append((urlPrefix, Stub(statusCode: statusCode, data: data)))
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        stubs = []
    }

    private static func stub(for url: URL) -> Stub? {
        lock.lock()
        defer { lock.unlock() }
        let absolute = url.absoluteString
        // Prefer the longest matching prefix so more specific stubs win.
        return stubs
            .filter { absolute.hasPrefix($0.prefix) }
            .max(by: { $0.prefix.count < $1.prefix.count })?
            .stub
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let url = request.url,
            let matched = Self.stub(for: url)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: matched.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: matched.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
    }
}
