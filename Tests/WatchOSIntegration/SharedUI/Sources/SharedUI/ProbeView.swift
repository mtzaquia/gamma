import Gamma
import SwiftUI
public struct ProbeView: View {
    @ThemeReader private var theme
    public init() {}
    public var body: some View {
        Text("Gamma integration probe")
            .font(theme.font(.typographyBody))
            .foregroundStyle(theme.color(.contentText))
            .padding(theme.unit(.spacingDefault))
            .theme(.probe, bundle: .module)
    }
}
