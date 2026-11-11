//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import RegexBuilder

/// Pre-process the inline and block latex in markdown.
/// This is a less heavy-weight approach than forking commonmark-gfm and swift-markdown to support parsing latex nodes.
protocol LaTexPreProcessor {
  func process(input: String, matchingRules: [MarkdownParseOption.LatexMatching]) -> String
}

extension LaTexPreProcessor {
  func process(input: String) -> String {
    return process(input: input, matchingRules: MarkdownParseOption.LatexMatching.allCases)
  }
}

final class LaTexPreProcessorImpl: LaTexPreProcessor {

  static let latexRef = Reference(Substring.self)
  static let latexOpenIndentation = Reference(Substring.self)

  static let dollarBlockMath = Regex {
    Anchor.startOfLine
    Capture(as: latexOpenIndentation) {
      ZeroOrMore(.horizontalWhitespace)
    }
    "$$"
    Capture(as: latexRef) {
      OneOrMore(.any, .reluctant)
    }
    ZeroOrMore(.horizontalWhitespace)
    "$$"
    ZeroOrMore(.horizontalWhitespace)
    Anchor.endOfLine
  }

  static let slashBracketMath = Regex {
    Anchor.startOfLine
    Capture(as: latexOpenIndentation) {
      ZeroOrMore(.horizontalWhitespace)
    }
    "\\["
    Capture(as: latexRef) {
      OneOrMore(.any, .reluctant)
    }
    ZeroOrMore(.horizontalWhitespace)
    "\\]"
    ZeroOrMore(.horizontalWhitespace)
    Anchor.endOfLine
  }

  static let inlineParenthesisMath = Regex {
    "\\("
    Capture(as: latexRef) {
      OneOrMore(.any, .reluctant)
    }
    "\\)"
  }

  static let boxedLatex = Regex {
    Capture {
      "\\boxed"
    }
  }

  static let dfracLatex = Regex {
    Capture {
      "\\dfrac"
    }
  }

  static let tfracLatex = Regex {
    Capture {
      "\\tfrac"
    }
  }

  static let bracketSize = Regex {
    Capture {
      ChoiceOf {
        "\\bigl"
        "\\biggl"
        "\\Bigl"
        "\\Biggl"
        "\\bigr"
        "\\biggr"
        "\\Bigr"
        "\\Biggr"
        "\\big"
      }
    }
  }

  static let primeLatex = Regex {
    Capture {
      "'"
    }
  }

  static let vectorLatex = Regex {
    Capture {
      "\\overrightarrow"
    }
  }

  static let rightArrowLatex = Regex {
    Capture {
      "\\implies"
    }
  }

  static let harpoonsLatex = Regex {
    Capture {
      "\\rightleftharpoons"
    }
  }

  static let dotsLatex = Regex {
    Capture {
      "\\dots"
    }
  }

  static let customCodeType = "blockmath"
  static let inlineCodePrefix = "\\("
  static let inlineCodeSuffix = "\\)"
  static let newline = "\n"

  init() {}

  /// Rewrites math in prose only. Each pass parses the Markdown it is given, so
  /// code (fenced, indented, quoted or nested in a list), code spans, raw HTML,
  /// link destinations and reference definitions keep their dollars and
  /// backslashes.
  func process(input: String, matchingRules: [MarkdownParseOption.LatexMatching]) -> String {
    let rules = Set(matchingRules)
    let result = processBlockMath(input: input, rules: rules)
    return processInlineMath(input: result, rules: rules)
  }

  /// This replace block math with a special code block node. By treating it as a code block it will avoid over escaping characters within latex.
  func processBlockMath(input: String, rules: Set<MarkdownParseOption.LatexMatching>) -> String {
    var result = input
    if rules.contains(.blockDollar), result.contains("$$") {
      result = Self.replacingBlocks(Self.dollarBlockMath, in: result)
    }
    if rules.contains(.blockSlashBracket), result.contains("\\[") {
      result = Self.replacingBlocks(Self.slashBracketMath, in: result)
    }
    return result
  }

  /// This wraps inline math as inline code to avoid over-unescaping issue
  func processInlineMath(input: String, rules: Set<MarkdownParseOption.LatexMatching>) -> String {
    var result = input
    if rules.contains(.inlineSlashBracket), result.contains("\\(") {
      let prose = Prose(result)
      result = Self.replacing(Self.inlineParenthesisMath, in: result, where: prose.contains) { match in
        let latex = String(match[Self.latexRef]).filteringUnsupportedSyntaxes()
        return "`\\(\(latex)\\)`"
      }
    }
    // Runs last: what the pass above wrote is code now, which this pass skips.
    if rules.contains(.inlineDollar) {
      result = Self.wrappingDollarMath(in: result)
    }
    return result
  }

  /// Wraps each `$…$` in prose as inline code, as `processInlineMath` does for
  /// `\(…\)`. Escaped dollars and `$$` are left alone.
  static func wrappingDollarMath(in input: String) -> String {
    guard input.contains("$") else { return input }
    let prose = Prose(input)
    var result = ""
    var index = input.startIndex
    while index < input.endIndex {
      let character = input[index]
      let next = input.index(after: index)
      if !prose.contains(index) || next == input.endIndex {
        result.append(character)
        index = next
      } else if character == "\\" || (character == "$" && input[next] == "$") {
        result += input[index...next]
        index = input.index(after: next)
      } else if character == "$", let close = closingDollar(in: input, after: index, prose: prose) {
        let latex = String(input[next..<close]).filteringUnsupportedSyntaxes()
        result += "`\(inlineCodePrefix)\(latex)\(inlineCodeSuffix)`"
        index = input.index(after: close)
      } else {
        result.append(character)
        index = next
      }
    }
    return result
  }

