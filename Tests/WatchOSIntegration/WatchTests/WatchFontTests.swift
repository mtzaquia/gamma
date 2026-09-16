import CoreText
@testable import Gamma
import SwiftUI
import Testing
import UIKit

@MainActor @Suite("Native watch typography")
struct WatchFontTests {
    @Test(arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility3])
    func fontAndMetricsShareNativeScaling(size: DynamicTypeSize) {
        var environment = EnvironmentValues()
        environment.dynamicTypeSize = size
        let expected = Font.custom("Helvetica", size: 17, relativeTo: .body)
            .resolve(in: environment.fontResolutionContext).pointSize
        let font = ThemeFont(fontName: "Helvetica", cascadeFontNames: [], fontSize: 17,
                             lineHeight: 24, letterSpacing: 10, textCase: nil, textStyle: .body)
        let actual = font.font(for: size).resolve(in: environment.fontResolutionContext).pointSize
        #expect(abs(actual - expected) < 0.01)
        #expect(abs(font.uiFont(for: size).pointSize - expected) < 0.01)
        #expect(abs(font.lineHeight(for: size) - expected * 24 / 17) < 0.01)
        #expect(abs(font.kerning(for: size) - expected * 0.1) < 0.01)
    }
    @Test
    func concreteFontKeepsFallbackCascade() {
        let font = ThemeFont(fontName: "Helvetica", cascadeFontNames: ["Courier"], fontSize: 17,
                             lineHeight: nil, letterSpacing: nil, textCase: nil, textStyle: .body)
        let descriptors = font.uiFont(for: .large).fontDescriptor.object(forKey: .cascadeList) as? [UIFontDescriptor]
        #expect(descriptors?.first?.postscriptName == "Courier")
    }
}
