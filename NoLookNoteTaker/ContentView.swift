import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NotesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isAuthenticated {
                    signInView
                } else if viewModel.isLoading {
                    ProgressView("Loading notes...")
                } else if viewModel.notes.isEmpty {
                    emptyStateView
                } else {
                    notesListView
                }
            }
            .navigationTitle("Voice Notes")
        }
        .task {
            if !viewModel.isAuthenticated {
                await viewModel.signInAnonymously()
            }
        }
    }

    private var signInView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Signing in...")
                .foregroundColor(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("No Notes Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Record a voice note on your Apple Watch to get started.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }

    private var notesListView: some View {
        List {
            ForEach(viewModel.notes) { note in
                NavigationLink(destination: NoteDetailView(note: note)) {
                    NoteRowView(note: note)
                }
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await viewModel.deleteNote(viewModel.notes[index])
                    }
                }
            }
        }
        .refreshable {
            // Firestore listener auto-refreshes, but this provides feedback
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
}

struct NoteRowView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: note.statusIcon)
                    .foregroundColor(colorForStatus(note.statusColor))

                Text(note.displayDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if note.status != "complete" {
                    Text(note.status.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(colorForStatus(note.statusColor).opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if let summary = note.summary, !summary.isEmpty {
                Text(summary)
                    .lineLimit(3)
                    .font(.body)
            } else if let transcription = note.transcription, !transcription.isEmpty {
                Text(transcription)
                    .lineLimit(3)
                    .font(.body)
                    .foregroundColor(.secondary)
            } else if note.status == "error" {
                Text(note.error ?? "Transcription failed")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text(note.status == "summarizing" ? "Generating summary..." : "Transcription in progress...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }

    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "green": return .green
        case "red": return .red
        default: return .orange
        }
    }
}

struct NoteDetailView: View {
    let note: Note
    @State private var showFullTranscription = false
    @State private var showAudioPlayer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status header
                HStack {
                    Image(systemName: note.statusIcon)
                    Text(note.status.capitalized)
                    Spacer()
                    Text(note.displayDate)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)

                Divider()

                // Summary (primary content)
                if let summary = note.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.body)
                        .textSelection(.enabled)
                } else if let transcription = note.transcription, !transcription.isEmpty {
                    // Show transcription if no summary yet
                    Text(transcription)
                        .font(.body)
                        .textSelection(.enabled)
                        .foregroundColor(.secondary)
                } else if note.status == "error" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription Failed")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(note.error ?? "Unknown error")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text(note.status == "summarizing" ? "Generating summary..." : "Transcribing...")
                            .foregroundColor(.secondary)
                    }
                }

                // Expandable sections
                if note.status == "complete" {
                    Divider()
                        .padding(.top, 8)

                    // Full Transcription section
                    if let transcription = note.transcription, !transcription.isEmpty {
                        DisclosureGroup("Full Transcription", isExpanded: $showFullTranscription) {
                            Text(transcription)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .padding(.top, 8)
                        }
                        .tint(.primary)
                    }

                    // Audio section
                    if note.audioPath != nil {
                        DisclosureGroup("Audio Recording", isExpanded: $showAudioPlayer) {
                            AudioPlayerView(audioPath: note.audioPath)
                                .padding(.top, 8)
                        }
                        .tint(.primary)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AudioPlayerView: View {
    let audioPath: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading audio...")
                        .foregroundColor(.secondary)
                }
            } else if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                    Text("Audio available")
                        .foregroundColor(.secondary)
                    Spacer()
                    // TODO: Add actual audio playback controls
                    Button(action: {}) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                    }
                    .disabled(true) // Placeholder for now
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
