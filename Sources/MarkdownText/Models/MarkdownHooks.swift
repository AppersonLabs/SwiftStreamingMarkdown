//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftUI

extension EnvironmentValues {
  /// Draws a fenced code block in place of the built-in view. Return `nil` to
  /// keep the built-in view, for example for languages the app does not draw
  /// itself.
  @Entry public var markdownCodeBlock: ((_ language: String, _ code: String) -> AnyView?)?

  /// Called when a tap lands on prose rather than on a link, an attachment or
  /// a text selection.
  @Entry public var markdownTap: (() -> Void)?
}
