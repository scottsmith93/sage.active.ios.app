import SwiftUI

struct PrototypeCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                SageActiveTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: SageActiveTheme.cardCornerRadius, style: .continuous)
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
            .shadow(color: SageActiveTheme.shadow, radius: 2, y: 1)
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
    case primary, secondary, tertiary, information, positive, caution

    var id: Self { self }
    var name: String {
        switch self {
        case .primary: "Primary"
        case .secondary: "Secondary"
        case .tertiary: "Tertiary"
        case .information: "Information"
        case .positive: "Positive"
        case .caution: "Caution"
        }
    }

    var colour: Color {
        switch self {
        case .primary: SageActiveTheme.brand
        case .secondary: SageActiveTheme.secondaryVisual
        case .tertiary: SageActiveTheme.tertiaryVisual
        case .information: SageActiveTheme.informationVisual
        case .positive: SageActiveTheme.positiveVisual
        case .caution: SageActiveTheme.warningVisual
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
                                        .foregroundStyle(SageActiveTheme.primaryText)
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

/// A shared pill for time periods, document statuses and future quick-filter controls.
struct SelectionPill: View {
    let title: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                    .fontWeight(.medium)
                if let count {
                    Text("(\(count))")
                        .fontWeight(.regular)
                }
            }
            .font(.subheadline)
            .foregroundStyle(isSelected ? SageActiveTheme.selectedPillText : SageActiveTheme.primaryText)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                isSelected ? SageActiveTheme.selectedPillBackground : SageActiveTheme.pillBackground,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(isSelected ? SageActiveTheme.selectedPillStroke : .clear, lineWidth: 1.5)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
