// NexusTrade home-screen widget (iOS, WidgetKit).
// Data is written by the app via home_widget into the App Group
// "group.uz.nexustrade.app" (see lib/state/widget_sync.dart).
// Setup in Xcode: see docs/WIDGET.md.
import SwiftUI
import WidgetKit

private let appGroup = "group.uz.nexustrade.app"
private let gold = Color(red: 0.83, green: 0.70, blue: 0.42)

struct NexusEntry: TimelineEntry {
    let date: Date
    let countLabel: String
    let count: String
    let deal: String
    let client: String
    let stage: String
    let progress: Int
    let progressMax: Int
    let sumLabel: String
    let sum: String
    let profitLabel: String
    let profit: String
    let profitNegative: Bool

    static func load() -> NexusEntry {
        let d = UserDefaults(suiteName: appGroup)
        func s(_ k: String, _ f: String = "") -> String { d?.string(forKey: k) ?? f }
        return NexusEntry(
            date: Date(),
            countLabel: s("w_count_label", "Active contracts"),
            count: s("w_count", "0"),
            deal: s("w_deal", "NexusTrade"),
            client: s("w_client"),
            stage: s("w_stage"),
            progress: d?.integer(forKey: "w_progress") ?? 0,
            progressMax: max(d?.integer(forKey: "w_progress_max") ?? 4, 1),
            sumLabel: s("w_sum_label", "Contract amount"),
            sum: s("w_sum", "—"),
            profitLabel: s("w_profit_label", "Profit"),
            profit: s("w_profit", "—"),
            profitNegative: d?.bool(forKey: "w_profit_negative") ?? false
        )
    }
}

struct NexusProvider: TimelineProvider {
    func placeholder(in context: Context) -> NexusEntry { NexusEntry.load() }
    func getSnapshot(in context: Context, completion: @escaping (NexusEntry) -> Void) {
        completion(NexusEntry.load())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NexusEntry>) -> Void) {
        // The app asks WidgetKit to reload whenever the data changes.
        completion(Timeline(entries: [NexusEntry.load()], policy: .never))
    }
}

struct NexusWidgetView: View {
    let e: NexusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(e.count).font(.system(size: 26, weight: .bold)).foregroundColor(gold)
                Text(e.countLabel).font(.caption).foregroundColor(.white.opacity(0.7)).lineLimit(1)
                Spacer()
                Text("NexusTrade").font(.caption2).foregroundColor(gold.opacity(0.6))
            }
            Text(e.deal).font(.subheadline.bold()).foregroundColor(.white).lineLimit(1)
            if !e.client.isEmpty {
                Text(e.client).font(.caption2).foregroundColor(.white.opacity(0.6)).lineLimit(1)
            }
            ProgressView(value: Double(e.progress), total: Double(e.progressMax)).tint(gold)
            Text(e.stage).font(.caption2).foregroundColor(gold).lineLimit(1)
            HStack {
                VStack(alignment: .leading) {
                    Text(e.sumLabel).font(.caption2).foregroundColor(.white.opacity(0.6))
                    Text(e.sum).font(.footnote.bold()).foregroundColor(.white).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(e.profitLabel).font(.caption2).foregroundColor(.white.opacity(0.6))
                    Text(e.profit).font(.footnote.bold())
                        .foregroundColor(e.profitNegative ? Color(red: 1, green: 0.48, blue: 0.48)
                                                          : Color(red: 0.48, green: 0.88, blue: 0.66))
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.05, green: 0.14, blue: 0.27), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .widgetURL(URL(string: "nexustrade://widget"))
    }
}

@main
struct NexusWidget: Widget {
    // Must match HomeWidgetBridge.iOSName in lib/state/widget_sync.dart.
    let kind = "NexusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NexusProvider()) { entry in
            NexusWidgetView(e: entry)
        }
        .configurationDisplayName("NexusTrade")
        .description("Contracts, stage, amount, profit")
        .supportedFamilies([.systemMedium])
    }
}
