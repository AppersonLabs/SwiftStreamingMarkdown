//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
@testable import SwiftStreamingMarkdown
import XCTest
#if canImport(AppKit)
import AppKit
#endif

/// Link icons are decoration, and a tap anywhere in a document follows one
/// selection policy.
@MainActor
final class DocumentInteractionTests: XCTestCase {

  private let parser = MarkdownParserImpl()
  private let icon = NSTextAttachment()
  private var config: MarkdownRenderConfig {
    let icon = icon
    return MarkdownRenderConfig.default.withLinkConfig(LinkConfig(id: "icons", icon: { _ in icon }))
  }

  private func document(_ text: String) async -> RenderableDocument {
    let result = await parser.parse(text: text, option: MarkdownParseOption(speculativeRewrite: false))
    return await RenderableDocument(document: result.document, config: config)
  }

  func test_plainText_leavesOutLinkIcons() async {
    let text = await document("""
    # See [docs](https://example.com)

    Read [the guide](https://example.com/guide) first.

    - item [one](https://example.com/1)

    | Site | Note |
    | ---- | ---- |
    | [home](https://example.com) | ok |
    """).plainText
    XCTAssertFalse(text.contains("\u{FFFC}"), text)
    XCTAssertTrue(text.contains("See docs"))
    XCTAssertTrue(text.contains("Read the guide first."))
    XCTAssertTrue(text.contains("item one"))
    XCTAssertTrue(text.contains("home\tok"))
  }

  func test_linkIcon_isMarkedDecorationAndStillOpensTheLink() async {
    guard case .paragraph(_, let content) = await document("see [docs](https://example.com)").renderables.first else {
      return XCTFail("Expected a paragraph")
    }
    let index = ("see " as NSString).length
    XCTAssertNotNil(content.attribute(.markdownDecoration, at: index, effectiveRange: nil))
    XCTAssertNotNil(content.attribute(.link, at: index, effectiveRange: nil))
    XCTAssertNil(content.attribute(.markdownDecoration, at: index + 1, effectiveRange: nil))
    XCTAssertEqual(content.plainText, "see docs")
  }

  func test_redraw_editsOnlyStorageHoldingTheAttachment() {
    let holding = NSTextStorage(attributedString: NSAttributedString(attachment: icon))
    let other = NSTextStorage(string: "plain")
    var edited: [NSTextStorage] = []
    let token = NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: nil, queue: nil) { note in
      if let storage = note.object as? NSTextStorage { edited.append(storage) }
    }
    defer { NotificationCenter.default.removeObserver(token) }
    XCTAssertTrue(holding.redraw(icon))
    XCTAssertFalse(other.redraw(icon))
    XCTAssertEqual(edited.map(ObjectIdentifier.init), [ObjectIdentifier(holding)])
  }

  // MARK: - Taps

  func test_tap_runsWithoutASelection() {
    let controller = MarkdownController(listener: nil)
    let tap = CountingTap()
    controller.tap(tap)
    XCTAssertEqual(tap.count, 1)
  }

  func test_tap_onlyClearsASelectionElsewhereInTheDocument() {
    let controller = MarkdownController(listener: nil)
    let selected = FakeProse(selected: true)
    controller.select(selected)
    let tap = CountingTap()
    controller.tap(tap)
    XCTAssertEqual(tap.count, 0)
    XCTAssertFalse(selected.hasSelection)
    controller.tap(tap)
    XCTAssertEqual(tap.count, 1)
  }

  func test_tap_thatBeganOnASelectionDoesNotRun() {
    let controller = MarkdownController(listener: nil)
    let tap = CountingTap()
    controller.tap(tap, wasSelected: true)
    XCTAssertEqual(tap.count, 0)
  }

  func test_tableActions_needAListener() {
    XCTAssertFalse(MarkdownController(listener: nil).hasListener)
  }

  #if canImport(AppKit)
  func test_paragraphSelection_reachesTheController() {
    let controller = MarkdownController(listener: nil)
    let first = ParagraphNSView()
    let second = ParagraphNSView()
    for view in [first, second] {
      view.setMarkdownController(controller)
      view.setParagraphContents(NSMutableAttributedString(string: "Some prose here"), animatedByWord: false)
    }
    first.setSelectedRange(NSRange(location: 0, length: 4))
    XCTAssertTrue(controller.hasSelection)

    let tap = CountingTap()
    controller.tap(tap)
    XCTAssertEqual(tap.count, 0)
    XCTAssertFalse(first.hasSelection)
    XCTAssertFalse(controller.hasSelection)
  }

  func test_copy_leavesOutLinkIcons() async {
    guard case .paragraph(_, let content) = await document("see [docs](https://example.com) now").renderables.first else {
      return XCTFail("Expected a paragraph")
    }
    let view = ParagraphNSView()
    view.setParagraphContents(content, animatedByWord: false)
    view.selectAll(nil)
    let board = NSPasteboard(name: NSPasteboard.Name("DocumentInteractionTests"))
    board.clearContents()
    XCTAssertTrue(view.writeSelection(to: board, types: [.string, .rtf]))
    XCTAssertEqual(board.string(forType: .string), "see docs now")
    let rtf = board.data(forType: .rtf).flatMap { NSAttributedString(rtf: $0, documentAttributes: nil) }
    XCTAssertEqual(rtf?.string, "see docs now")
    XCTAssertEqual(view.accessibilityLabel(), "see docs now")
  }
  #endif
}

@MainActor
private final class CountingTap: MarkdownTaps {
  var count = 0
  func callAsFunction() { count += 1 }
}

@MainActor
private final class FakeProse: ProseSelection {
  var hasSelection: Bool
  init(selected: Bool) { hasSelection = selected }
  func clearSelection() { hasSelection = false }
}
