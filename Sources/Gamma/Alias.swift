//
//  Copyright (c) 2026 @mtzaquia
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

/// A marker protocol for asset catalog types.
public protocol AssetType {}
/// Asset type marker for icon resources.
public enum IconAsset: AssetType {}
/// Asset type marker for illustration resources.
public enum IllustrationAsset: AssetType {}
/// Asset type marker for animation resources (e.g., Lottie).
public enum AnimationAsset: AssetType {}

/// Namespace for design token alias types used to look up theme values.
public enum Theme {
    /// An alias for a local icon asset.
    public typealias IconAlias = AssetAlias<IconAsset>

    /// Identifies a design token in a family or one generated token group.
    ///
    /// A family scope accepts tokens from any of its groups. A generated group
    /// scope lets component parameters accept only that group, such as
    /// `Theme.Units.SpacingAlias`.
    nonisolated public struct Alias<Scope: ThemeAliasScope>: RawRepresentable, Codable, Hashable, Sendable
    where Scope.Family: ThemeExtension {
        /// The family or generated group represented by this alias.
        public typealias AliasScope = Scope

        /// The token key as it appears in the theme.
        public let rawValue: String

        /// The first path component, or `nil` for a single-component ungrouped key.
        public var tokenGroup: String? {
            let components = rawValue.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            guard components.count == 2 else { return nil }
            return String(components[0])
        }

        /// The name component that follows the token group.
        public var tokenName: String {
            let components = rawValue.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            return String(components.last ?? "")
        }

        /// Creates an alias from a theme token key.
        ///
        /// Resolution fails when the key does not exist in
        /// ``ThemeAliasScope/Family`` or violates a generated group scope.
        ///
        /// - Parameter rawValue: The token key as it appears in the theme.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Decodes an alias from one JSON string containing its complete token key.
        public init(from decoder: any Decoder) throws {
            rawValue = try decoder.singleValueContainer().decode(String.self)
        }

        /// Encodes the alias as one JSON string containing its complete token key.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    /// Identifies an asset catalog entry by name for a given asset type.
    public struct AssetAlias<Asset: AssetType>: RawRepresentable, Hashable, Sendable {
        /// The marker type that distinguishes this category of asset alias.
        public typealias Kind = Asset

        /// The asset name as it appears in the asset catalog.
        public var rawValue: String
        /// The bundle containing the asset catalog. `nil` falls back to the main bundle.
        public var bundle: Bundle?

        /// Creates an alias with an explicit bundle.
        public init(rawValue: String, bundle: Bundle? = nil) {
            self.rawValue = rawValue
            self.bundle = bundle
        }

        public init(rawValue: String) {
            self.rawValue = rawValue
            self.bundle = nil
        }
    }
}
