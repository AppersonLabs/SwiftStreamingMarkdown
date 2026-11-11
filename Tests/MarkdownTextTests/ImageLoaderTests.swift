//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

@testable import SwiftStreamingMarkdown
import XCTest

final class ImageLoaderTests: XCTestCase {

  private let config = ImageConfig(enabled: true, allowedImageTypes: [.publicRemote])

  override func setUp() {
    super.setUp()
    Stub.reset()
  }

  private func loader() -> ImageLoader {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [Stub.self]
    return ImageLoader(configuration: configuration)
  }

  func test_loads_without_cookies_or_referrer() async {
    Stub.routes["https://img.example.com/a.png"] = .image(setCookie: "id=1; Domain=img.example.com")
    Stub.routes["https://img.example.com/b.png"] = .image(setCookie: nil)
    let loader = loader()
    let first = await loader.image(from: URL(string: "https://img.example.com/a.png")!, config: config)
    let second = await loader.image(from: URL(string: "https://img.example.com/b.png")!, config: config)
    XCTAssertNotNil(first)
    XCTAssertNotNil(second)
    XCTAssertEqual(Stub.requests.count, 2)
    for request in Stub.requests {
      XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
      XCTAssertNil(request.value(forHTTPHeaderField: "Referer"))
    }
  }

  func test_refuses_a_redirect_to_a_private_host() async {
    Stub.routes["https://img.example.com/a.png"] = .redirect("https://192.168.1.1/a.png")
    Stub.routes["https://192.168.1.1/a.png"] = .image(setCookie: nil)
    let image = await loader().image(from: URL(string: "https://img.example.com/a.png")!, config: config)
    XCTAssertNil(image)
    XCTAssertEqual(Stub.requests.map(\.url?.host), ["img.example.com"])
  }

  func test_refuses_a_redirect_to_plain_http_or_a_numeric_host() async {
    for target in ["http://img.example.com/a.png", "https://0x7f.1/a.png", "https://localhost/a.png"] {
      Stub.reset()
      Stub.routes["https://img.example.com/a.png"] = .redirect(target)
      Stub.routes[target] = .image(setCookie: nil)
      let image = await loader().image(from: URL(string: "https://img.example.com/a.png")!, config: config)
      XCTAssertNil(image, target)
      XCTAssertEqual(Stub.requests.count, 1, target)
    }
  }

  func test_follows_a_redirect_to_a_public_host() async {
    Stub.routes["https://img.example.com/a.png"] = .redirect("https://cdn.example.org/a.png")
    Stub.routes["https://cdn.example.org/a.png"] = .image(setCookie: nil)
    let image = await loader().image(from: URL(string: "https://img.example.com/a.png")!, config: config)
    XCTAssertNotNil(image)
    XCTAssertEqual(Stub.requests.map(\.url?.host), ["img.example.com", "cdn.example.org"])
  }

  func test_never_requests_a_source_the_config_refuses() async {
    Stub.routes["https://10.0.0.1/a.png"] = .image(setCookie: nil)
    let image = await loader().image(from: URL(string: "https://10.0.0.1/a.png")!, config: config)
    XCTAssertNil(image)
    XCTAssertTrue(Stub.requests.isEmpty)
  }

  func test_keeps_a_loaded_image_in_memory() async {
    Stub.routes["https://img.example.com/a.png"] = .image(setCookie: nil)
    let loader = loader()
    _ = await loader.image(from: URL(string: "https://img.example.com/a.png")!, config: config)
    let again = await loader.image(from: URL(string: "https://img.example.com/a.png")!, config: config)
    XCTAssertNotNil(again)
    XCTAssertEqual(Stub.requests.count, 1)
  }
}

/// Serves canned responses and records each request it sees.
private final class Stub: URLProtocol {
  enum Route {
    case image(setCookie: String?)
    case redirect(String)
  }

  nonisolated(unsafe) static var routes: [String: Route] = [:]
  nonisolated(unsafe) static var requests: [URLRequest] = []
  private static let lock = NSLock()

  static func reset() {
    lock.withLock {
      routes = [:]
      requests = []
    }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url else { return }
    let route = Self.lock.withLock {
      Self.requests.append(request)
      return Self.routes[url.absoluteString]
    }
    switch route {
    case .image(let cookie):
      var headers = ["Content-Type": "image/png"]
      headers["Set-Cookie"] = cookie
      let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: Self.png)
      client?.urlProtocolDidFinishLoading(self)
    case .redirect(let target):
      let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Location": target])!
      client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: URL(string: target)!), redirectResponse: response)
      // A refused redirect ends with the 302 itself, as it does over HTTP.
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocolDidFinishLoading(self)
    case nil:
      client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
    }
  }

  override func stopLoading() {}

  /// A 1×1 PNG.
  static let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
}
