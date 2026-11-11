//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftUI

/// A remote Markdown image, drawn by `content` as it loads. Loading goes
/// through `ImageLoader`, never the shared URL session.
struct RemoteImage<Content: View>: View {
  let url: URL
  @ViewBuilder let content: (AsyncImagePhase) -> Content

  @Environment(\.markdownConfig) private var config
  @State private var phase = AsyncImagePhase.empty

  var body: some View {
    content(phase)
      .task(id: url) {
        if let image = await ImageLoader.shared.image(from: url, config: config.imageConfig) {
          phase = .success(Image(mdImage: image))
        } else if !Task.isCancelled {
          phase = .failure(URLError(.cannotDecodeContentData))
        }
      }
  }
}

/// Loads remote images for untrusted Markdown. It keeps no cookies, writes
/// nothing to disk, sends no referrer, and follows a redirect only to a source
/// the same `ImageConfig` accepts, so a public URL cannot bounce the device to
/// its own network. Loaded images stay in memory for the viewer to reuse.
final class ImageLoader: Sendable {
  static let shared = ImageLoader()

  private let session: URLSession
  private let cache = Cache()

  /// - Parameter configuration: Tests pass one with stub protocols; the
  ///   privacy settings are applied over it.
  init(configuration: URLSessionConfiguration = .ephemeral) {
    configuration.httpCookieAcceptPolicy = .never
    configuration.httpShouldSetCookies = false
    configuration.httpCookieStorage = nil
    configuration.urlCache = nil
    configuration.urlCredentialStorage = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    session = URLSession(configuration: configuration)
  }

  /// The image at `url`, or nil when it fails to load, decode or pass `config`.
  func image(from url: URL, config: ImageConfig) async -> MDImage? {
    if let image = cache.image(for: url) { return image }
    guard case .remote = config.resolvedSource(for: url.absoluteString) else { return nil }
    var request = URLRequest(url: url)
    request.setValue("image/*", forHTTPHeaderField: "Accept")
    guard let (data, response) = try? await session.data(for: request, delegate: Redirects(config: config)),
      let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status),
      let image = MDImage(data: data) else {
      return nil
    }
    cache.keep(image, for: url)
    return image
  }

  private final class Redirects: NSObject, URLSessionTaskDelegate, Sendable {
    let config: ImageConfig

    init(config: ImageConfig) { self.config = config }

    func urlSession(
      _ session: URLSession,
      task: URLSessionTask,
      willPerformHTTPRedirection response: HTTPURLResponse,
      newRequest request: URLRequest
    ) async -> URLRequest? {
      guard let url = request.url, case .remote = config.resolvedSource(for: url.absoluteString) else { return nil }
      var request = request
      request.setValue(nil, forHTTPHeaderField: "Referer")
      request.setValue(nil, forHTTPHeaderField: "Cookie")
      return request
    }
  }

  private final class Cache: @unchecked Sendable {
    private let images = NSCache<NSURL, MDImage>()

    init() { images.countLimit = 64 }

    func image(for url: URL) -> MDImage? { images.object(forKey: url as NSURL) }
    func keep(_ image: MDImage, for url: URL) { images.setObject(image, forKey: url as NSURL) }
  }
}
