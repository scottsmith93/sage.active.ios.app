import SwiftUI
import WidgetKit

struct FinanceSnapshotEntry: TimelineEntry {
    let date: Date
    let unpaidSalesCents: Int
    let unpaidPurchasesCents: Int
}

struct FinanceSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> FinanceSnapshotEntry {
        snapshot
    }

    func getSnapshot(in context: Context, completion: @escaping (FinanceSnapshotEntry) -> Void) {
        completion(snapshot)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FinanceSnapshotEntry>) -> Void) {
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: snapshot.date) ?? snapshot.date
        completion(Timeline(entries: [snapshot], policy: .after(nextRefresh)))
    }

    private var snapshot: FinanceSnapshotEntry {
        FinanceSnapshotEntry(
            date: Date(),
            unpaidSalesCents: 1_000_000,
            unpaidPurchasesCents: 735_000
        )
    }
}

struct FinanceSnapshotWidgetView: View {
    let entry: FinanceSnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 14) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("Action needed")
                    .font(.headline)
                Spacer(minLength: 0)
            }

            if family == .systemSmall {
                KPI(label: "Sales unpaid", cents: entry.unpaidSalesCents)
                KPI(label: "Purchases unpaid", cents: entry.unpaidPurchasesCents)
            } else {
                HStack(spacing: 18) {
                    KPI(label: "Sales unpaid", cents: entry.unpaidSalesCents)
                    Divider()
                    KPI(label: "Purchases unpaid", cents: entry.unpaidPurchasesCents)
                }
            }

            Text("Tap to review invoices")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.background, for: .widget)
    }

    private struct KPI: View {
        let label: String
        let cents: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(Self.euro(cents))
                    .font(.title3.bold())
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private static func euro(_ cents: Int) -> String {
            (Double(cents) / 100).formatted(
                .currency(code: "EUR")
                    .locale(Locale(identifier: "es_ES"))
                    .precision(.fractionLength(0))
            )
        }
    }
}

struct FinanceSnapshotWidget: Widget {
    let kind = "com.example.SageActive.finance-snapshot"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinanceSnapshotProvider()) { entry in
            FinanceSnapshotWidgetView(entry: entry)
        }
        .configurationDisplayName("Invoice actions")
        .description("Shows unpaid sales and purchase invoice totals.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SageActiveWidgetBundle: WidgetBundle {
    var body: some Widget {
        FinanceSnapshotWidget()
    }
}
