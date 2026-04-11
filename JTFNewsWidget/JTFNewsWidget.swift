import WidgetKit
import SwiftUI

struct JTFNewsWidget: Widget {
    let kind: String = "JTFNewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JTFNewsTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(Color(white: 0.1), for: .widget)
        }
        .configurationDisplayName("JTF News")
        .description("Today's verified facts at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetStoryEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

@main
struct JTFNewsWidgetBundle: WidgetBundle {
    var body: some Widget {
        JTFNewsWidget()
        #if os(iOS)
        JTFNewsLiveActivity()
        #endif
    }
}
