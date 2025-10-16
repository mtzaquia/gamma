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

import GammaSchema
import Foundation
import os
import UIKit

package typealias ThemeValidationIssue = GammaSchema.ThemeValidationIssue

extension RawTheme {
    func validationIssues(resolvedModes: ResolvedThemeModes? = nil) -> [ThemeValidationIssue] {
        var issues = schemaValidationIssues()

        guard let resolvedModes else {
            return issues.sortedForDiagnostics()
        }

        if resolvedModes.colors.light.isEmpty {
            issues.append(.init(path: "resolver.colors.light", message: "mode name must not be empty"))
        }
        if resolvedModes.colors.dark.isEmpty {
            issues.append(.init(path: "resolver.colors.dark", message: "mode name must not be empty"))
        }
        if resolvedModes.fonts.primary.isEmpty {
            issues.append(.init(path: "resolver.fonts.primary", message: "mode name must not be empty"))
        }
        if resolvedModes.unit.isEmpty {
            issues.append(.init(path: "resolver.unit", message: "mode name must not be empty"))
        }

        for (token, color) in colors {
            for mode in Set([resolvedModes.colors.light, resolvedModes.colors.dark]) where !mode.isEmpty {
                if color.modes[mode] == nil {
                    issues.append(.init(path: "colors.\(token).modes.\(mode)", message: "mode selected by the resolver is missing"))
                }
            }
        }

        for (token, font) in fonts {
            let modes = [resolvedModes.fonts.primary] + resolvedModes.fonts.cascades
            for mode in Set(modes) where !mode.isEmpty {
                guard let value = font.modes[mode] else {
                    issues.append(.init(path: "fonts.\(token).modes.\(mode)", message: "mode selected by the resolver is missing"))
                    continue
                }

                if UIFont(name: value.fontName, size: value.fontSize) == nil {
                    issues.append(.init(
                        path: "fonts.\(token).modes.\(mode).fontName",
                        message: "PostScript name \(value.fontName.inspecting) is not available to UIKit"
                    ))
                }
            }
        }

        for (token, unit) in units where !resolvedModes.unit.isEmpty && unit.modes[resolvedModes.unit] == nil {
            issues.append(.init(
                path: "units.\(token).modes.\(resolvedModes.unit)",
                message: "mode selected by the resolver is missing"
            ))
        }

        return issues.sortedForDiagnostics()
    }

}

enum ThemeDiagnostics {
    private nonisolated static let reportedKeys = OSAllocatedUnfairLock(initialState: Set<String>())

    static func validate(
        _ theme: RawTheme,
        resolvedModes: ResolvedThemeModes,
        additionalIssues: [ThemeValidationIssue] = []
    ) {
        let key = validationKey(theme: theme, modes: resolvedModes)
        guard markReported(key) else { return }

        let issues = (theme.validationIssues(resolvedModes: resolvedModes) + additionalIssues)
            .uniqueSortedForDiagnostics()

        guard !issues.isEmpty else {
            gammaLog.gammaDebug(.themeValidated(
                themeID: theme.id,
                colors: theme.colors.count,
                fonts: theme.fonts.count,
                units: theme.units.count
            ))
            return
        }

        reportFailure(
            consolidatedMessage(
                heading: "[theme] ⚠ validation failed | id=\(theme.id) issues=\(issues.count)",
                issues: issues
            )
        )
    }

    static func overridesApplied(_ theme: RawTheme, overrides: RawThemeOverrides) {
        let key = "overrides|\(theme.instanceID)|\(theme.overrideHash)"
        guard markReported(key) else { return }
        gammaLog.gammaDebug(.overridesApplied(
            themeID: theme.id,
            colors: overrides.colors.count,
            fonts: overrides.fonts.count,
            units: overrides.units.count
        ))
    }

    static func fontRegistrationFailed(_ issues: [FontRegistrationIssue]) {
        let issues = Array(Set(issues)).sorted {
            if $0.fileName == $1.fileName {
                $0.reason < $1.reason
            } else {
                $0.fileName < $1.fileName
            }
        }
        guard !issues.isEmpty else { return }

        let key = "font-registration|" + issues.map(\.description).joined(separator: "|")
        guard markReported(key) else { return }

        reportFailure(
            (["[font] ⚠ registration failed | issues=\(issues.count)"]
                + issues.map { "  • \($0.description)" })
                .joined(separator: "\n")
        )
    }

    static func resolutionFailure(
        kind: String,
        alias: String,
        themeInstanceID: UUID,
        detail: String
    ) {
        let key = "resolution|\(themeInstanceID)|\(kind)|\(alias)|\(detail)"
        guard markReported(key) else { return }
        reportFailure("[resolve] ⚠ \(kind) token \(alias.inspecting) could not be resolved | \(detail)")
    }

    private static func validationKey(
        theme: RawTheme,
        modes: ResolvedThemeModes
    ) -> String {
        "validation|\(theme.instanceID)|\(theme.overrideHash)|\(modes)"
    }

    private static func markReported(_ key: String) -> Bool {
        reportedKeys.withLock { $0.insert(key).inserted }
    }

    private static func reportFailure(_ message: String) {
        gammaLog.gammaWarning(message)
#if DEBUG
        assertionFailure(message)
#endif
    }

    private static func consolidatedMessage(
        heading: String,
        issues: [ThemeValidationIssue]
    ) -> String {
        ([heading] + issues.map { "  • \($0.description)" }).joined(separator: "\n")
    }
}

private extension Array where Element == ThemeValidationIssue {
    func sortedForDiagnostics() -> Self {
        sorted {
            if $0.path == $1.path {
                $0.message < $1.message
            } else {
                $0.path < $1.path
            }
        }
    }

    func uniqueSortedForDiagnostics() -> Self {
        Array(Set(self)).sortedForDiagnostics()
    }
}

private extension String {
    var inspecting: String {
        "\"\(self)\""
    }
}
