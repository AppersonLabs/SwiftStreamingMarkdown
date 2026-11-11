//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import Markdown
@testable import SwiftStreamingMarkdown
import XCTest

final class LaTexPreProcessorTests: XCTestCase {

  let preprocessor = LaTexPreProcessorImpl()

  func testNoLatex() throws {
    let testString = "Your string with (parentheticals), [square parentheticals], and money, like $5. That's a lot of $$!"
    let result = preprocessor.process(input: testString)
    XCTAssertEqual(result, testString)
  }

  func testBlockMath() {
    let input = """
    $$a = b + c \\\\ d = e + f$$
    """
    let expectation = """
    ```blockmath
    a = b + c \\\\ d = e + f
    ```
    """
    let output = preprocessor.process(input: input)
    XCTAssertEqual(output, expectation)
  }

  func testBlockMathWithIndentationAndSpaces() {
    // Note we are adding white space after the closing `$$` since the model can return them
    let whiteSpaces = String(repeating: " ", count: 3)
    let input = """
    $$   ax^2 + bx + c = 0       $$ \(whiteSpaces)
    """

    let expectation = """
    ```blockmath
       ax^2 + bx + c = 0
    ```
    """
    let output = preprocessor.process(input: input)
    XCTAssertEqual(output, expectation)
  }

  func testBlockMathWithBracket() throws {
    let testString = """
    Your string with
    \\[
    wrapped text\\]
    and more text
    """
    let expectation = """
    Your string with
    ```blockmath
    wrapped text
    ```
    and more text
    """
    let newLatex = preprocessor.process(input: testString)
    XCTAssertEqual(newLatex, expectation)
  }

  func testBlockMathWithBracketWithSpaces() throws {
    let whiteSpaces = String(repeating: " ", count: 3)
    let testString = """
    Your string with
    \\[
    wrapped text\\]\(whiteSpaces)
    and more text
    """
    let expectation = """
    Your string with
    ```blockmath
    wrapped text
    ```
    and more text
    """
    let newLatex = preprocessor.process(input: testString)
    XCTAssertEqual(newLatex, expectation)
  }

  func testInlineMath() throws {
    let input = """
    This is \\(inline latex\\). Some more \\( inline (parenthesis) latex \\).
    """
    let expectation = """
    This is `\\(inline latex\\)`. Some more `\\( inline (parenthesis) latex \\)`.
    """
    let newLatex = preprocessor.process(input: input)
    XCTAssertEqual(newLatex, expectation)
  }

  func testTableWithDollarSign() throws {
    let input = """
    Here's a list of restaurant near you:


    | Restaurant    | Price |
    | -------- | ------- |
    | January  | $$$$   |
    | February | $$$$     |
    | March    | $$$$    |
    """
    let newLatex = preprocessor.process(input: input)
    XCTAssertEqual(newLatex, input)
  }

  func testConsecutiveFormula() throws {
    let input = """
    Here are a couple of most famous math formulas
    $$a^2 + b^2 = c^$$

    $$e^{i\\pi} + 1 = 0$$

    $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$
    $$A = \\pi r^2$$

    $$F = ma$$

    $$\\text{Mass-Energy Equivalence: } E = mc^2$$

    $$(a + b)^n = \\sum_{k=0}^{n} \\binom{n}{k} a^{n-k} b^k$$

    $$f(x) = \\sum_{n=0}^{\\infty} \\frac{f^{(n)}(a)}{n!}(x - a)^n$$

    $$f'(x) = \\lim_{h \\to 0} \\frac{f(x+h) - f(x)}{h}$$

    $$\\int_a^b f(x)\\,dx = \\lim_{n \\to \\infty} \\sum_{i=1}^{n} f(x_i^*) \\Delta x$$

    $$C = S_0 N(d_1) - K e^{-rT} N(d_2)$$
    $$d_1 = \\frac{\\ln\\left(\\frac{S_0}{K}\\right) + \\left(r + \\frac{\\sigma^2}{2}\\right)T}{\\sigma \\sqrt{T}}, \\quad$$
    $$d_2 = d_1 - \\sigma \\sqrt{T}$$
    """
    let newLatex = preprocessor.process(input: input)
    let expectation = """
    Here are a couple of most famous math formulas
    ```blockmath
    a^2 + b^2 = c^
    ```

    ```blockmath
    e^{i\\pi} + 1 = 0
    ```

    ```blockmath
    x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
    ```
    ```blockmath
    A = \\pi r^2
    ```

    ```blockmath
    F = ma
    ```

    ```blockmath
    \\text{Mass-Energy Equivalence: } E = mc^2
    ```

    ```blockmath
    (a + b)^n = \\sum_{k=0}^{n} \\binom{n}{k} a^{n-k} b^k
    ```

    ```blockmath
    f(x) = \\sum_{n=0}^{\\infty} \\frac{f^{(n)}(a)}{n!}(x - a)^n
    ```

    ```blockmath
    f^\\prime(x) = \\lim_{h \\to 0} \\frac{f(x+h) - f(x)}{h}
    ```

    ```blockmath
    \\int_a^b f(x)\\,dx = \\lim_{n \\to \\infty} \\sum_{i=1}^{n} f(x_i^*) \\Delta x
    ```

    ```blockmath
    C = S_0 N(d_1) - K e^{-rT} N(d_2)
    ```
    ```blockmath
    d_1 = \\frac{\\ln\\left(\\frac{S_0}{K}\\right) + \\left(r + \\frac{\\sigma^2}{2}\\right)T}{\\sigma \\sqrt{T}}, \\quad
    ```
    ```blockmath
    d_2 = d_1 - \\sigma \\sqrt{T}
    ```
    """
    // print(newLatex)
    XCTAssertEqual(newLatex, expectation)
  }

