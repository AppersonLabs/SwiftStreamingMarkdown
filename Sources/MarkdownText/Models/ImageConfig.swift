//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation

/// Configuration controlling whether and how Markdown images are rendered as
/// block-level content.
///
/// - Important: Image support is **experimental**. The behavior, API, and
///   rendering output may change in future releases.
public struct ImageConfig: Hashable, Sendable {

  /// A category of image source permitted while image rendering is enabled.
  public enum ImageType: Hashable, Sendable {
    /// Remote images loaded over `https`, restricted to the hosts in
    /// `allowedDomains`. Plain `http` is never permitted.
    ///
    /// An empty list permits any host. Matching is case-insensitive and
    /// includes subdomains, so `example.com` also matches `cdn.example.com`.
    ///
    /// Maps from sources with an `https` scheme, e.g.
    /// `![logo](https://example.com/logo.png)`.
    case remote(allowedDomains: [String])

    /// Remote images loaded over `https` from any public host, as judged by
    /// `ImageConfig.isPublicHost(_:)`. Use it for untrusted Markdown, where an
    /// image must not make the device fetch from its own network.
    case publicRemote

    /// Bundled images resolved from the app's asset catalog by name via
    /// `Image(_:)`.
    ///
    /// Maps from sources with an `assets` scheme, where the asset name is the
    /// remainder of the source, e.g. `![logo](assets://Images/logo)` resolves
    /// the asset named `Images/logo`.
    case assetCatalog

    /// Bundled images resolved from a loose resource file in the app's main
    /// bundle by name.
    ///
    /// Maps from scheme-less relative paths, e.g. `![logo](logo.png)` or
    /// `![logo](./logo.png)`.
    case bundledResource
  }

  /// Whether Markdown images are rendered as block-level content.
  public let enabled: Bool

  /// The image sources permitted while `enabled` is `true`. An image whose
  /// source matches none of these types renders a placeholder instead.
  public let allowedImageTypes: [ImageType]

  /// Whether tapping a rendered image opens the built-in, zoomable fullscreen
  /// image viewer. Independent of `MarkdownListener.onImageTap(image:)`, which
  /// always fires on tap regardless of this flag.
  public let fullscreenViewerEnabled: Bool

  /// Create an image configuration.
  /// - Parameters:
  ///   - enabled: See `enabled`. Defaults to `false`.
  ///   - allowedImageTypes: See `allowedImageTypes`. Defaults to empty, which
  ///     permits no image sources.
  ///   - fullscreenViewerEnabled: See `fullscreenViewerEnabled`. Defaults to
  ///     `true`.
  public init(
    enabled: Bool = false,
    allowedImageTypes: [ImageType] = [],
    fullscreenViewerEnabled: Bool = true
  ) {
    self.enabled = enabled
    self.allowedImageTypes = allowedImageTypes
    self.fullscreenViewerEnabled = fullscreenViewerEnabled
  }

  /// Image support disabled.
  public static let disabled = ImageConfig(enabled: false)

  /// Whether `host` is a name on the public internet: a dotted DNS name that
  /// is neither an IP address in any spelling nor under a suffix reserved for
  /// local or test use.
  ///
  /// URL parsers read a host whose last label is a number as IPv4, so
  /// `0x7f.1`, `2130706433` and `017700000001` all reach 127.0.0.1. Any such
  /// host is refused, as is anything outside letters, digits and hyphens.
  /// A public name can still resolve to a private address; only resolving it
  /// would tell.
  public static func isPublicHost(_ host: String) -> Bool {
    var name = host.lowercased()
    if name.hasSuffix(".") { name.removeLast() }
    let labels = name.split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count > 1, let last = labels.last,
      labels.allSatisfy(isLabel), !isNumber(last), !isAddress(name) else {
      return false
    }
    return !reservedSuffixes.contains { name == $0 || name.hasSuffix("." + $0) }
  }

  /// Suffixes for loopback, link-local, private-network and test names
  /// (RFC 2606, RFC 6761, RFC 6762, RFC 8375) and common intranet names.
  private static let reservedSuffixes = [
    "localhost", "local", "localdomain", "internal", "intranet", "lan", "home", "corp", "private",
    "test", "invalid", "example", "arpa"
  ]

  /// A DNS label: letters, digits and inner hyphens. Characters beyond ASCII
  /// pass so an internationalized name still reads as one.
  private static func isLabel(_ label: Substring) -> Bool {
    !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-"
      && label.unicodeScalars.allSatisfy { scalar in
        !scalar.isASCII || ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) || scalar == "-"
      }
  }

  /// Whether a URL parser would read `label`, as the last label of a host, as
  /// an IPv4 part: decimal, octal or `0x` hex.
  private static func isNumber(_ label: Substring) -> Bool {
    if label.hasPrefix("0x") { return label.dropFirst(2).allSatisfy(\.isHexDigit) }
    return label.allSatisfy(\.isASCII) && label.allSatisfy(\.isNumber)
  }

  /// Whether the system resolver would take `name` as a literal address.
  private static func isAddress(_ name: String) -> Bool {
    var v4 = in_addr()
    var v6 = in6_addr()
    return inet_aton(name, &v4) != 0 || inet_pton(AF_INET6, name, &v6) == 1
  }

  /// Whether bundled asset-catalog images are permitted under this config.
  var allowsAssetCatalog: Bool {
    guard enabled else { return false }
    return allowedImageTypes.contains { $0 == .assetCatalog }
  }

  /// Whether loose bundled resource images are permitted under this config.
  var allowsBundledResource: Bool {
    guard enabled else { return false }
    return allowedImageTypes.contains { $0 == .bundledResource }
  }
}
