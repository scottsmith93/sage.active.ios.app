import Graphite
import SwiftUI

/// The app-facing styling boundary for Sage Active.
///
/// Feature views use these semantic roles instead of importing Graphite directly. When Sage's
/// future `DS*` token library replaces the legacy `GR*` palette, only this adapter needs to change.
enum SageActiveTheme {
    static let darkerSurfacePreferenceKey = "dashboardDarkModeDarkerSurface"

    /// Shared app background. Graphite supplies the light-mode value; the dark-mode value is
    /// intentionally app-owned so every page uses the same very dark green rather than mixing
    /// Graphite black with feature-specific backgrounds.
    static let pageBackground = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0 / 255, green: 8 / 255, blue: 2 / 255, alpha: 1)
        }

        return UIColor(Theme.GRColorPalette.background.color)
            .resolvedColor(with: traits)
    })
    static var cardBackground: Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark,
               UserDefaults.standard.bool(forKey: darkerSurfacePreferenceKey) {
                return UIColor(red: 25 / 255, green: 25 / 255, blue: 25 / 255, alpha: 1)
            }

            return UIColor(Theme.GRColorPalette.surface.color)
                .resolvedColor(with: traits)
        })
    }

    static let primaryText = Theme.GRColorPalette.onSurface.color
    static let supportingText = Theme.GRColorPalette.onSurfaceSecondary.color
    static let white = Theme.GRColorPalette.white.color
    static let brand = Theme.GRColorPalette.primaryAccent100.color
    static let brilliantGreen = Theme.GRColorPalette.brilliantGreen.color
    static let onBrand = Theme.GRColorPalette.onPrimary.color
    /// Brand gradient used for high-priority creation actions.
    static let brandGradient = LinearGradient(
        colors: [brand, brilliantGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Official Graphite AI/Copilot gradient used by the speech-entry control.
    /// Keeping the three stops behind this adapter means the feature does not
    /// import Graphite directly and future token migrations stay localized here.
    static let speechButtonGradient = LinearGradient(
        colors: speechButtonGradientColors,
        startPoint: .leading,
        endPoint: .trailing
    )
    /// The same Copilot gradient stops exposed as semantic colours for effects
    /// that need to animate the gradient itself (for example, a sheet halo).
    /// Feature views still use this adapter rather than importing Graphite.
    static let speechButtonGradientColors: [Color] = [
        Theme.GRColorPalette.copilotGradientStop1.color,
        Theme.GRColorPalette.copilotGradientStop2.color,
        Theme.GRColorPalette.copilotGradientStop3.color
    ]
    /// Fixed dark foreground for bright primary actions in either appearance mode.
    static let primaryActionForeground = Theme.GRColorPalette.backgroundInverted.color

    // Dedicated decorative roles for the dashboard mesh. Keeping these named prevents the
    // supplied brand values from leaking into interactive controls or data visualisations.
    static let meshBrandGreen = Color("MeshBrandGreen")
    static let meshBrandBlue = Color("MeshBrandBlue")

    // Native tab bar roles. These remain dynamic UIColors so UIKit resolves the correct
    // Graphite value immediately when the device changes between Light and Dark Mode.
    static let tabBarSelectedForeground = Theme.GRColorPalette.brilliantGreen.uiColor
    static let tabBarSelectedBackground = Theme.GRColorPalette.secondaryAccent10.uiColor
    static let tabBarUnselectedForeground = Theme.GRColorPalette.onSurfaceSecondary.uiColor

    static let pillBackground = Theme.GRColorPalette.secondaryAccent10.color
    /// Utility / Secondary / 010, used for the low-emphasis recording waveform.
    static let secondaryUtility10 = Theme.GRColorPalette.secondaryAccent10.color
    /// Utility / Secondary / 025, used for the speech recording waveform.
    static let secondaryUtility25 = Theme.GRColorPalette.secondaryAccent25.color
    static let selectedPillBackground = Theme.GRColorPalette.primaryAccent10.color
    static let selectedPillText = Theme.GRColorPalette.primaryAccent100.color
    static let selectedPillStroke = Theme.GRColorPalette.primaryAccent100.color
    /// The light outline used by the Sales document status filters. Keeping this as a
    /// semantic Graphite token means it resolves correctly in dark mode as well.
    static let unselectedPillStroke = Theme.GRColorPalette.secondaryAccent25.color
    static let profileHighlightBackground = Theme.GRColorPalette.tertiaryAccent10.color

    static let positiveText = Theme.GRColorPalette.positiveGreenText.color
    static let positiveVisual = Theme.GRColorPalette.positiveGreen100.color
    static let negativeText = Theme.GRColorPalette.errorRedText.color
    static let negativeVisual = Theme.GRColorPalette.errorRed100.color
    static let warningText = Theme.GRColorPalette.cautionOrangeText.color
    static let warningVisual = Theme.GRColorPalette.cautionOrange100.color
    static let warningBackground = Theme.GRColorPalette.cautionOrange10.color
    static let warningBorder = Theme.GRColorPalette.cautionOrange50.color
    static let informationText = Theme.GRColorPalette.infoBlueText.color
    static let informationVisual = Theme.GRColorPalette.infoBlue100.color
    static let informationBackground = Theme.GRColorPalette.infoBlue10.color
    static let informationBorder = Theme.GRColorPalette.infoBlue50.color
    static let positiveBackground = Theme.GRColorPalette.positiveGreen10.color
    static let positiveBorder = Theme.GRColorPalette.positiveGreen50.color
    static let negativeBackground = Theme.GRColorPalette.errorRed10.color
    static let negativeBorder = Theme.GRColorPalette.errorRed50.color
    static let secondaryVisual = Theme.GRColorPalette.secondaryAccent100.color
    static let tertiaryVisual = Theme.GRColorPalette.tertiaryAccent100.color
    static let disabled = Theme.GRColorPalette.disabled.color
    static let shadow = Theme.GRColorPalette.shadow.color

    // Graphite's current geometry values are component-specific and don't yet expose stable DS
    // semantic roles. These remain app-owned until the future DSTokens façade is available.
    static let cardCornerRadius: CGFloat = 24
    static let pageSpacing: CGFloat = 16
    static let relatedSpacing: CGFloat = 4
    static let controlSpacing: CGFloat = 12

    /// Six Graphite 100-strength colours used for data visualisation.
    static let chartPalette100: [Color] = [
        brand,
        secondaryVisual,
        informationVisual,
        positiveVisual,
        warningVisual,
        negativeVisual
    ]
}
