import AppIntents

struct ToggleRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Voice Recording"
    static let description = IntentDescription("Start or stop voice note recording")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppState.shared.toggleRecording()
        return .result()
    }
}

struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Voice Recording"
    static let description = IntentDescription("Start recording a new voice note")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if !AppState.shared.isRecording {
            AppState.shared.startRecording()
        }
        return .result()
    }
}

struct StopRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Voice Recording"
    static let description = IntentDescription("Stop the current voice note recording")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if AppState.shared.isRecording {
            AppState.shared.stopRecording()
        }
        return .result()
    }
}
