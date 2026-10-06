import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BodyTrainerWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeighInLiveActivity()
    }
}

struct WeighInLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WeighInAttributes.self) { ctx in
            LockScreenTrend(state: ctx.state)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.teal)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Weigh-in", systemImage: "scalemass.fill")
                        .font(.caption.bold()).foregroundStyle(.teal)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(ctx.state.deltaText).font(.headline).foregroundStyle(ctx.state.deltaColor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(ctx.state.trendText).font(.subheadline).lineLimit(1).minimumScaleFactor(0.7)
                }
            } compactLeading: {
                Image(systemName: "scalemass.fill").foregroundStyle(.teal)
            } compactTrailing: {
                Text(ctx.state.deltaText).foregroundStyle(ctx.state.deltaColor)
            } minimal: {
                Image(systemName: "scalemass.fill").foregroundStyle(.teal)
            }
        }
    }
}

private struct LockScreenTrend: View {
    let state: WeighInAttributes.ContentState

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Weigh-in", systemImage: "scalemass.fill").font(.caption.bold()).foregroundStyle(.teal)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(state.latestText).font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(state.unit.rawValue).foregroundStyle(.secondary)
                }
                Text(state.trendText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(state.deltaText)
                .font(.title2.bold())
                .foregroundStyle(state.deltaColor)
        }
    }
}
