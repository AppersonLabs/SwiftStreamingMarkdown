//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension NSAttributedString.Key {
  /// Marks a run the reader sees but that is not part of the words, such as a
  /// link's site icon. Copied, spoken and "Select more text" text leaves it out.
  /// A `URL` value is the destination a click on the run opens.
  public static let markdownDecoration = NSAttributedString.Key("MarkdownTextDecoration")
}

extension Notification.Name {
  /// Posted with an attachment as its object after its image changed in place.
  static let markdownAttachmentChanged = Notification.Name("MarkdownTextAttachmentChanged")
}

extension NSTextAttachment {
  /// Redraws every Markdown paragraph that shows this attachment after its
  /// image changed in place. Keep its bounds the same, so no text moves.
  @MainActor public func redrawMarkdown() {
    NotificationCenter.default.post(name: .markdownAttachmentChanged, object: self)
  }
}

extension NSAttributedString {
  /// The words, without decorations.
  var plainText: String { plainText(in: NSRange(location: 0, length: length)) }

  /// The words in `range`, clamped to the string, without decorations.
  func plainText(in range: NSRange) -> String {
    withoutDecorations(in: range).string
  }

  /// A copy of `range`, clamped to the string, with every decoration removed.
  func withoutDecorations(in range: NSRange) -> NSAttributedString {
    let clamped = NSIntersectionRange(range, NSRange(location: 0, length: length))
    let copy = NSMutableAttributedString(attributedString: attributedSubstring(from: clamped))
    var decorations: [NSRange] = []
    copy.enumerateAttribute(.markdownDecoration, in: NSRange(location: 0, length: copy.length)) { value, range, _ in
      if value != nil { decorations.append(range) }
    }
    for range in decorations.reversed() { copy.deleteCharacters(in: range) }
    return copy
  }

  /// The destination of the decoration at `index`, if it has one.
  func decorationLink(at index: Int) -> URL? {
    guard index >= 0, index < length else { return nil }
    return attribute(.markdownDecoration, at: index, effectiveRange: nil) as? URL
  }

  /// Whether any decoration lies in `range`.
  func hasDecoration(in range: NSRange) -> Bool {
    let clamped = NSIntersectionRange(range, NSRange(location: 0, length: length))
    var found = false
    enumerateAttribute(.markdownDecoration, in: clamped) { value, _, stop in
      if value != nil { found = true; stop.pointee = true }
    }
    return found
  }

  /// The runs that hold `attachment`.
  func ranges(of attachment: NSTextAttachment) -> [NSRange] {
    var ranges: [NSRange] = []
    enumerateAttribute(.attachment, in: NSRange(location: 0, length: length)) { value, range, _ in
      if (value as AnyObject?) === attachment { ranges.append(range) }
    }
    return ranges
  }
}

extension NSTextStorage {
  /// Redraws the runs that hold `attachment`, if any. Returns whether there were any.
  @discardableResult
  func redraw(_ attachment: NSTextAttachment) -> Bool {
    let ranges = ranges(of: attachment)
    guard !ranges.isEmpty else { return false }
    beginEditing()
    for range in ranges { edited(.editedAttributes, range: range, changeInLength: 0) }
    endEditing()
    return true
  }
}
