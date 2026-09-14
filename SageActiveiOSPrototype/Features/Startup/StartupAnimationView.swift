import Lottie
import SwiftUI

/// Plays the bundled Sage animation once, then hands off to the live app with a restrained system-style transition.
struct StartupAnimationView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playbackMode = LottiePlaybackMode.paused(at: .currentFrame)
    @State private var hasStartedExit = false
    @State private var exitScale: CGFloat = 1
    @State private var exitOpacity: Double = 1

    var body: some View {
        ZStack {
            SageActiveTheme.pageBackground

            LottieView {
                try await DotLottieFile.named("SageActiveSplash")
            } placeholder: {
                SageActiveTheme.pageBackground
            }
            .playbackMode(playbackMode)
            .animationDidFinish { completed in
                guard completed else { return }
                beginExitSequence()
            }
            .resizable()
            .aspectRatio(360 / 812, contentMode: .fill)
        }
        .scaleEffect(exitScale)
        .opacity(exitOpacity)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    beginExitSequence()
                }
            } else {
                playbackMode = .playing(
                    .fromProgress(0, toProgress: 1, loopMode: .playOnce)
                )

                // Never hold the user on the startup layer if decoding unexpectedly fails.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(4))
                    beginExitSequence()
                }
            }
        }
    }

    private func beginExitSequence() {
        guard !hasStartedExit else { return }
        hasStartedExit = true

        Task { @MainActor in
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.20)) {
                    exitOpacity = 0
                }
                try? await Task.sleep(for: .milliseconds(200))
            } else {
                withAnimation(.smooth(duration: 0.30)) {
                    exitScale = 0.98
                    exitOpacity = 0
                }
                try? await Task.sleep(for: .milliseconds(300))
            }

            onFinished()
        }
    }
}
