import SwiftUI

/// The Figma background study uses a short Copilot gradient under a veil that
/// fades from 80% page colour to 100%. Keep the native page beneath it adaptive.
struct SageActiveMeshBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: SageActiveTheme.speechButtonGradientColors[0], location: 0),
                        .init(color: SageActiveTheme.speechButtonGradientColors[1], location: 0.64423),
                        .init(color: SageActiveTheme.speechButtonGradientColors[2], location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .opacity(colorScheme == .dark ? 0.20 : 0.14)
                .mask {
                    LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                }
                .frame(height: min(max(geometry.size.height * 0.1773, 150), 190))

                LinearGradient(
                    colors: [SageActiveTheme.meshBrandGreen.opacity(colorScheme == .dark ? 0.08 : 0.06), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .mask { LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom) }
                .frame(height: min(max(geometry.size.height * 0.1133, 90), 128))
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
