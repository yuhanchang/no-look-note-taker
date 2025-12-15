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
            .toolbar {
                if viewModel.isAuthenticated {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if let email = viewModel.userEmail {
                                Text(email)
                            }
                            Button("Sign Out", role: .destructive) {
                                viewModel.signOut()
                            }
                        } label: {
                            Image(systemName: "person.circle")
                        }
                    }
                }
            }
        }
    }

    private var signInView: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Pain & Activity Tracker")
                .font(.title2)
                .fontWeight(.bold)

            Text("Sign in to sync your notes across devices")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button(action: {
                viewModel.signInWithGoogle()
            }) {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("Sign in with Google")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
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

            Section {
                Button(role: .destructive) {
                    viewModel.signOut()
                } label: {
                    HStack {
                        Text("Sign Out")
                        Spacer()
                        if let email = viewModel.userEmail {
                            Text(email)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
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

                if note.status == "complete", let category = note.category {
                    HStack(spacing: 4) {
                        Image(systemName: note.categoryIcon)
                        if category == "activity", let screenType = note.screenType {
                            Text(screenType.capitalized)
                        } else {
                            Text(category.capitalized)
                        }
                        if let duration = note.activityDurationMinutes {
                            Text("• \(duration)m")
                        }
                        if let pain = note.painIntensity {
                            Text("• \(pain)/5")
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(colorForStatus(note.categoryColor).opacity(0.2))
                    .cornerRadius(4)
                } else if note.status != "complete" {
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
        case "blue": return .blue
        case "gray": return .gray
        default: return .orange
        }
    }
}

struct NoteDetailView: View {
    let note: Note
    @State private var showFullTranscription = false
    @State private var showAudioPlayer = false

    private var shareContent: String {
        if let summary = note.summary, !summary.isEmpty {
            return summary
        } else if let transcription = note.transcription, !transcription.isEmpty {
            return transcription
        }
        return ""
    }

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
        .toolbar {
            if !shareContent.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareContent) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
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
