import SwiftUI

enum PrototypeTheme {
    static let pageBackground = Color(uiColor: UIColor { traits in
        let colour: UIColor = traits.userInterfaceStyle == .dark ? .black : .secondarySystemBackground
        return colour.resolvedColor(with: traits)
    })
    static let cardBackground = Color(uiColor: UIColor { traits in
        let colour: UIColor = traits.userInterfaceStyle == .dark ? .secondarySystemBackground : .systemBackground
        return colour.resolvedColor(with: traits)
    })
    static let positive = Color(uiColor: .systemGreen).mix(with: .primary, by: 0.18)
    static let negative = Color(uiColor: .systemRed)
    static let supportingText = Color.primary.opacity(0.68)
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
        Image(assetName)
            .resizable()
            .scaledToFit()
            .padding(3)
            .frame(width: 32, height: 32)
            .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5)
            }
            .accessibilityLabel(name)
    }

    private var assetName: String {
        switch name {
        case "Santander": "bank-santander"
        case "CaixaBank": "bank-caixabank"
        default: "bank-bbva"
        }
    }
}
