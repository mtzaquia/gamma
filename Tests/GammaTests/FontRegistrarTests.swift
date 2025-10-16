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

#if canImport(UIKit)
import CoreGraphics
import Foundation
import Testing
@testable import Gamma

@Suite("Font registrar")
struct FontRegistrarTests {
    @Test("A recurring SwiftUI modifier does not reload or re-register the same URL")
    func recurringURLIsCheap() throws {
        let backend = try FakeFontRegistrationBackend()
        let registrar = FontRegistrar(backend: backend)
        let url = URL(fileURLWithPath: "/tmp/Brand-Regular.ttf")

        let first = registrar.registerFonts(at: [url])
        let second = registrar.registerFonts(at: [url])

        #expect(backend.loadCount == 1)
        #expect(backend.registrationCount == 1)
        #expect(first.newlyRegistered.map(\.postScriptName) == [backend.postScriptName])
        #expect(second.availablePostScriptNames == [backend.postScriptName])
        #expect(second.newlyRegistered.isEmpty)
    }

    @Test("Different cache URLs for the same PostScript name register only once")
    func postScriptNameDeduplicatesChangingURLs() throws {
        let backend = try FakeFontRegistrationBackend()
        let registrar = FontRegistrar(backend: backend)

        let report = registrar.registerFonts(at: [
            URL(fileURLWithPath: "/tmp/download-1.ttf"),
            URL(fileURLWithPath: "/tmp/download-2.ttf"),
        ])

        #expect(backend.loadCount == 2)
        #expect(backend.registrationCount == 1)
        #expect(report.availablePostScriptNames == [backend.postScriptName])
        #expect(report.issues.isEmpty)
    }

    @Test("Fonts already visible to the process are successful without registration")
    func processAvailableFontIsSuccessful() throws {
        let backend = try FakeFontRegistrationBackend(isAvailable: true)
        let registrar = FontRegistrar(backend: backend)

        let report = registrar.registerFonts(at: [URL(fileURLWithPath: "/tmp/already-there.ttf")])

        #expect(backend.registrationCount == 0)
        #expect(report.availablePostScriptNames == [backend.postScriptName])
        #expect(report.issues.isEmpty)
    }

    @Test("Core Text's already-registered result is successful")
    func coreTextAlreadyRegisteredIsSuccessful() throws {
        let backend = try FakeFontRegistrationBackend(attempt: .alreadyRegistered)
        let registrar = FontRegistrar(backend: backend)

        let report = registrar.registerFonts(at: [URL(fileURLWithPath: "/tmp/already-registered.ttf")])

        #expect(backend.registrationCount == 1)
        #expect(report.availablePostScriptNames == [backend.postScriptName])
        #expect(report.issues.isEmpty)
    }

    @Test("Registration failures retain the file and reason for consolidated diagnostics")
    func registrationFailureIsDescriptive() throws {
        let backend = try FakeFontRegistrationBackend(attempt: .failed("invalid font data"))
        let registrar = FontRegistrar(backend: backend)

        let report = registrar.registerFonts(at: [URL(fileURLWithPath: "/tmp/broken.ttf")])

        #expect(report.availablePostScriptNames.isEmpty)
        #expect(report.issues == [
            FontRegistrationIssue(fileName: "broken.ttf", reason: "invalid font data"),
        ])
    }
}

private final class FakeFontRegistrationBackend: FontRegistrationBackend {
    let postScriptName: String
    private let font: CGFont
    private let isAvailable: Bool
    private let attempt: FontRegistrationAttempt

    private(set) var loadCount = 0
    private(set) var registrationCount = 0

    init(
        isAvailable: Bool = false,
        attempt: FontRegistrationAttempt = .registered
    ) throws {
        guard let font = CGFont("Helvetica" as CFString),
              let rawPostScriptName = font.postScriptName
        else {
            throw TestError.couldNotCreateFont
        }

        self.font = font
        self.postScriptName = rawPostScriptName as String
        self.isAvailable = isAvailable
        self.attempt = attempt
    }

    func loadFont(at url: URL) -> CGFont? {
        loadCount += 1
        return font
    }

    func isFontAvailable(named postScriptName: String) -> Bool {
        isAvailable
    }

    func register(_ font: CGFont) -> FontRegistrationAttempt {
        registrationCount += 1
        return attempt
    }

    private enum TestError: Error {
        case couldNotCreateFont
    }
}
#endif
