import WidgetKit
import SwiftUI

struct VoiceNoteEntry: TimelineEntry {
    let date: Date
}

struct VoiceNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> VoiceNoteEntry {
        VoiceNoteEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (VoiceNoteEntry) -> ()) {
        completion(VoiceNoteEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VoiceNoteEntry>) -> ()) {
        let entry = VoiceNoteEntry(date: Date())
        // Static complication - no need to refresh
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct CircularComplicationView: View {
    var entry: VoiceNoteProvider.Entry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(.white)
        }
        .widgetURL(URL(string: "nolooknotetaker://record"))
    }
}

struct CornerComplicationView: View {
    var entry: VoiceNoteProvider.Entry

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.title3)
            .widgetLabel {
                Text("Note")
            }
            .widgetURL(URL(string: "nolooknotetaker://record"))
    }
}

struct RectangularComplicationView: View {
    var entry: VoiceNoteProvider.Entry

    var body: some View {
        HStack {
            Image(systemName: "mic.fill")
                .font(.title2)
            VStack(alignment: .leading) {
                Text("Voice Note")
                    .font(.headline)
                Text("Tap to record")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .widgetURL(URL(string: "nolooknotetaker://record"))
    }
}

@main
struct VoiceNoteWidget: Widget {
    let kind: String = "VoiceNoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VoiceNoteProvider()) { entry in
            VoiceNoteWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Voice Note")
        .description("Tap to record a voice note")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular
        ])
    }
}

struct VoiceNoteWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: VoiceNoteProvider.Entry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        default:
            CircularComplicationView(entry: entry)
        }
    }
}

#Preview(as: .accessoryCircular) {
    VoiceNoteWidget()
} timeline: {
    VoiceNoteEntry(date: Date())
}
