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
import os

/// Global Gamma diagnostic configuration.
public enum Gamma {
    /// The amount of diagnostic detail emitted by Gamma in debug builds.
    public enum DebugLogLevel: Equatable, Sendable {
        /// Disables optional debug logs. Validation warnings are still emitted.
        case off
        /// Logs theme installation and override activity.
        case normal
        /// Includes successful validation and resolution details.
        case trace
    }

    private nonisolated static let debugLock = OSAllocatedUnfairLock(initialState: DebugLogLevel.off)

    /// Controls optional Gamma logging emitted in debug builds.
    public nonisolated static var debug: DebugLogLevel {
        get { debugLock.withLock { $0 } }
        set { debugLock.withLock { $0 = newValue } }
    }
}

nonisolated let gammaLog = Logger(
    subsystem: "eu.lelfe.gamma",
    category: "Gamma"
)

enum GammaLogEvent {
    case fontRegistered(fileName: String, postScriptName: String)
    case overridesApplied(themeID: String, colors: Int, fonts: Int, units: Int, extensions: Int)
    case themeValidated(themeID: String, colors: Int, fonts: Int, units: Int)
    case overridesValidated(themeID: String, colors: Int, fonts: Int, units: Int)

    var logLevel: Gamma.DebugLogLevel {
        switch self {
        case .overridesApplied: .normal
        case .fontRegistered, .themeValidated, .overridesValidated: .trace
        }
    }

    var message: String {
        switch self {
        case let .fontRegistered(fileName, postScriptName):
            "[font] ✓ registered | file=\(fileName) postscript=\(postScriptName)"
        case let .overridesApplied(themeID, colors, fonts, units, extensions):
            "[override] ✓ applied | theme=\(themeID) colors=\(colors) fonts=\(fonts) units=\(units) extensions=\(extensions)"
        case let .themeValidated(themeID, colors, fonts, units):
            "[theme] ✓ validated | id=\(themeID) colors=\(colors) fonts=\(fonts) units=\(units)"
        case let .overridesValidated(themeID, colors, fonts, units):
            "[override] ✓ validated | theme=\(themeID) colors=\(colors) fonts=\(fonts) units=\(units)"
        }
    }
}

extension Logger {
    func gammaDebug(_ event: @autoclosure () -> GammaLogEvent) {
#if DEBUG
        let configuredLevel = Gamma.debug
        guard configuredLevel != .off else { return }

        let event = event()
        guard configuredLevel.includes(event.logLevel) else { return }
        debug("\(event.message, privacy: .public)")
#endif
    }

    func gammaWarning(_ message: @autoclosure () -> String) {
        let message = message()
        warning("\(message, privacy: .public)")
    }
}

private extension Gamma.DebugLogLevel {
    func includes(_ eventLevel: Self) -> Bool {
        switch (self, eventLevel) {
        case (.trace, _), (.normal, .normal), (.off, .off): true
        default: false
        }
    }
}
