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

/// Identifies one installed theme and resolver context without coupling cache
/// entries to the mode names returned by that resolver.
struct ThemeCacheScope: Hashable {
    let themeInstanceID: UUID
    let overrideHash: Int
    let modeResolver: AnyThemeModeResolver
    let layoutDirection: LayoutDirection
    let horizontalSizeClass: UserInterfaceSizeClass?
}

struct ThemeTokenCacheKey: Hashable {
    let scope: ThemeCacheScope
    let alias: String
}

/// Dynamic Type size is the only system variant of the concrete font object.
/// Text style is intentionally absent: the runtime scaling pipeline owns it and
/// callers with the same face, cascade, and base size reuse the scaled result.
struct ThemeFontCacheKey: Hashable {
    let fontName: String
    let cascadeFontNames: [String]
    let size: CGFloat
    let dynamicTypeSize: DynamicTypeSize
}

/// A small LRU cache. Token data can be server-driven, so every cache has an
/// explicit bound instead of retaining every theme and override ever observed.
final class BoundedCache<Key: Hashable, Value> {
    let countLimit: Int

    private var storage: [Key: Value] = [:]
    private var recency: [Key] = []

    init(countLimit: Int) {
        precondition(countLimit > 0)
        self.countLimit = countLimit
    }

    subscript(key: Key) -> Value? {
        get {
            guard let value = storage[key] else { return nil }
            markRecentlyUsed(key)
            return value
        }
        set {
            guard let newValue else {
                storage.removeValue(forKey: key)
                recency.removeAll { $0 == key }
                return
            }

            storage[key] = newValue
            markRecentlyUsed(key)
            evictIfNeeded()
        }
    }

    var count: Int { storage.count }

    private func markRecentlyUsed(_ key: Key) {
        recency.removeAll { $0 == key }
        recency.append(key)
    }

    private func evictIfNeeded() {
        while storage.count > countLimit, let oldest = recency.first {
            recency.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}

enum ThemeProxyCache {
    static let colorCache = BoundedCache<ThemeTokenCacheKey, Color>(countLimit: 256)
    static let fontCache = BoundedCache<ThemeTokenCacheKey, ThemeFont>(countLimit: 256)
    static let unitCache = BoundedCache<ThemeTokenCacheKey, CGFloat>(countLimit: 512)
    static let uiFontCache = BoundedCache<ThemeFontCacheKey, UIFont>(countLimit: 256)
    static let swiftUIFontCache = BoundedCache<ThemeFontCacheKey, Font>(countLimit: 256)

}
