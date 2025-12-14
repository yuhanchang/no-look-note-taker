import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Status icon
            if appState.isSending {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Sending to iPhone...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if appState.lastSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                Text("Sent!")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                // Microphone icon - changes when recording
                Image(systemName: appState.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 50))
                    .foregroundColor(appState.isRecording ? .red : .white)
                    .symbolEffect(.pulse, isActive: appState.isRecording)

                // Timer display
                Text(formatTime(appState.recordingTime))
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(appState.isRecording ? .red : .secondary)
            }

            Spacer()

            // Error display
            if let error = appState.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }

            // Record/Stop button
            Button(action: {
                appState.toggleRecording()
            }) {
                HStack {
                    Image(systemName: appState.isRecording ? "stop.fill" : "record.circle")
                    Text(appState.isRecording ? "Stop" : "Record")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(appState.isRecording ? .red : .blue)
            .disabled(appState.isSending)
        }
        .padding()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
}