  func testInline() throws {
    let text = """
    This double integral:
    - Sweeps across a rectangular region from \\( x = 0 \\) to \\( \\pi \\), and \\( y = 1 \\) to \\( e \\)
    - Combines a sine of a product \\( xy \\), a logarithmic denominator, and a cosine term multiplied by a polynomial
    - Is a great example of how calculus can get delightfully \\( \\text{tangled} \\)
    """
    let processed = preprocessor.processInlineMath(input: text)
    let expected = """
    This double integral:
    - Sweeps across a rectangular region from `\\( x = 0 \\)` to `\\( \\pi \\)`, and `\\( y = 1 \\)` to `\\( e \\)`
    - Combines a sine of a product `\\( xy \\)`, a logarithmic denominator, and a cosine term multiplied by a polynomial
    - Is a great example of how calculus can get delightfully `\\( \\text{tangled} \\)`
    """
    XCTAssertEqual(processed, expected)
  }

  func testBlockMathWithWhitespace() throws {
    let text = """
    - Net force on the ring:
      \\[
        F = f - m\\,g = (k\\,m\\,g) - m\\,g = (k-1)\\,m\\,g.
      \\]
    - Therefore the ring’s acceleration is
      \\[
        a_{\\rm ring} = \\frac{F}{m} = (k-1)\\,g
        \\quad\\text{(upward).}
      \\]
    """
    let processed = preprocessor.processBlockMath(input: text)
    let expected = """
    - Net force on the ring:
      ```blockmath
        F = f - m\\,g = (k\\,m\\,g) - m\\,g = (k-1)\\,m\\,g.
      ```
    - Therefore the ring’s acceleration is
      ```blockmath
        a_{\\rm ring} = \\frac{F}{m} = (k-1)\\,g
        \\quad\\text{(upward).}
      ```
    """
    XCTAssertEqual(expected, processed)
  }

  func testBlockMathWithSpecificSymbols() throws {
    let text = """
    \\[
    \\varphi(x) = f(x) - \\big(f(a) + f'(a)(x-a)\\big).
    \\]

    - Vector \\(\\overrightarrow{FA} = (a+c,0)\\)

    \\[
    2+2(2q-1) = 2q^2 \\implies 2+4q-2 = 2q^2 \\implies 4q = 2q^2 \\implies q^2 - 2q = 0.
    \\]

    \\[
    Fe^{3+}_{(aq)} + xCl^-_{(aq)} \\rightleftharpoons [FeCl_x]^{3-x}_{(aq)} \\quad (x = 1,2,3,4)
    \\]

    \\(a_1, \\dots, a_n\\)
    """

    let processed = preprocessor.process(input: text)
    let expected = """
    ```blockmath
    \\varphi(x) = f(x) - (f(a) + f^\\prime(a)(x-a)).
    ```

    - Vector `\\(\\vec{FA} = (a+c,0)\\)`

    ```blockmath
    2+2(2q-1) = 2q^2 \\Rightarrow 2+4q-2 = 2q^2 \\Rightarrow 4q = 2q^2 \\Rightarrow q^2 - 2q = 0.
    ```

    ```blockmath
    Fe^{3+}_{(aq)} + xCl^-_{(aq)} \\Leftrightarrow [FeCl_x]^{3-x}_{(aq)} \\quad (x = 1,2,3,4)
    ```

    `\\(a_1, \\ldots, a_n\\)`
    """
    XCTAssertEqual(expected, processed)
  }

  // MARK: - Matching-rule gating

  func testBlockDollarDisabledLeavesDollarsAsPlainText() {
    let input = """
    The price is $$5 and the total is $$10.
    $$a = b + c$$
    """
    let processed = preprocessor.process(
      input: input,
      matchingRules: [.inlineSlashBracket, .blockSlashBracket]
    )
    XCTAssertEqual(processed, input)
  }

