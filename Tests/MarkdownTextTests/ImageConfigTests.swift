//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

@testable import SwiftStreamingMarkdown
import XCTest

final class ImageConfigTests: XCTestCase {

  private func url(_ string: String) -> URL {
    guard let url = URL(string: string) else {
      fatalError("Invalid test URL: \(string)")
    }
    return url
  }

  private func remoteConfig(_ domains: [String] = [], enabled: Bool = true) -> ImageConfig {
    ImageConfig(enabled: enabled, allowedImageTypes: [.remote(allowedDomains: domains)])
  }

  func test_disabled_config_allows_nothing() {
    XCTAssertNil(remoteConfig(enabled: false).resolvedSource(for: "https://example.com/a.png"))
  }

  func test_enabled_without_allowed_types_allows_nothing() {
    XCTAssertNil(ImageConfig(enabled: true).resolvedSource(for: "https://example.com/a.png"))
  }

  func test_nil_or_empty_source_is_not_resolved() {
    XCTAssertNil(remoteConfig().resolvedSource(for: nil))
    XCTAssertNil(remoteConfig().resolvedSource(for: ""))
  }

  func test_empty_allowed_domains_permits_any_https_host() {
    XCTAssertEqual(
      remoteConfig().resolvedSource(for: "https://anything.example/a.png"),
      .remote(url("https://anything.example/a.png"))
    )
  }

  func test_plain_http_is_never_allowed() {
    XCTAssertNil(remoteConfig().resolvedSource(for: "http://anything.example/a.png"))
  }

  func test_allowed_domain_matches_exact_and_subdomains() {
    let config = remoteConfig(["markdownguide.org"])
    XCTAssertNotNil(config.resolvedSource(for: "https://markdownguide.org/a.png"))
    XCTAssertNotNil(config.resolvedSource(for: "https://www.markdownguide.org/a.png"))
    XCTAssertNil(config.resolvedSource(for: "https://example.com/a.png"))
    XCTAssertNil(config.resolvedSource(for: "https://notmarkdownguide.org/a.png"))
  }

  func test_domain_matching_is_case_insensitive() {
    let config = remoteConfig(["Markdownguide.ORG"])
    XCTAssertNotNil(config.resolvedSource(for: "https://WWW.MarkdownGuide.org/a.png"))
  }

  func test_non_http_schemes_are_not_allowed() {
    XCTAssertNil(remoteConfig().resolvedSource(for: "file:///tmp/a.png"))
    XCTAssertNil(remoteConfig().resolvedSource(for: "ftp://example.com/a.png"))
  }

  func test_asset_catalog_permission_requires_type_and_enabled() {
    XCTAssertFalse(ImageConfig(enabled: false, allowedImageTypes: [.assetCatalog]).allowsAssetCatalog)
    XCTAssertFalse(ImageConfig(enabled: true, allowedImageTypes: [.remote(allowedDomains: [])]).allowsAssetCatalog)
    XCTAssertTrue(ImageConfig(enabled: true, allowedImageTypes: [.assetCatalog]).allowsAssetCatalog)
  }

  func test_bundled_resource_permission_requires_type_and_enabled() {
    XCTAssertFalse(ImageConfig(enabled: false, allowedImageTypes: [.bundledResource]).allowsBundledResource)
    XCTAssertFalse(ImageConfig(enabled: true, allowedImageTypes: [.assetCatalog]).allowsBundledResource)
    XCTAssertTrue(ImageConfig(enabled: true, allowedImageTypes: [.bundledResource]).allowsBundledResource)
  }

  func test_asset_catalog_type_does_not_permit_remote_urls() {
    let config = ImageConfig(enabled: true, allowedImageTypes: [.assetCatalog])
    XCTAssertNil(config.resolvedSource(for: "https://example.com/a.png"))
  }

  func test_fullscreen_viewer_is_enabled_by_default() {
    XCTAssertTrue(ImageConfig(enabled: true, allowedImageTypes: [.assetCatalog]).fullscreenViewerEnabled)
    XCTAssertTrue(ImageConfig.disabled.fullscreenViewerEnabled)
  }

  func test_fullscreen_viewer_can_be_disabled() {
    let config = ImageConfig(enabled: true, allowedImageTypes: [.assetCatalog], fullscreenViewerEnabled: false)
    XCTAssertFalse(config.fullscreenViewerEnabled)
  }

  func test_fullscreen_viewer_flag_affects_equality() {
    let on = ImageConfig(enabled: true, allowedImageTypes: [.assetCatalog], fullscreenViewerEnabled: true)
    let off = ImageConfig(enabled: true, allowedImageTypes: [.assetCatalog], fullscreenViewerEnabled: false)
    XCTAssertNotEqual(on, off)
  }

  // MARK: - Public hosts

  func test_publicRemote_allows_public_hosts_only() {
    let config = ImageConfig(enabled: true, allowedImageTypes: [.publicRemote])
    XCTAssertNotNil(config.resolvedSource(for: "https://cdn.example.com/a.png"))
    for source in [
      "https://localhost/a.png",
      "https://intranet/a.png",
      "https://192.168.1.10/a.png",
      "https://[::1]/a.png",
      "https://printer.local/a.png",
      "https://build.internal/a.png",
      "http://cdn.example.com/a.png"
    ] {
      XCTAssertNil(config.resolvedSource(for: source), source)
    }
  }

  func test_isPublicHost_ignores_case_and_a_trailing_dot() {
    XCTAssertTrue(ImageConfig.isPublicHost("Example.COM."))
    XCTAssertFalse(ImageConfig.isPublicHost("Router.Home.Arpa"))
  }

  func test_isPublicHost_refuses_every_spelling_of_an_address() {
    for host in [
      "127.0.0.1", "0x7f.0.0.1", "0x7f.1", "0X7F.1", "0xc0.0xa8.1.1", "0300.0250.1.1",
      "2130706433", "017700000001", "0x7f000001", "127.1", "1.2.3.4.5", "foo.0x7f", "foo.123",
      "foo.0x", "::1", "[::1]", "::ffff:127.0.0.1", "fe80::1%en0", "169.254.169.254"
    ] {
      XCTAssertFalse(ImageConfig.isPublicHost(host), host)
    }
  }

  func test_isPublicHost_refuses_reserved_and_malformed_names() {
    for host in [
      "localhost", "intranet", "a.localhost", "printer.local", "x.localdomain", "build.internal",
      "nas.lan", "foo.test", "foo.invalid", "foo.example", "1.0.0.127.in-addr.arpa", "router.home.arpa",
      "a..com", ".com", "-a.com", "a-.com", "a_b.com", "127%2e0%2e0%2e1", "a b.com", ""
    ] {
      XCTAssertFalse(ImageConfig.isPublicHost(host), host)
    }
  }

  func test_isPublicHost_allows_public_names() {
    for host in ["example.com", "cdn.example.com", "1password.com", "123.example.com", "a-b.co.uk", "xn--mnchen-3ya.de", "münchen.de"] {
      XCTAssertTrue(ImageConfig.isPublicHost(host), host)
    }
  }

  func test_publicRemote_refuses_numeric_hosts_in_urls() {
    let config = ImageConfig(enabled: true, allowedImageTypes: [.publicRemote])
    for source in ["https://0x7f.0.0.1/a", "https://0x7f.1/a", "https://0xc0.0xa8.1.1/a", "https://017700000001/a", "https://2130706433/a"] {
      XCTAssertNil(config.resolvedSource(for: source), source)
    }
  }
}
