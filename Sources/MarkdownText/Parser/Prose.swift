//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import Markdown

/// Where a Markdown source holds prose: the text of paragraphs, headings and
/// table cells, outside code spans, raw HTML, link or image destinations and
/// URLs written out in the text. Code blocks at any depth (fenced, indented,
/// quoted or inside a list), HTML blocks and link reference definitions are
/// never prose.
///
/// The LaTeX preprocessor rewrites the source before the real parse, so it
/// asks this first parse which characters it may touch.
struct Prose {
  private let source: String
  /// one flag per UTF-8 byte of `source`
  private var flags: [Bool]
  private let lineStarts: [Int]

  init(_ source: String) {
    self.source = source
    flags = Array(repeating: false, count: source.utf8.count)
    var starts = [0]
    for (offset, byte) in source.utf8.enumerated() where byte == UInt8(ascii: "\n") {
      starts.append(offset + 1)
    }
    lineStarts = starts
    mark(Document(parsing: source))
    for url in source.matches(of: Self.bareURL) { set(url.range, false) }
  }

  /// A URL written out in text, which a reader would still see linked.
  // swiftlint:disable:next force_try
  private static let bareURL = try! Regex(#"(?i)(?:https?://|www\.)[^\s<>]+"#)

  /// Whether every character in `range` is prose.
  func contains(_ range: Range<String.Index>) -> Bool {
    let lower = offset(range.lowerBound)
    let upper = offset(range.upperBound)
    return lower < upper && flags[lower..<upper].allSatisfy { $0 }
  }

  /// Whether the character at `index` is prose.
  func contains(_ index: String.Index) -> Bool {
    let at = offset(index)
    return at < flags.count && flags[at]
  }

  private mutating func mark(_ markup: Markup) {
    switch markup {
    case is Paragraph, is Heading, is Table.Cell:
      set(markup.range, true)
      for child in markup.children { unmark(child) }
    case is CodeBlock, is HTMLBlock:
      return
    default:
      for child in markup.children { mark(child) }
    }
  }

  /// Clears the parts of an inline that are not prose.
  private mutating func unmark(_ markup: Markup) {
    switch markup {
    case is InlineCode, is InlineHTML:
      set(markup.range, false)
    case is Link, is Image:
      guard let range = markup.range else { return }
      // `[text](destination)`: only the text is prose. A bare or `<…>` autolink is all destination.
      let text = markup.children.compactMap(\.range)
      guard character(at: range.lowerBound) == "[" || character(at: range.lowerBound) == "!",
        let end = text.map(\.upperBound).max() else {
        set(range, false)
        return
      }
      set(end..<range.upperBound, false)
      for child in markup.children { unmark(child) }
    default:
      for child in markup.children { unmark(child) }
    }
  }

  private mutating func set(_ range: Range<String.Index>, _ value: Bool) {
    for offset in offset(range.lowerBound)..<offset(range.upperBound) { flags[offset] = value }
  }

  private mutating func set(_ range: SourceRange?, _ value: Bool) {
    guard let range else { return }
    let lower = byte(range.lowerBound)
    let upper = byte(range.upperBound)
    guard lower < upper else { return }
    for offset in lower..<upper { flags[offset] = value }
  }

  private func byte(_ location: SourceLocation) -> Int {
    guard location.line >= 1, location.line <= lineStarts.count else { return flags.count }
    return min(lineStarts[location.line - 1] + max(location.column - 1, 0), flags.count)
  }

  private func character(at location: SourceLocation) -> Character? {
    let at = byte(location)
    guard at < flags.count else { return nil }
    let index = source.utf8.index(source.utf8.startIndex, offsetBy: at)
    return source[index...].first
  }

  private func offset(_ index: String.Index) -> Int {
    source.utf8.distance(from: source.utf8.startIndex, to: index)
  }
}
