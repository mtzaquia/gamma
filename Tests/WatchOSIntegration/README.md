# iOS and watchOS integration

This fixture embeds a single-target watch app in a phone app. Both import the same `SharedUI` SwiftPM target with GammaBuildPlugin enabled. Building `PhoneProbe` must generate and compile both token and asset aliases separately for iOS and watchOS, without a command-plugin generation step or checked-in aliases.

Generate with `xcodegen generate --spec Tests/WatchOSIntegration/project.yml`, then build `PhoneProbe` for an iPhone simulator and test `WatchProbe` on a watchOS 26+ simulator. The watch tests compare concrete fonts, line height, and kerning with native SwiftUI font resolution across Dynamic Type sizes, and check fallback cascade preservation.

Regenerating this fixture must not require modifying its package manifest or its app targets. The generated project and plist are disposable; retain the source fixture.
