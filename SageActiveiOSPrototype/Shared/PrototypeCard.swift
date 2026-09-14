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
    var size: CGFloat = 24

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .padding(size <= 16 ? 1 : 2)
            .frame(width: size, height: size)
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
    case primary, secondary, information, positive, caution, error

    var id: Self { self }
    var name: String {
        switch self {
        case .primary: "Primary"
        case .secondary: "Secondary"
        case .information: "Information"
        case .positive: "Positive"
        case .caution: "Caution"
        case .error: "Error"
        }
    }

    var colour: Color {
        switch self {
        case .primary: SageActiveTheme.brand
        case .secondary: SageActiveTheme.secondaryVisual
        case .information: SageActiveTheme.informationVisual
        case .positive: SageActiveTheme.positiveVisual
        case .caution: SageActiveTheme.warningVisual
        case .error: SageActiveTheme.negativeVisual
        }
    }
}

struct ChartColourPicker: View {
    let title: String
    @Binding var selection: ChartColour
    var swatchSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 0) {
                ForEach(ChartColour.allCases) { option in
                    Button {
                        selection = option
                    } label: {
                        Circle()
                            .fill(option.colour)
                            .frame(width: swatchSize, height: swatchSize)
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

                    if option != ChartColour.allCases.last {
                        Spacer(minLength: 8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

enum SelectionPillVariant {
    /// The established app pill used by Insights period filters.
    case standard
    /// The outlined document-status treatment used by Sales lists.
    case salesFilter
}

/// A shared pill for time periods, document statuses and future quick-filter controls.
struct SelectionPill: View {
    let title: String
    var count: Int?
    let isSelected: Bool
    var showsSelectionIcon = false
    var variant: SelectionPillVariant = .standard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if showsSelectionIcon && isSelected {
                    SageCarbonIconView(
                        .tickThick,
                        pointSize: 16,
                        color: SageActiveTheme.selectedPillText
                    )
                    .frame(width: 16, height: 16)
                }

                Text(title)
                    .fontWeight(titleWeight)
                if let count {
                    Text("(\(count))")
                        .fontWeight(.regular)
                }
            }
            .font(.subheadline)
            .foregroundStyle(isSelected ? SageActiveTheme.selectedPillText : SageActiveTheme.primaryText)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 8)
            .background(
                fillColour,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(strokeColour, lineWidth: strokeWidth)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var titleWeight: Font.Weight {
        switch variant {
        case .standard: .medium
        case .salesFilter: isSelected ? .semibold : .regular
        }
    }

    private var horizontalPadding: CGFloat {
        switch variant {
        case .standard: 13
        case .salesFilter: 10
        }
    }

    private var fillColour: Color {
        if isSelected {
            return SageActiveTheme.selectedPillBackground
        }

        switch variant {
        case .standard: return SageActiveTheme.pillBackground
        case .salesFilter: return SageActiveTheme.cardBackground
        }
    }

    private var strokeColour: Color {
        if isSelected {
            return SageActiveTheme.selectedPillStroke
        }

        switch variant {
        case .standard: return Color.clear
        case .salesFilter: return SageActiveTheme.unselectedPillStroke
        }
    }

    private var strokeWidth: CGFloat {
        switch variant {
        case .standard: isSelected ? 1.5 : 0
        case .salesFilter: 1
        }
    }
}
