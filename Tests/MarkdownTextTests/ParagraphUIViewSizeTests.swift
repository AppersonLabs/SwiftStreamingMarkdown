//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

#if canImport(UIKit)
@testable import SwiftStreamingMarkdown
import Testing
import UIKit

@Suite("ParagraphUIView sizing")
@MainActor
struct ParagraphUIViewSizeTests {
  final class Probe: ParagraphUIView {
    var invalidations = 0

    override func invalidateIntrinsicContentSize() {
      invalidations += 1
      super.invalidateIntrinsicContentSize()
    }
  }

  @Test func unchangedLayoutKeepsItsSize() {
    let view = Probe()
    view.frame = CGRect(x: 0, y: 0, width: 240, height: 200)
    view.setParagraphContents(NSMutableAttributedString(string: String(repeating: "word ", count: 200)), animatedByWord: false)
    _ = view.intrinsicContentSize
    view.layoutSubviews()
    view.invalidations = 0
    for _ in 0..<3 { view.layoutSubviews() }
    #expect(view.invalidations == 0)
  }

  @Test func aNewWidthChangesItsSize() {
    let view = ParagraphUIView()
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    view.setParagraphContents(NSMutableAttributedString(string: String(repeating: "word ", count: 200)), animatedByWord: false)
    let narrow = view.intrinsicContentSize
    view.frame.size.width = 600
    let wide = view.intrinsicContentSize
    #expect(wide.height > 0)
    #expect(wide.height < narrow.height)
  }

  @Test func anUnsetWidthHasNoIntrinsicSize() {
    let view = ParagraphUIView()
    #expect(view.intrinsicContentSize == CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric))
  }
}
#endif
