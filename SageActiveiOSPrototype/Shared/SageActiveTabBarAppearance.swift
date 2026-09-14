import UIKit

@MainActor
enum SageActiveTabBarAppearance {
    static func configure() {
        let appearance = makeAppearance()
        let tabBar = UITabBar.appearance()

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = SageActiveTheme.tabBarSelectedForeground
        tabBar.unselectedItemTintColor = SageActiveTheme.tabBarUnselectedForeground
    }

    private static func makeAppearance() -> UITabBarAppearance {
        let appearance = UITabBarAppearance()

        // Retain Apple's native iOS 26 Liquid Glass surface and movement.
        appearance.configureWithDefaultBackground()
        appearance.selectionIndicatorTintColor = SageActiveTheme.tabBarSelectedBackground

        configure(appearance.stackedLayoutAppearance)
        configure(appearance.inlineLayoutAppearance)
        configure(appearance.compactInlineLayoutAppearance)
        return appearance
    }

    private static func configure(_ appearance: UITabBarItemAppearance) {
        appearance.normal.iconColor = SageActiveTheme.tabBarUnselectedForeground
        appearance.normal.titleTextAttributes = [
            .foregroundColor: SageActiveTheme.tabBarUnselectedForeground,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
        ]

        appearance.selected.iconColor = SageActiveTheme.tabBarSelectedForeground
        appearance.selected.titleTextAttributes = [
            .foregroundColor: SageActiveTheme.tabBarSelectedForeground,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
        ]
    }
}
