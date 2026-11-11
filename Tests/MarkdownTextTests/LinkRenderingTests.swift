//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
@testable import SwiftStreamingMarkdown
import XCTest

final class LinkRenderingTests: XCTestCase {

  private let parser = MarkdownParserImpl()

  /// Regression test for a macOS crash: `Link.convert` stored an empty Swift array
  /// as the `.underlineStyle` attribute value, but TextKit expects an `NSNumber`
  /// and AppKit calls `-integerValue` on it, crashing `NSTextView` with
  /// `-[Swift.__EmptyArrayStorage integerValue]` on any rendered link.
  func test_linkUnderlineStyle_bridgesToNSNumber() async {
    let document = await parser.parse(text: "check the [docs](https://example.com) here")
    let renderables = document.convert(with: .default)

    guard case .paragraph(_, let content) = renderables.first else {
      return XCTFail("Expected a single paragraph")
    }

    var foundUnderlineAttribute = false
    var underlineNumber: NSNumber?
    content.enumerateAttribute(.underlineStyle, in: NSRange(location: 0, length: content.length)) { value, _, _ in
      if value != nil {
        foundUnderlineAttribute = true
        underlineNumber = value as? NSNumber
      }
    }
    XCTAssertTrue(foundUnderlineAttribute, "Expected the link run to carry an underlineStyle attribute")
    XCTAssertNotNil(
      underlineNumber,
      "underlineStyle must bridge to NSNumber — AppKit's TextKit calls -integerValue on it and crashes on any other type"
    )
  }

  func test_linkUnderlineStyle_usesConfiguredStyle() async {
    let document = await parser.parse(text: "check the [docs](https://example.com) here")
    let defaults = MarkdownRenderConfig.defaultInlineStyle
    let inlineStyle = MarkdownRenderConfig.MarkdownInlineTextStyle(
      boldTextColor: defaults.boldTextColor,
      linkTextFont: defaults.linkTextFont,
      linkTextColor: defaults.linkTextColor,
      linkUnderlineStyle: .single,
      codeTextFont: defaults.codeTextFont,
      codeTextColor: defaults.codeTextColor,
      codeBackgroundColor: defaults.codeBackgroundColor,
      codeUnderlineColor: defaults.codeUnderlineColor
    )
    let config = MarkdownRenderConfig.default.withInlineStyle(value: inlineStyle)
    let renderables = document.convert(with: config)

    guard case .paragraph(_, let content) = renderables.first else {
      return XCTFail("Expected a single paragraph")
    }

    let linkLocation = content.string.range(of: "docs")?.lowerBound.utf16Offset(in: content.string)
    let underline = linkLocation.flatMap {
      content.attribute(.underlineStyle, at: $0, effectiveRange: nil) as? NSNumber
    }
    XCTAssertEqual(underline?.intValue, NSUnderlineStyle.single.rawValue)
  }

  // MARK: - LinkConfig

  private func firstParagraph(_ text: String, config: MarkdownRenderConfig) async -> NSAttributedString? {
    let document = await parser.parse(text: text)
    guard case .paragraph(_, let content) = document.convert(with: config).first else { return nil }
    return content
  }

  func test_refusedLink_keepsItsTextAndLosesItsDestination() async {
    let config = MarkdownRenderConfig.default.withLinkConfig(
      LinkConfig(id: "web", allows: { $0.scheme == "https" })
    )
    let content = await firstParagraph("open [this](file:///etc/passwd) or [that](https://example.com)", config: config)
    XCTAssertEqual(content?.string, "open this or that")

    var destinations: [URL] = []
    content?.enumerateAttribute(.link, in: NSRange(location: 0, length: content?.length ?? 0)) { value, _, _ in
      if let url = value as? URL { destinations.append(url) }
    }
    XCTAssertEqual(destinations.map(\.absoluteString), ["https://example.com"])
  }

  func test_icon_leadsTheLinkAndOpensItsDestination() async {
    let config = MarkdownRenderConfig.default.withLinkConfig(
      LinkConfig(id: "icons", icon: { _ in NSTextAttachment() })
    )
    let content = await firstParagraph("see [docs](https://example.com)", config: config)
    let iconIndex = ("see " as NSString).length
    XCTAssertNotNil(content?.attribute(.attachment, at: iconIndex, effectiveRange: nil))
    XCTAssertEqual(
      (content?.attribute(.link, at: iconIndex, effectiveRange: nil) as? URL)?.absoluteString,
      "https://example.com"
    )
  }

  func test_linkConfigsCompareByID() {
    XCTAssertEqual(LinkConfig(id: "a", allows: { _ in false }), LinkConfig(id: "a"))
    XCTAssertNotEqual(LinkConfig(id: "a"), LinkConfig(id: "b"))
  }
}