  func testBlockDollarDisabledStillProcessesOtherRules() {
    let input = """
    $$a = b + c$$
    \\[
    x = y + z
    \\]
    Inline \\(p + q\\) here.
    """
    let expected = """
    $$a = b + c$$
    ```blockmath
    x = y + z
    ```
    Inline `\\(p + q\\)` here.
    """
    let processed = preprocessor.process(
      input: input,
      matchingRules: [.inlineSlashBracket, .blockSlashBracket]
    )
    XCTAssertEqual(processed, expected)
  }

  // MARK: - Inline dollar math

  func testInlineDollarMath() {
    XCTAssertEqual(
      preprocessor.process(input: "Euler: $e^{i\\pi} + 1 = 0$ and $x$."),
      "Euler: `\\(e^{i\\pi} + 1 = 0\\)` and `\\(x\\)`."
    )
  }

  func testInlineDollarLeavesPricesAsText() {
    for input in ["It costs $5 and $10.", "From $5-$10 a month.", "Paid \\$5 for $x", "a $ b $ c"] {
      XCTAssertEqual(preprocessor.process(input: input), input)
    }
  }

  func testInlineDollarLeavesCodeAlone() {
    let input = """
    Run `echo $a+$b` then:
    ```bash
    echo $a+$b
    ```
    ~~~
    $x$
    ~~~
    """
    XCTAssertEqual(preprocessor.process(input: input), input)
  }

  func testInlineDollarDisabledLeavesDollarsAsText() {
    let input = "Here $x$ stays."
    XCTAssertEqual(
      preprocessor.process(input: input, matchingRules: [.inlineSlashBracket, .blockDollar, .blockSlashBracket]),
      input
    )
  }

  // MARK: - Math only in prose

  func testDollarsInCodeStayUntouched() {
    for input in [
      "Indented:\n\n    x = $a+$b\n    $$y$$",
      "> ```\n> cost $a+$b\n> ```",
      "> ~~~\n> $$x$$\n> ~~~",
      "- item\n\n  ```sh\n  echo $a+$b\n  ```",
      "1. step\n\n       echo $a+$b",
      "Run `echo $a+$b` now",
      "Run ``a ` $x$ ` b`` now",
      "```\n\\(x\\) and \\[y\\]\n```"
    ] {
      XCTAssertEqual(preprocessor.process(input: input), input, input)
    }
  }

  func testDollarsInLinksStayUntouched() {
    for input in [
      "[x](https://e.com/?a=$b&c=$d)",
      "[orders](https://api.e.com/orders?$filter=a&$top=5) and $x$",
      "![chart](https://e.com/c.png?$w=$h)",
      "<https://e.com/?a=$b&c=$d>",
      "See https://e.com/?a=$b&c=$d today",
      "[x][ref]\n\n[ref]: https://e.com/?a=$b&c=$d",
      "[ref]: https://e.com/?$a=$b\n\nText"
    ] {
      let expected = input.replacingOccurrences(of: "and $x$", with: "and `\\(x\\)`")
      XCTAssertEqual(preprocessor.process(input: input), expected, input)
    }
  }

  func testDollarsInRawHTMLStayUntouched() {
    let input = "<span title=\"$a$\">x</span>\n\n<div>\n$b$\n</div>"
    XCTAssertEqual(preprocessor.process(input: input), input)
  }

  func testMathInProseStillRenders() {
    XCTAssertEqual(
      preprocessor.process(input: "> Quote $x$ and\n- item $y_1$\n\n| a |\n| - |\n| $z$ |\n\n# Head $h$"),
      "> Quote `\\(x\\)` and\n- item `\\(y_1\\)`\n\n| a |\n| - |\n| `\\(z\\)` |\n\n# Head `\\(h\\)`"
    )
    XCTAssertEqual(
      preprocessor.process(input: "[cost $a$](https://e.com/?q=$b) and \\(c\\)"),
      "[cost `\\(a\\)`](https://e.com/?q=$b) and `\\(c\\)`"
    )
  }

  func testEscapedAndCurrencyDollarsStayText() {
    for input in ["Paid \\$5 and \\$x\\$ here", "Costs $5, $10 or $1.50.", "US$5 and $ 6"] {
      XCTAssertEqual(preprocessor.process(input: input), input, input)
    }
  }

  func testBlockMathOnlyOutsideCode() {
    let input = "```\n$$a$$\n```\n$$b$$\n\n    $$c$$\n\n\\[\nd\n\\]"
    let expected = "```\n$$a$$\n```\n```blockmath\nb\n```\n\n    $$c$$\n\n```blockmath\nd\n```"
    XCTAssertEqual(preprocessor.process(input: input), expected)
  }

  func testCodeBeforeMathDoesNotSwallowIt() {
    let input = "    $$ code\n\n$$x$$"
    XCTAssertEqual(preprocessor.process(input: input), "    $$ code\n\n```blockmath\nx\n```")
  }
}
