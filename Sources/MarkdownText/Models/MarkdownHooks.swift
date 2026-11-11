// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE in the project root.

import SwiftUI

/// Supplies an app's native view for a fenced code block.
@MainActor
public protocol MarkdownCodeBlocks {
  /// Return nil to use the built-in code view.
  func view(language: String, code: String) -> AnyView?
}

/// Handles a prose tap after links, attachments and text selection have been excluded.
@MainActor
public protocol MarkdownTaps {
  func callAsFunction()
}

extension EnvironmentValues {
  @Entry public var markdownCodeBlock: (any MarkdownCodeBlocks)?
  @Entry public var markdownTap: (any MarkdownTaps)?
}
