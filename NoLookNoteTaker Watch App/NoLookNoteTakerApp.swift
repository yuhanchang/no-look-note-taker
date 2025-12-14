import SwiftUI

@main
struct NoLookNoteTakerApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    if url.scheme == "nolooknotetaker" && url.host == "record" {
                        if !appState.isRecording && !appState.isSending {
                            appState.startRecording()
                        }
                    }
                }
        }
    }
}
