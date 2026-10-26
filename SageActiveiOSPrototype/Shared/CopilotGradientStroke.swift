import SwiftUI

/// The single animated stroke treatment used by Copilot entry points and presentations.
/// Using an absolute-time phase keeps each instance's movement smooth and deterministic.
struct CopilotGradientStroke<StrokeShape: Shape>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let shape: StrokeShape
    var lineWidth: CGFloat = 2
    var opacity: Double = 1

    // Eight seconds keeps the branded movement easy to notice without making
    // the border compete with the sheet's primary content. Smaller controls
    // can opt into a longer cycle so the same movement does not appear rushed.
    var cycleDuration: TimeInterval = 8
    var colors: [Color]? = nil
    var gradient: Gradient? = nil

    private var loopingColors: [Color] {
        let palette = colors ?? SageActiveTheme.speechButtonGradientColors
        guard let firstColor = palette.first else {
            return []
        }

        return palette + [firstColor]
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: reduceMotion || scenePhase != .active
            )
        ) { context in
            shape.stroke(
                AngularGradient(
                    gradient: gradient ?? Gradient(colors: loopingColors),
                    center: .center,
                    startAngle: gradientAngle(at: context.date),
                    endAngle: gradientAngle(at: context.date) + .degrees(360)
                ),
                lineWidth: lineWidth
            )
            .opacity(opacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func gradientAngle(at date: Date) -> Angle {
        guard !reduceMotion else { return .zero }

        let progress = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
        return .degrees(progress * 360)
    }
}
