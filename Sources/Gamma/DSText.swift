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

import SwiftUI

/// A text view that automatically applies the active theme's line height.
///
/// Use `DSText` in place of SwiftUI's `Text` whenever a theme font has been
/// applied via `.font(_:)` so that line height is respected correctly.
public struct DSText: View {
    @Environment(\.themeFontLineHeight) private var lineHeight

    @usableFromInline let text: Text

    public var body: some View {
        text
            .frame(minHeight: lineHeight)
    }

    @inlinable public init(verbatim content: String) {
        self.text = Text(verbatim: content)
    }

    public init<S>(_ content: S) where S : StringProtocol {
        self.text = Text(content)
    }

    public init(_ key: LocalizedStringKey, tableName: String? = nil, bundle: Bundle? = nil, comment: StaticString? = nil) {
        self.text = Text(key, tableName: tableName, bundle: bundle, comment: comment)
    }

    public init(_ resource: LocalizedStringResource) {
        self.text = Text(resource)
    }

    public init<Subject>(_ subject: Subject, formatter: Formatter) where Subject : ReferenceConvertible {
        self.text = Text(subject, formatter: formatter)
    }

    public init<Subject>(_ subject: Subject, formatter: Formatter) where Subject : NSObject {
        self.text = Text(subject, formatter: formatter)
    }

    public init<F>(_ input: F.FormatInput, format: F) where F : FormatStyle, F.FormatInput : Equatable, F.FormatOutput == String {
        self.text = Text(input, format: format)
    }

    @available(iOS 18.0, *)
    public init<F>(_ input: F.FormatInput, format: F) where F : FormatStyle, F.FormatInput : Equatable, F.FormatOutput == AttributedString {
        self.text = Text(input, format: format)
    }

    public init(_ image: Image) {
        self.text = Text(image)
    }

    public init(_ date: Date, style: Text.DateStyle) {
        self.text = Text(date, style: style)
    }

    public init(_ dates: ClosedRange<Date>) {
        self.text = Text(dates)
    }

    public init(_ interval: DateInterval) {
        self.text = Text(interval)
    }

    public init(timerInterval: ClosedRange<Date>, pauseTime: Date? = nil, countsDown: Bool = true, showsHours: Bool = true) {
        self.text = Text(timerInterval: timerInterval, pauseTime: pauseTime, countsDown: countsDown, showsHours: showsHours)
    }

    public init(_ attributedContent: AttributedString) {
        self.text = Text(attributedContent)
    }

    @available(iOS 18.0, *)
    public init<V, F>(_ source: TimeDataSource<V>, format: F) where V == F.FormatInput, F : DiscreteFormatStyle, F.FormatOutput == AttributedString {
        self.text = Text(source, format: format)
    }

    @available(iOS 18, *)
    public init<V, F>(_ source: TimeDataSource<V>, format: F) where V == F.FormatInput, F : DiscreteFormatStyle, F.FormatOutput == String {
        self.text = Text(source, format: format)
    }
}