  /// The closing `$` on the same line, within prose: a non-space to its left and
  /// no digit to its right, so prices such as `$5 and $10` stay text.
  private static func closingDollar(in input: String, after open: String.Index, prose: Prose) -> String.Index? {
    let first = input.index(after: open)
    guard first < input.endIndex, !input[first].isWhitespace, prose.contains(first) else { return nil }
    var previous = first
    var index = input.index(after: first)
    while index < input.endIndex, prose.contains(index) {
      let character = input[index]
      if character == "\n" || character == "`" { return nil }
      let next = input.index(after: index)
      if character == "\\" || (character == "$" && next < input.endIndex && input[next] == "$") {
        guard next < input.endIndex else { return nil }
        previous = next
        index = input.index(after: next)
        continue
      }
      let digitFollows = next < input.endIndex && input[next].isNumber
      if character == "$", !input[previous].isWhitespace, !digitFollows {
        return index
      }
      previous = index
      index = next
    }
    return nil
  }

  /// Replaces each block of math whose opening and closing delimiters are
  /// prose. The lines between are not checked: Markdown may read one of them as
  /// a list item or heading.
  private static func replacingBlocks(_ pattern: Regex<(Substring, Substring, Substring)>, in input: String) -> String {
    let prose = Prose(input)
    return replacing(pattern, in: input, where: { range in
      let text = input[range]
      guard let open = text.firstIndex(where: { !$0.isWhitespace }),
        let close = text.lastIndex(where: { !$0.isWhitespace }) else { return false }
      return prose.contains(open) && prose.contains(close)
    }) { match in
      buildCodeBlock(indentation: match[latexOpenIndentation], latex: match[latexRef])
    }
  }

  /// Replaces the matches of `pattern` that `allowed` accepts. A refused match
  /// gives up only its first character, so a match that starts inside code
  /// cannot swallow math that follows it.
  private static func replacing<Output>(
    _ pattern: Regex<Output>,
    in input: String,
    where allowed: (Range<String.Index>) -> Bool,
    with replacement: (Regex<Output>.Match) -> String
  ) -> String {
    var result = ""
    var copied = input.startIndex
    var search = input.startIndex
    while search < input.endIndex, let match = input[search...].firstMatch(of: pattern) {
      if allowed(match.range) {
        result += input[copied..<match.range.lowerBound]
        result += replacement(match)
        copied = match.range.upperBound
        search = match.range.upperBound
      } else {
        search = input.index(after: match.range.lowerBound)
      }
    }
    result += input[copied...]
    return result
  }

  // MARK: - Convenience overloads (default to every supported rule)

  func processBlockMath(input: String) -> String {
    return processBlockMath(input: input, rules: Set(MarkdownParseOption.LatexMatching.allCases))
  }

  func processInlineMath(input: String) -> String {
    return processInlineMath(input: input, rules: Set(MarkdownParseOption.LatexMatching.allCases))
  }

  private static func buildCodeBlock(indentation: Substring, latex: Substring) -> String {
    let processedLatex = latex.trimmingCharacters(in: .newlines).filteringUnsupportedSyntaxes()
    let nextLineIntendation = latex.hasPrefix(Self.newline) ? "" : indentation
    return "\(indentation)```\(Self.customCodeType)\(Self.newline)\(nextLineIntendation)\(processedLatex)\(Self.newline)\(indentation)```"
  }
}

extension String {

  func filteringUnsupportedSyntaxes() -> String {
    return self
      .strippingBoxedLatex()
      .replacingfrac()
      .replacingPrime()
      .replacingVector()
      .replacingImplies()
      .replacingHarpoons()
      .replacingDots()
      .strippingBracketSizeCommands()
  }

  /// This strips "\boxed" string from a given latex. This is because our rendering engine does not support \boxed{...} yet.
  func strippingBoxedLatex() -> String {
    return self.replacing(LaTexPreProcessorImpl.boxedLatex, with: "")
  }

  /// Replacing `dfrac` and `tfac` which is unsupported into simple `frac`
  func replacingfrac() -> String {
    return self
      .replacing(LaTexPreProcessorImpl.dfracLatex, with: "\\frac")
      .replacing(LaTexPreProcessorImpl.tfracLatex, with: "\\frac")
  }

  /// Replacing `'` which is unsupported into `^prime`
  func replacingPrime() -> String {
    return self.replacing(LaTexPreProcessorImpl.primeLatex, with: "^\\prime")
  }

  /// Replacing `overrightarrow` which is unsupported into `vec`
  func replacingVector() -> String {
    return self.replacing(LaTexPreProcessorImpl.vectorLatex, with: "\\vec")
  }

  /// Replacing `implies` which is unsupported into `Rightarrow`
  func replacingImplies() -> String {
    return self.replacing(LaTexPreProcessorImpl.rightArrowLatex, with: "\\Rightarrow")
  }

  /// Replacing `harpoons` which is unsupported into `Leftrightarrow`
  func replacingHarpoons() -> String {
    return self.replacing(LaTexPreProcessorImpl.harpoonsLatex, with: "\\Leftrightarrow")
  }

  /// Replacing `dots` which is unsupported into `ldots`
  func replacingDots() -> String {
    return self.replacing(LaTexPreProcessorImpl.dotsLatex, with: "\\ldots")
  }

  /// Stripping commands to specify bracket sizes(`\Biggl` etc) which is unsupported
  func strippingBracketSizeCommands() -> String {
    return self.replacing(LaTexPreProcessorImpl.bracketSize, with: "")
  }
}
