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

/// Decides which link destinations stay tappable and what is drawn before
/// their text.
public struct LinkConfig: Hashable, Sendable {

  /// Stands in for the closures when configs are compared: two configs with
  /// the same `id` must make the same decisions.
  public let id: String

  /// Whether a destination stays a link. A refused link keeps its text and
  /// loses its destination and link styling.
  public let allows: @Sendable (URL) -> Bool

  /// An attachment drawn before the link's text, such as a site icon. It opens
  /// the same destination as the text.
  public let icon: @Sendable (URL) -> NSTextAttachment?

  /// Create a link configuration.
  /// - Parameters:
  ///   - id: See `id`.
  ///   - allows: See `allows`. Defaults to allowing every destination.
  ///   - icon: See `icon`. Defaults to no icon.
  public init(
    id: String,
    allows: @escaping @Sendable (URL) -> Bool = { _ in true },
    icon: @escaping @Sendable (URL) -> NSTextAttachment? = { _ in nil }
  ) {
    self.id = id
    self.allows = allows
    self.icon = icon
  }

  /// Every destination stays a link and none has an icon.
  public static let `default` = LinkConfig(id: "default")

  public static func == (lhs: LinkConfig, rhs: LinkConfig) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
