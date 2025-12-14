import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = true
    @Published var error: String?
    @Published var isAuthenticated = false

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                if let userId = user?.uid {
                    self?.startListening(userId: userId)
                } else {
                    self?.notes = []
                    self?.listener?.remove()
                }
            }
        }
    }

    deinit {
        listener?.remove()
        if let authListener = authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    func signInAnonymously() async {
        do {
            try await Auth.auth().signInAnonymously()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startListening(userId: String) {
        listener?.remove()

        listener = db.collection("users")
            .document(userId)
            .collection("notes")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.isLoading = false

                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }

                    self?.notes = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: Note.self)
                    } ?? []
                }
            }
    }

    func deleteNote(_ note: Note) async {
        guard let noteId = note.id,
              let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users")
                .document(userId)
                .collection("notes")
                .document(noteId)
                .delete()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
