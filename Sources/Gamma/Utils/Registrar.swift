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

import CoreText
import Foundation
import UIKit

struct FontRegistrationIssue: Hashable {
    let fileName: String
    let reason: String

    var description: String {
        "\(fileName): \(reason)"
    }
}

struct RegisteredFont: Hashable {
    let fileName: String
    let postScriptName: String
}

struct FontRegistrationReport: Equatable {
    var availablePostScriptNames: Set<String> = []
    var newlyRegistered: [RegisteredFont] = []
    var issues: [FontRegistrationIssue] = []
}

enum FontRegistrationAttempt: Equatable {
    case registered
    case alreadyRegistered
    case failed(String)
}

protocol FontRegistrationBackend {
    func loadFont(at url: URL) -> CGFont?
    func isFontAvailable(named postScriptName: String) -> Bool
    func register(_ font: CGFont) -> FontRegistrationAttempt
}

final class FontRegistrar {
    private let backend: any FontRegistrationBackend
    private var postScriptNameByURL: [URL: String] = [:]
    private var availablePostScriptNames: Set<String> = []

    init(backend: any FontRegistrationBackend) {
        self.backend = backend
    }

    func registerFonts(at urls: [URL]) -> FontRegistrationReport {
        var report = FontRegistrationReport()

        for suppliedURL in urls {
            let url = suppliedURL.standardizedFileURL

            if let postScriptName = postScriptNameByURL[url],
               availablePostScriptNames.contains(postScriptName) {
                report.availablePostScriptNames.insert(postScriptName)
                continue
            }

            guard let font = backend.loadFont(at: url) else {
                report.issues.append(.init(
                    fileName: url.lastPathComponent,
                    reason: "could not read a font from this file"
                ))
                continue
            }

            guard let rawPostScriptName = font.postScriptName else {
                report.issues.append(.init(
                    fileName: url.lastPathComponent,
                    reason: "font does not expose a PostScript name"
                ))
                continue
            }

            let postScriptName = rawPostScriptName as String
            postScriptNameByURL[url] = postScriptName
            report.availablePostScriptNames.insert(postScriptName)

            if availablePostScriptNames.contains(postScriptName)
                || backend.isFontAvailable(named: postScriptName) {
                availablePostScriptNames.insert(postScriptName)
                continue
            }

            switch backend.register(font) {
            case .registered:
                availablePostScriptNames.insert(postScriptName)
                report.newlyRegistered.append(.init(
                    fileName: url.lastPathComponent,
                    postScriptName: postScriptName
                ))
            case .alreadyRegistered:
                availablePostScriptNames.insert(postScriptName)
            case let .failed(reason):
                report.availablePostScriptNames.remove(postScriptName)
                report.issues.append(.init(fileName: url.lastPathComponent, reason: reason))
            }
        }

        return report
    }
}

enum Registrar {
    private static let fontRegistrar = FontRegistrar(backend: CoreTextFontRegistrationBackend())

    @discardableResult
    static func registerFonts(at urls: [URL]) -> Set<String> {
        let report = fontRegistrar.registerFonts(at: urls)

        for font in report.newlyRegistered {
            gammaLog.gammaDebug(.fontRegistered(
                fileName: font.fileName,
                postScriptName: font.postScriptName
            ))
        }

        ThemeDiagnostics.fontRegistrationFailed(report.issues)
        return report.availablePostScriptNames
    }
}

private struct CoreTextFontRegistrationBackend: FontRegistrationBackend {
    func loadFont(at url: URL) -> CGFont? {
        guard let dataProvider = CGDataProvider(url: url as CFURL) else { return nil }
        return CGFont(dataProvider)
    }

    func isFontAvailable(named postScriptName: String) -> Bool {
        UIFont(name: postScriptName, size: 12) != nil
    }

    func register(_ font: CGFont) -> FontRegistrationAttempt {
        var unmanagedError: Unmanaged<CFError>?
        guard !CTFontManagerRegisterGraphicsFont(font, &unmanagedError) else {
            return .registered
        }

        guard let error = unmanagedError?.takeRetainedValue() else {
            return .failed("Core Text rejected the font without an error")
        }

        if CFErrorGetCode(error) == CTFontManagerError.alreadyRegistered.rawValue {
            return .alreadyRegistered
        }

        return .failed(CFErrorCopyDescription(error) as String)
    }
}
