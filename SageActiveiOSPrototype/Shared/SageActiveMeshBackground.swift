import SwiftUI

/// A decorative, token-driven brand wash for the top of dashboard surfaces.
///
/// The mesh deliberately resolves to the page background before its lower edge so it never
/// becomes a competing full-screen treatment. It has no interaction or accessibility meaning.
struct SageActiveMeshBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                topMesh(for: geometry.size.height)

                bottomCornerWash
                    .frame(height: bottomWashHeight(for: geometry.size.height))
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func topMesh(for availableHeight: CGFloat) -> some View {
        mesh(points: restingMeshPoints)
        .frame(maxWidth: .infinity)
        // The light Figma variant keeps the top wash to roughly 25% of the viewport. Keeping
        // this region short is important: the large navigation title and its subtitle remain
        // on a calm background when the title collapses during scrolling.
        .frame(height: topMeshHeight(for: availableHeight))
        .mask {
            if colorScheme == .dark {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.00),
                        .init(color: .white.opacity(0.96), location: 0.34),
                        .init(color: .white.opacity(0.34), location: 0.68),
                        .init(color: .clear, location: 1.00),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                // The Figma light variant uses a translucent white veil over the brand wash.
                // This keeps the colours present at the status-bar edge but removes the strong
                // colour field that was reducing subtitle contrast after the title collapsed.
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.38), location: 0.00),
                        .init(color: .white.opacity(0.28), location: 0.24),
                        .init(color: .white.opacity(0.08), location: 0.64),
                        .init(color: .clear, location: 1.00),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private func topMeshHeight(for availableHeight: CGFloat) -> CGFloat {
        if colorScheme == .dark {
            return 400
        }

        return min(max(availableHeight * 0.253, 200), 240)
    }

    private func mesh(points: [SIMD2<Float>]) -> some View {
        MeshGradient(
            width: 3,
            height: 4,
            points: points,
            colors: meshColors,
            background: SageActiveTheme.pageBackground,
            smoothsColors: true,
            colorSpace: .perceptual
        )
    }

    private var restingMeshPoints: [SIMD2<Float>] {
        [
            .init(0.00, 0.00), .init(0.50, 0.00), .init(1.00, 0.00),
            .init(0.00, 0.20), .init(0.50, 0.20), .init(1.00, 0.20),
            .init(0.00, 0.52), .init(0.50, 0.52), .init(1.00, 0.52),
            .init(0.00, 1.00), .init(0.50, 1.00), .init(1.00, 1.00),
        ]
    }

    /// A separate lower-corner accent based on the Figma background study. Keeping it outside
    /// `topMesh` preserves the established top gradient exactly while allowing the lower wash to
    /// adapt to the visible screen height. The two-axis fade keeps the green confined to one corner.
    private var bottomCornerWash: some View {
        LinearGradient(
            colors: [bottomGreen, .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask {
            LinearGradient(
                colors: [.clear, .white.opacity(0.20), .white],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var bottomGreen: Color {
        // Light Mode uses a softer wash so the mesh remains atmospheric rather than
        // competing with the content on brighter and wider simulator displays.
        SageActiveTheme.meshBrandGreen.opacity(colorScheme == .dark ? 0.25 : 0.22)
    }

    private func bottomWashHeight(for availableHeight: CGFloat) -> CGFloat {
        if colorScheme == .dark {
            // The updated dark treatment occupies the lowest 20% of the reference screen.
            return min(max(availableHeight * 0.20, 160), 220)
        }

        // Figma retains the shorter lower wash in Light Mode.
        return min(max(availableHeight * 0.115, 96), 128)
    }

    private var meshColors: [Color] {
        let background = SageActiveTheme.pageBackground

        if colorScheme == .dark {
            return [
                SageActiveTheme.meshBrandGreen.opacity(0.44),
                SageActiveTheme.meshBrandGreen.opacity(0.36),
                SageActiveTheme.meshBrandBlue.opacity(0.50),
                SageActiveTheme.meshBrandGreen.opacity(0.36),
                SageActiveTheme.meshBrandGreen.opacity(0.44),
                SageActiveTheme.meshBrandBlue.opacity(0.50),
                SageActiveTheme.meshBrandGreen.opacity(0.20),
                background,
                SageActiveTheme.meshBrandBlue.opacity(0.24),
                background,
                background,
                background,
            ]
        }

        return [
            // The Figma light variant keeps the brand colours intact, then applies a translucent
            // background veil in the mask above. This preserves the visible blue/green at the
            // status-bar edge while still resolving quickly to the page background.
            SageActiveTheme.meshBrandGreen.opacity(0.78),
            SageActiveTheme.meshBrandGreen.opacity(0.66),
            SageActiveTheme.meshBrandBlue.opacity(0.80),
            SageActiveTheme.meshBrandGreen.opacity(0.66),
            SageActiveTheme.meshBrandGreen.opacity(0.78),
            SageActiveTheme.meshBrandBlue.opacity(0.80),
            SageActiveTheme.meshBrandGreen.opacity(0.22),
            background,
            SageActiveTheme.meshBrandBlue.opacity(0.24),
            background, background, background,
        ]
    }
}
