import Foundation

/// A fake Notion. Suites that use it MUST be `.serialized`, because the handler is shared.
final class NotionStub: URLProtocol, @unchecked Sendable {
  struct Call {
    let method: String
    let path: String
    let body: [String: Any]
  }

  nonisolated(unsafe) static var handler: (Call) throws -> (Int, String) = { _ in (500, "{}") }
  nonisolated(unsafe) static var calls: [Call] = []

  static func session(_ handler: @escaping (Call) throws -> (Int, String)) -> URLSession {
    self.handler = handler
    calls = []
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [NotionStub.self]
    return URLSession(configuration: configuration)
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}

  override func startLoading() {
    let call = Call(
      method: request.httpMethod ?? "GET",
      path: request.url?.path ?? "",
      body: (try? JSONSerialization.jsonObject(with: Self.body(of: request))) as? [String: Any]
        ?? [:]
    )
    Self.calls.append(call)
    do {
      let (status, json) = try Self.handler(call)
      let response = HTTPURLResponse(
        url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: Data(json.utf8))
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  /// URLSession moves the body into a stream before a protocol sees it.
  private static func body(of request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      guard count > 0 else { break }
      data.append(buffer, count: count)
    }
    return data
  }
}
