import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var isSending = false
    @Published var lastError: String?
    @Published var lastSuccess: Bool = false

    private let recorder = AudioRecorderManager()
    private let connectivity = WatchConnectivityManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Observe recorder state
        recorder.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)

        recorder.$recordingTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingTime)
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        lastError = nil
        lastSuccess = false
        recorder.startRecording()
    }

    func stopRecording() {
        if let url = recorder.stopRecording() {
            sendToPhone(url: url)
        }
    }

    private func sendToPhone(url: URL) {
        isSending = true

        connectivity.sendRecording(fileURL: url) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isSending = false

                if success {
                    self?.lastSuccess = true
                    print("Recording transferred to iPhone")
                } else {
                    self?.lastError = error ?? "Failed to send"
                    print("Send error: \(error ?? "unknown")")
                }
            }
        }
    }
}
