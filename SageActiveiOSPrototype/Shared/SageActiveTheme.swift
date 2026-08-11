import Graphite
import SwiftUI

/// The app-facing styling boundary for Sage Active.
///
/// Feature views use these semantic roles instead of importing Graphite directly. When Sage's
/// future `DS*` token library replaces the legacy `GR*` palette, only this adapter needs to change.
enum SageActiveTheme {
    static let pageBackground = Theme.GRColorPalette.background.color
    static let cardBackground = Theme.GRColorPalette.surface.color

    static let primaryText = Theme.GRColorPalette.onSurface.color
    static let supportingText = Theme.GRColorPalette.onSurfaceSecondary.color
    static let brand = Theme.GRColorPalette.primaryAccent100.color
    static let onBrand = Theme.GRColorPalette.onPrimary.color

    static let pillBackground = Theme.GRColorPalette.secondaryAccent10.color
    static let selectedPillBackground = Theme.GRColorPalette.primaryAccent10.color
    static let selectedPillText = Theme.GRColorPalette.primaryAccent100.color
    static let selectedPillStroke = Theme.GRColorPalette.primaryAccent100.color

    static let positiveText = Theme.GRColorPalette.positiveGreenText.color
    static let positiveVisual = Theme.GRColorPalette.positiveGreen100.color
    static let negativeText = Theme.GRColorPalette.errorRedText.color
    static let negativeVisual = Theme.GRColorPalette.errorRed100.color
    static let warningText = Theme.GRColorPalette.cautionOrangeText.color
    static let warningVisual = Theme.GRColorPalette.cautionOrange100.color
    static let informationText = Theme.GRColorPalette.infoBlueText.color
    static let informationVisual = Theme.GRColorPalette.infoBlue100.color
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
        tertiaryVisual,
        informationVisual,
        positiveVisual,
        warningVisual
    ]
}
