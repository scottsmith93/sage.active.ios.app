import SwiftUI

struct PrototypeCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

