//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftUI

/// A text view in a document that can hold a selection. It reports changes to
/// the document's `MarkdownController`, which decides what a tap does.
@MainActor
protocol ProseSelection: AnyObject {
  var hasSelection: Bool { get }
  func clearSelection()
}

/// Sends taps on a block drawn by SwiftUI to the document's tap handler. Child
/// controls such as Copy keep their own taps. Never put it on a view that
/// holds a paragraph: the paragraph's text view handles its own taps.
struct DocumentTap: ViewModifier {
  @Environment(\.markdownController) private var controller
  @Environment(\.markdownTap) private var action

  func body(content: Content) -> some View {
    if let controller, let action {
      content
        .contentShape(Rectangle())
        .onTapGesture { controller.tap(action) }
    } else {
      content
    }
  }
}

/// A clear area that sends taps to the document's tap handler. It goes behind
/// views that hold paragraphs, so it takes only the gaps between them.
struct DocumentTapArea: View {
  var body: some View {
    Color.clear.modifier(DocumentTap())
  }
}

extension View {
  /// See `DocumentTap`.
  func documentTap() -> some View {
    modifier(DocumentTap())
  }
}
