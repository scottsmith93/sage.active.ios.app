import SwiftUI
import UIKit

private struct CardMotionPose {
    let pitch: Double
    let roll: Double
    let twist: Double
    let energy: Double

    init(sample: CardMotionSample, orientation: UIInterfaceOrientation) {
        let x: Double
        let y: Double
        switch orientation {
        case .landscapeLeft: x = sample.y; y = -sample.x
        case .landscapeRight: x = -sample.y; y = sample.x
        case .portraitUpsideDown: x = -sample.x; y = -sample.y
        default: x = sample.x; y = sample.y
        }
        pitch = 8 * tanh(x / 0.45)
        roll = -8 * tanh(y / 0.45)
        twist = 2.5 * tanh(sample.z / 0.6)
        energy = sample.energy
    }
}

struct CardMotionEffect: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cornerRadius: CGFloat
    @State private var sample = CardMotionSample.neutral
    @State private var visible = true
    @State private var orientation: UIInterfaceOrientation = .portrait

    private var tracking: Bool {
        visible && scenePhase == .active && !reduceMotion && CardMotionSource.shared.isAvailable
    }

    func body(content: Content) -> some View {
        let pose = CardMotionPose(sample: tracking ? sample : .neutral, orientation: orientation)
        content
            .overlay {
                if tracking { CardMotionShine(pose: pose, cornerRadius: cornerRadius) }
            }
            .shadow(color: SageActiveTheme.shadow.opacity(tracking ? 0.22 : 0), radius: 12,
                    x: -pose.roll * 0.7, y: 5 + pose.pitch * 0.5)
            .rotation3DEffect(.degrees(pose.pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
            .rotation3DEffect(.degrees(pose.roll), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .rotationEffect(.degrees(pose.twist))
            .animation(reduceMotion ? nil : .linear(duration: 1.0 / 30.0), value: sample)
            .background {
                CardMotionOrientationReader { orientation = $0 }
                    .frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true)
            }
            .onScrollVisibilityChange(threshold: 0.1) { visible = $0 }
            .onChange(of: orientation) { _, _ in CardMotionSource.shared.recenter() }
            .task(id: tracking) {
                guard tracking else { sample = .neutral; return }
                for await value in CardMotionSource.shared.updates() {
                    guard !Task.isCancelled else { return }
                    sample = value
                }
            }
    }
}

private struct CardMotionShine: View {
    let pose: CardMotionPose
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let lightX = max(-1, min(1, pose.roll / 8 + pose.twist / 8))
            let lightY = max(-1, min(1, pose.pitch / 8 - pose.twist / 8))
            let intensity = min(1, 0.08 + (abs(lightX) + abs(lightY)) * 0.22 + pose.energy * 0.75)
            ZStack {
                // A bright core with a gradual falloff keeps the reflection glossy
                // without a hard stripe or a uniform wash across the card.
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.43),
                    .init(color: SageActiveTheme.cardShineTint.opacity(0.025), location: 0.45),
                    .init(color: SageActiveTheme.cardShine.opacity(0.12), location: 0.47),
                    .init(color: SageActiveTheme.cardShine.opacity(0.38), location: 0.488),
                    .init(color: SageActiveTheme.cardShine.opacity(0.7), location: 0.496),
                    .init(color: SageActiveTheme.cardShine.opacity(0.95), location: 0.5),
                    .init(color: SageActiveTheme.cardShine.opacity(0.7), location: 0.504),
                    .init(color: SageActiveTheme.cardShine.opacity(0.38), location: 0.512),
                    .init(color: SageActiveTheme.cardShine.opacity(0.12), location: 0.53),
                    .init(color: SageActiveTheme.cardShineTint.opacity(0.025), location: 0.55),
                    .init(color: .clear, location: 0.57)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: geometry.size.width * 2, height: geometry.size.height * 2)
                .blur(radius: 1.25)
                .rotationEffect(.degrees(-20 + pose.twist * 3))
                .offset(x: lightX * geometry.size.width * 0.45, y: lightY * geometry.size.height * 0.4)
                .blendMode(.screen)
                .opacity(intensity * 0.48)

                ZStack {
                    cornerLight(at: UnitPoint(x: 0.015 + lightX * 0.06, y: 0.015 + lightY * 0.06), radius: geometry.size.width * 0.28)
                    cornerLight(at: UnitPoint(x: 0.985 - lightX * 0.06, y: 0.985 - lightY * 0.06), radius: geometry.size.width * 0.28)
                }
                .mask { RoundedRectangle(cornerRadius: cornerRadius, style: .circular).stroke(lineWidth: 1.5) }
                .blendMode(.screen)
                .opacity(intensity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(.rect(cornerRadius: cornerRadius, style: .circular))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cornerLight(at center: UnitPoint, radius: CGFloat) -> some View {
        RadialGradient(stops: [
            .init(color: SageActiveTheme.cardShine, location: 0),
            .init(color: SageActiveTheme.cardShine.opacity(0.95), location: 0.07),
            .init(color: SageActiveTheme.cardShine.opacity(0.8), location: 0.16),
            .init(color: SageActiveTheme.cardShine.opacity(0.5), location: 0.28),
            .init(color: SageActiveTheme.cardShine.opacity(0.22), location: 0.45),
            .init(color: SageActiveTheme.cardShineTint.opacity(0.08), location: 0.6),
            .init(color: .clear, location: 1)
        ], center: center, startRadius: 0, endRadius: radius)
    }
}

/// Read this card's window scene; Duo can have different geometry on each display.
private struct CardMotionOrientationReader: UIViewRepresentable {
    let onChange: (UIInterfaceOrientation) -> Void

    func makeUIView(context: Context) -> OrientationView { OrientationView() }
    func updateUIView(_ view: OrientationView, context: Context) {
        view.onChange = onChange
        view.observeOrientation()
    }

    final class OrientationView: UIView {
        var onChange: ((UIInterfaceOrientation) -> Void)?
        private var lastOrientation: UIInterfaceOrientation?
        private var observation: NSKeyValueObservation?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            observation = window?.windowScene?.observe(\.effectiveGeometry, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.observeOrientation() }
            }
            observeOrientation()
        }

        func observeOrientation() {
            guard let orientation = window?.windowScene?.effectiveGeometry.interfaceOrientation,
                  orientation != .unknown, orientation != lastOrientation else { return }
            lastOrientation = orientation
            let callback = onChange
            DispatchQueue.main.async { callback?(orientation) }
        }
    }
}
