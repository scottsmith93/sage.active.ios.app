//
//  ColorPalette.swift
//  Graphite
//
//  Copyright © 2021 Sage. All rights reserved.
//

import SwiftUI
import Foundation

// MARK: Base Color Palette
extension Theme {
    public enum GRColorPalette: String, CaseIterable, Identifiable, ShapeStyle {
        public var id: String {
            return rawValue
        }

        // Brand
        case brilliantGreen
        case black
        case grey
        case white

        // Backgrounds
        case background
        case surface
        case backgroundInverted
        case surfaceInverted
        case darkBackground

        // Text Colors
        case onSurface
        case onSurfaceSecondary
        case onPrimary
        case onInverted

        // Utility Colors
        case primaryAccentText
        case primaryAccent100
        case primaryAccent75
        case primaryAccent50
        case primaryAccent25
        case primaryAccent10

        case secondaryAccent100
        case secondaryAccent75
        case secondaryAccent50
        case secondaryAccent25
        case secondaryAccent10

        case tertiaryAccentText
        case tertiaryAccent100
        case tertiaryAccent75
        case tertiaryAccent50
        case tertiaryAccent25
        case tertiaryAccent10

        // Copilot Colors
        case copilotGradientStop1
        case copilotGradientStop2
        case copilotGradientStop3

        // Semantic Colors
        case disabled

        case infoBlueText
        case infoBlue100
        case infoBlue75
        case infoBlue50
        case infoBlue25
        case infoBlue10

        case positiveGreenText
        case positiveGreen100
        case positiveGreen75
        case positiveGreen50
        case positiveGreen25
        case positiveGreen10

        case cautionOrangeText
        case cautionOrange100
        case cautionOrange75
        case cautionOrange50
        case cautionOrange25
        case cautionOrange10

        case errorRedText
        case errorRed100
        case errorRed75
        case errorRed50
        case errorRed25
        case errorRed10

        case shadow
        case secondaryShadow

        public var uiColor: UIColor {
            return UIColor(
                named: self.rawValue,
                in: Bundle.graphiteBundle,
                compatibleWith: nil
            ) ?? .black
        }

        public var color: Color {
            return Color(uiColor)
        }

    }
}
