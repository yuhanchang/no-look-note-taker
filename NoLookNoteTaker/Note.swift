import Foundation
import FirebaseFirestore

struct Note: Identifiable, Codable {
    @DocumentID var id: String?
    var transcription: String?
    var summary: String?
    var status: String
    var audioPath: String?
    var createdAt: Date?
    var updatedAt: Date?
    var error: String?

    var displayDate: String {
        guard let date = createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var statusIcon: String {
        switch status {
        case "recording": return "mic.fill"
        case "uploading", "uploaded": return "arrow.up.circle"
        case "transcribing": return "text.bubble"
        case "summarizing": return "sparkles"
        case "complete": return "checkmark.circle.fill"
        case "error": return "exclamationmark.triangle.fill"
        default: return "questionmark.circle"
        }
    }

    var statusColor: String {
        switch status {
        case "complete": return "green"
        case "error": return "red"
        default: return "orange"
        }
    }
}
