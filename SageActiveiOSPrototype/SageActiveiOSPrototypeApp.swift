import SwiftUI

@main
struct SageActiveiOSPrototypeApp: App {
    @State private var showsStartupAnimation = !ProcessInfo.processInfo.arguments.contains("-skipStartupAnimation")

    init() {
        SageActiveTabBarAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()

                if showsStartupAnimation {
                    StartupAnimationView {
                        showsStartupAnimation = false
                    }
                    .zIndex(1)
                }
            }
        }
    }
}  
