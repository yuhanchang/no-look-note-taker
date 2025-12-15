import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import Combine

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = true
    @Published var error: String?
    @Published var isAuthenticated = false
    @Published var userEmail: String?

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                self?.userEmail = user?.email
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

    func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            self.error = "Unable to get root view controller"
            return
        }

        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
                guard let idToken = result.user.idToken?.tokenString else {
                    self.error = "Unable to get ID token"
                    return
                }

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )

                try await Auth.auth().signIn(with: credential)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
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
