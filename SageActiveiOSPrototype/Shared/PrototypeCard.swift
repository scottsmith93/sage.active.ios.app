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
    static let brand = Color(uiColor: .systemGreen)
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
            .padding(2)
            .frame(width: 24, height: 24)
            .background(.white, in: Circle())
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(.quaternary, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
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

enum ChartColour: String, CaseIterable, Identifiable {
    case blue, green, orange, purple, pink, teal

    var id: Self { self }
    var name: String { rawValue.capitalized }
    var colour: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .purple: .purple
        case .pink: .pink
        case .teal: .teal
        }
    }
}

struct ChartColourPicker: View {
    let title: String
    @Binding var selection: ChartColour

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                ForEach(ChartColour.allCases) { option in
                    Button {
                        selection = option
                    } label: {
                        Circle()
                            .fill(option.colour)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if selection == option {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title), \(option.name)")
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}
