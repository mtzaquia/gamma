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

import Gamma
import GammaSchema
import SwiftUI

/// The sample app's decoded gradient token payload.
nonisolated public struct GradientToken: ThemeExtensionToken {
    /// One mode-specific gradient value.
    nonisolated public struct Mode: Codable, Hashable, Sendable {
        /// Color token keys in rendering order.
        public let stops: [String]

        /// Creates a gradient mode from ordered color token keys.
        public init(stops: [String]) {
            self.stops = stops
        }
    }

    /// The display name supplied by the theme.
    public let name: String
    /// The semantic token group.
    public let group: String
    /// Gradient values keyed by mode name.
    public let modes: [String: Mode]
}

extension SampleTheme {
    static let campaignOverrides: ThemeOverrides = {
        do {
            return ThemeOverrides(tokens: [
                try ThemeTokenOverride(
                    Theme.Colors.BrandAlias.brandAccent,
                    modes: [
                        "day": .init(hex: "#D63F77", alpha: 1),
                        "night": .init(hex: "#FF82AD", alpha: 1),
                    ]
                ),
                try ThemeTokenOverride(
                    Theme.Units.RadiusAlias.radiusCard,
                    modes: ["compact": 8, "regular": 12]
                ),
                try ThemeTokenOverride(
                    Theme.Gradients.BrandAlias.brandHero,
                    modes: [
                        "day": GradientToken.Mode(stops: ["brand/accent", "surface/surface"]),
                        "night": GradientToken.Mode(stops: ["surface/surface", "brand/accent"]),
                    ]
                ),
            ])
        } catch {
            preconditionFailure("Could not create the sample campaign overrides: \(error)")
        }
    }()
}

extension Theme.Gradients: ThemeExtension {
    /// The app-owned payload decoded for generated gradient aliases.
    public typealias Token = GradientToken
}

extension ThemeProxy {
    /// Resolves any alias scope owned by the gradients family.
    ///
    /// The generic family constraint accepts both group-less gradient aliases
    /// and generated group aliases such as `Theme.Gradients.BrandAlias`.
    func gradient<Scope: ThemeAliasScope>(
        _ alias: Theme.Alias<Scope>
    ) -> LinearGradient where Scope.Family == Theme.Gradients {
        guard let mode = resolve(alias), !mode.stops.isEmpty else {
            return LinearGradient(
                colors: [.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: mode.stops.map {
                color(Theme.Alias<Theme.Colors>(rawValue: $0))
            },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
