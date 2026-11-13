//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

#if canImport(AppKit)
import AppKit
import SwiftUI
@testable import SwiftStreamingMarkdown
import Testing

@Suite("ParagraphNSView Measurement Tests")
@MainActor
struct ParagraphNSViewTests {

  final class Probe: ParagraphNSView {
    var invalidations = 0

    override func invalidateIntrinsicContentSize() {
      invalidations += 1
      super.invalidateIntrinsicContentSize()
    }
  }

  @Test("Unchanged layout keeps its intrinsic size")
  func unchangedLayoutKeepsItsSize() {
    let view = Probe()
    view.frame = CGRect(x: 0, y: 0, width: 240, height: 200)
    view.setParagraphContents(NSMutableAttributedString(string: String(repeating: "word ", count: 200)), animatedByWord: false)
    _ = view.intrinsicContentSize
    view.layout()
    view.invalidations = 0
    for _ in 0..<3 { view.layout() }
    #expect(view.invalidations == 0)
  }

  @Test("A new width changes the intrinsic size before layout")
  func aNewWidthChangesItsSize() {
    let view = ParagraphNSView()
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    view.setParagraphContents(NSMutableAttributedString(string: String(repeating: "word ", count: 200)), animatedByWord: false)
    let narrow = view.intrinsicContentSize
    view.frame.size.width = 600
    let wide = view.intrinsicContentSize
    #expect(wide.height > 0)
    #expect(wide.height < narrow.height)
  }

  @Test("An unset width does not use the screen")
  func anUnsetWidthHasNoIntrinsicSize() {
    let view = ParagraphNSView()
    #expect(view.intrinsicContentSize == NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric))
  }

  @Test("Unspecified SwiftUI measurement keeps the text's natural size")
  func anUnspecifiedProposalFitsTheText() {
    let text = NSMutableAttributedString(string: "A table cell with text", attributes: [.font: NSFont.systemFont(ofSize: 13)])
    let host = NSHostingView(rootView: ParagraphView(contents: text, lineSpacing: nil))
    let size = host.fittingSize
    #expect(size.width > 100)
    #expect(size.height > 0)
  }

  /// Regression: a paragraph is often measured before SwiftUI has given the view a frame
  /// (e.g. during a navigation transition). Measuring through the view's own text container
  /// used to return a zero height in that state because `widthTracksTextView` forces the
  /// container width to follow the frame width (0), collapsing the paragraph. Measurement
  /// must instead honor the requested width regardless of the view's frame.
  @Test("Measures a non-zero, width-dependent height without a frame")
  func measuresHeightWithoutFrame() {
    let view = ParagraphNSView()
    let longText = String(repeating: "word ", count: 200)
    view.setParagraphContents(NSMutableAttributedString(string: longText), animatedByWord: false)

    let narrow = view.measureSize(fittingWidth: 200)
    let wide = view.measureSize(fittingWidth: 1000)

    #expect(narrow.height > 0, "Wrapping content must have a non-zero height even without a frame")
    #expect(wide.height > 0, "Wrapping content must have a non-zero height even without a frame")
    #expect(
      narrow.height > wide.height,
      "A narrower width must wrap to more lines and therefore be taller, proving the requested width is honored"
    )
  }

  @Test("Empty content measures as zero")
  func measuresEmptyContentAsZero() {
    let view = ParagraphNSView()
    view.setParagraphContents(NSMutableAttributedString(string: ""), animatedByWord: false)

    #expect(view.measureSize(fittingWidth: 400) == .zero)
  }
}
#endif
