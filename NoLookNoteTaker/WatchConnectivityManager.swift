import Foundation
import WatchConnectivity
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit
import BackgroundTasks

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    private var session: WCSession?
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    private func beginBackgroundTask() {
        // End any existing background task
        endBackgroundTask()

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "WatchConnectivityUpload") { [weak self] in
            print("Background task expired")
            self?.endBackgroundTask()
        }
        print("Started background task: \(backgroundTask)")
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            print("Ending background task: \(backgroundTask)")
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    private func uploadRecording(data: Data, filename: String) {
        // Start background task to ensure upload completes
        beginBackgroundTask()

        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user, signing in...")
            Task {
                do {
                    try await Auth.auth().signInAnonymously()
                    self.uploadRecording(data: data, filename: filename)
                } catch {
                    print("Auth error: \(error)")
                    self.endBackgroundTask()
                }
            }
            return
        }

        let noteId = UUID().uuidString
        let storagePath = "recordings/\(userId)/\(noteId).m4a"

        print("Uploading recording: \(noteId)")

        // Upload to Firebase Storage
        let storageRef = storage.reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"

        storageRef.putData(data, metadata: metadata) { [weak self] _, error in
            if let error = error {
                print("Storage upload error: \(error)")
                self?.endBackgroundTask()
                return
            }

            // Create Firestore document
            self?.db.collection("users").document(userId).collection("notes").document(noteId).setData([
                "status": "uploaded",
                "audioPath": storagePath,
                "createdAt": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("Firestore error: \(error)")
                } else {
                    print("Successfully uploaded note: \(noteId)")
                }
                self?.endBackgroundTask()
            }
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation error: \(error)")
        } else {
            print("WCSession activated: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        session.activate()
    }

    // Receive message data (for immediate transfers)
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        print("Received message data: \(messageData.count) bytes")
        uploadRecording(data: messageData, filename: "recording.m4a")
        replyHandler(Data())
    }

    // Receive file transfers (for background transfers)
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("Received file: \(file.fileURL)")

        do {
            let data = try Data(contentsOf: file.fileURL)
            let filename = file.metadata?["filename"] as? String ?? "recording.m4a"
            uploadRecording(data: data, filename: filename)
        } catch {
            print("Error reading file: \(error)")
        }
    }
}
