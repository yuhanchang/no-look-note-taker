import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var transferProgress: Double = 0
    @Published var lastError: String?

    private var session: WCSession?
    private var pendingTransfers: [WCSessionFileTransfer: (Bool, String?) -> Void] = [:]
    private var pendingFileURLs: [WCSessionFileTransfer: URL] = [:]

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendRecording(fileURL: URL, completion: @escaping (Bool, String?) -> Void) {
        guard let session = session else {
            completion(false, "WatchConnectivity not available")
            return
        }

        guard session.activationState == .activated else {
            completion(false, "WatchConnectivity not activated yet")
            return
        }

        // Always use file transfer - more reliable than sendMessageData
        let metadata: [String: Any] = [
            "filename": fileURL.lastPathComponent,
            "timestamp": Date().timeIntervalSince1970
        ]

        let transfer = session.transferFile(fileURL, metadata: metadata)

        // Track this transfer so we know when it completes
        pendingTransfers[transfer] = completion
        pendingFileURLs[transfer] = fileURL

        print("Started file transfer: \(fileURL.lastPathComponent)")
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.lastError = error.localizedDescription
            }
            self.isReachable = session.isReachable
            print("WCSession activated: \(activationState.rawValue), reachable: \(session.isReachable)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("Reachability changed: \(session.isReachable)")
        }
    }

    // Called when a file transfer completes successfully
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            let completion = self.pendingTransfers.removeValue(forKey: fileTransfer)
            let fileURL = self.pendingFileURLs.removeValue(forKey: fileTransfer)

            if let error = error {
                print("File transfer failed: \(error.localizedDescription)")
                completion?(false, error.localizedDescription)
            } else {
                print("File transfer completed successfully")
                // Only delete local file after successful transfer
                if let url = fileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                completion?(true, nil)
            }
        }
    }
}
