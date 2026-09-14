import SwiftUI

enum ChartDataView: String, CaseIterable, Identifiable {
    case chart
    case table

    var id: Self { self }

    var accessibilityLabel: String {
        switch self {
        case .chart: "Chart view"
        case .table: "Table view"
        }
    }

    var icon: SageCarbonIcon {
        switch self {
        case .chart: .chartLine
        case .table: .listView
        }
    }
}

/// A native, reusable view selector for every data visualisation that offers an
/// accessible tabular alternative. Visible labels are icons; the Label titles
/// remain available to VoiceOver through the native segmented Picker.
struct ChartDataViewSwitcher: View {
    @Binding var selection: ChartDataView

    var body: some View {
        Picker("Data presentation", selection: $selection) {
            ForEach(ChartDataView.allCases) { option in
                Label {
                    Text(option.accessibilityLabel)
                } icon: {
                    // A segmented Picker is backed by UISegmentedControl, which
                    // does not preserve custom fonts used by Text glyphs. Supply
                    // a rendered template image so the Carbon icon survives the
                    // native control's UIKit bridge and inherits its tint.
                    SageCarbonTabIcon(option.icon, pointSize: 16)
                    .frame(width: 16, height: 16)
                }
                .labelStyle(.iconOnly)
                .tag(option)
                .accessibilityLabel(option.accessibilityLabel)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: 88, height: 36)
        .accessibilityLabel("Data presentation")
        .accessibilityValue(selection.accessibilityLabel)
    }
}

/// Applies one consistent, system-native layout animation whenever a chart changes between its
/// visual and tabular representations. With Reduce Motion enabled the transaction has no
/// animation, so the same state change remains immediate and predictable.
private struct ChartDataViewMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let selection: ChartDataView

    func body(content: Content) -> some View {
        content
            .animation(
                accessibilityReduceMotion ? nil : .smooth(duration: 0.35),
                value: selection
            )
    }
}

extension View {
    func chartDataViewMotion(for selection: ChartDataView) -> some View {
        modifier(ChartDataViewMotionModifier(selection: selection))
    }
}

extension AnyTransition {
    /// A restrained cross-fade lets the card-height animation carry the spatial relationship.
    static var chartDataViewSwap: AnyTransition { .opacity }
}

struct ChartValueTableRow: Identifiable {
    let id: String
    let date: String
    let totalCents: Int
}

struct ChartValueTable: View {
    let rows: [ChartValueTableRow]

    var body: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider()

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.date)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(MoneyFormatting.euro(row.totalCents))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(SageActiveTheme.supportingText)
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.date), total \(MoneyFormatting.euro(row.totalCents))")

                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Data table")
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text("Dates")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Total")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(SageActiveTheme.primaryText)
        .padding(.bottom, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Columns: dates and total")
    }
}

struct ProjectedBalanceTableRow: Identifiable {
    let id: String
    let date: String
    let balanceCents: Int
    let growth: Double?
}

struct ProjectedBalanceDataTable: View {
    let rows: [ProjectedBalanceTableRow]

    var body: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider()

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.date)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(MoneyFormatting.euro(row.balanceCents))
                        .frame(width: 116, alignment: .leading)

                    Text(growthLabel(row.growth))
                        .foregroundStyle(growthColour(row.growth))
                        .frame(width: 66, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(SageActiveTheme.supportingText)
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(row.date), projected balance \(MoneyFormatting.euro(row.balanceCents)), "
                    + "growth \(growthAccessibilityLabel(row.growth))"
                )

                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Projected balance data table")
    }

    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text("Dates")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Projected balance")
                .frame(width: 116, alignment: .leading)
            Text("Growth")
                .frame(width: 66, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(SageActiveTheme.primaryText)
        .padding(.bottom, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Columns: dates, projected balance and growth")
    }

    private func growthLabel(_ growth: Double?) -> String {
        growth.map { PrototypeFormatting.percent($0) } ?? "—"
    }

    private func growthAccessibilityLabel(_ growth: Double?) -> String {
        growth.map { PrototypeFormatting.percent($0, signed: false) } ?? "not available"
    }

    private func growthColour(_ growth: Double?) -> Color {
        guard let growth else { return SageActiveTheme.supportingText }
        if growth > 0 { return SageActiveTheme.positiveText }
        if growth < 0 { return SageActiveTheme.negativeText }
        return SageActiveTheme.supportingText
    }
}

struct CashMovementTableRow: Identifiable {
    let id: String
    let date: String
    let moneyInCents: Int
    let moneyOutCents: Int

    var netCents: Int { moneyInCents - moneyOutCents }
}

struct CashMovementDataTable: View {
    let rows: [CashMovementTableRow]

    var body: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider()

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .top, spacing: 8) {
                    Text(row.date)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("In: \(MoneyFormatting.euro(row.moneyInCents))")
                        Text("Out: \(MoneyFormatting.euro(row.moneyOutCents))")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(MoneyFormatting.signedEuro(row.netCents))
                        .frame(width: 84, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(SageActiveTheme.supportingText)
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(row.date), money in \(MoneyFormatting.euro(row.moneyInCents)), "
                    + "money out \(MoneyFormatting.euro(row.moneyOutCents)), "
                    + "net \(MoneyFormatting.signedEuro(row.netCents))"
                )

                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cash movement data table")
    }

    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text("Dates")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Transactions")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Net")
                .frame(width: 84, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(SageActiveTheme.primaryText)
        .padding(.bottom, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Columns: dates, transactions and net")
    }
}
