import Foundation
import FirebaseFirestore

struct Note: Identifiable, Codable {
    @DocumentID var id: String?
    var transcription: String?
    var summary: String?
    var category: String?  // "pain", "activity", or "other"
    var painIntensity: Int?  // 1-5 scale
    var screenType: String?  // "phone", "computer", "tv", or "other"
    var activityDurationMinutes: Int?
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
        case "summarizing", "analyzing": return "sparkles"
        case "complete": return "checkmark.circle.fill"
        case "error": return "exclamationmark.triangle.fill"
        default: return "questionmark.circle"
        }
    }

    var categoryIcon: String {
        switch category {
        case "pain": return "bolt.fill"
        case "activity": return screenTypeIcon
        default: return "doc.text"
        }
    }

    var screenTypeIcon: String {
        switch screenType {
        case "phone": return "iphone"
        case "computer": return "laptopcomputer"
        case "tv": return "tv"
        default: return "display"
        }
    }

    var categoryColor: String {
        switch category {
        case "pain": return "red"
        case "activity": return "blue"
        default: return "gray"
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
