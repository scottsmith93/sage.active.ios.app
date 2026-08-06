import SwiftUI

enum PrototypeTheme {
    static let pageBackground = Color(uiColor: .secondarySystemBackground)
    static let cardBackground = Color(uiColor: .systemBackground)
    static let cardCornerRadius: CGFloat = 24
    static let pageSpacing: CGFloat = 16
    static let relatedSpacing: CGFloat = 4
}

struct PrototypeCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PrototypeTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: PrototypeTheme.cardCornerRadius, style: .continuous)
            )
    }
}

struct BankBadge: View {
    let name: String

    var body: some View {
        Text(initials)
            .font(.caption2.weight(.bold))
            .frame(width: 30, height: 30)
            .background(.quaternary, in: Circle())
            .accessibilityLabel(name)
    }

    private var initials: String {
        switch name {
        case "Santander": "SAN"
        case "CaixaBank": "CX"
        default: String(name.prefix(3)).uppercased()
        }
    }
}
