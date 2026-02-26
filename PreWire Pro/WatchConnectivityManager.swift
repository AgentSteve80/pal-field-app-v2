//
//  WatchConnectivityManager.swift
//  PreWire Pro
//
//  Manages communication between iPhone and Apple Watch
//

import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var isWatchAppInstalled = false

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    /// Send trip status update to watch
    func sendTripUpdate(isTracking: Bool, miles: Double, elapsedTime: TimeInterval) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "type": "tripUpdate",
            "isTracking": isTracking,
            "miles": miles,
            "elapsedTime": elapsedTime
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send trip update to watch: \(error.localizedDescription)")
        }
    }

    /// Send trip started notification to watch
    func notifyTripStarted() {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "type": "tripStarted"
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send trip started to watch: \(error.localizedDescription)")
        }
    }

    /// Send trip stopped notification to watch
    func notifyTripStopped(miles: Double) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "type": "tripStopped",
            "finalMiles": miles
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send trip stopped to watch: \(error.localizedDescription)")
        }
    }

    /// Update application context (persisted state for watch)
    func updateApplicationContext(isTracking: Bool, miles: Double, elapsedTime: TimeInterval) {
        guard let session = session else { return }

        let context: [String: Any] = [
            "isTracking": isTracking,
            "miles": miles,
            "elapsedTime": elapsedTime,
            "lastUpdate": Date().timeIntervalSince1970
        ]

        do {
            try session.updateApplicationContext(context)
        } catch {
            print("Failed to update application context: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }

        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // Reactivate for new paired watch
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleMessage(message, replyHandler: replyHandler)
    }

    private func handleMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let type = message["type"] as? String else { return }

        DispatchQueue.main.async {
            switch type {
            case "startTrip":
                Task { @MainActor in
                    TripTrackingManager.shared.startTrip()
                    replyHandler?(["success": true])
                }

            case "stopTrip":
                Task { @MainActor in
                    if let trip = TripTrackingManager.shared.stopTrip() {
                        replyHandler?(["success": true, "miles": trip.miles])
                    } else {
                        replyHandler?(["success": false])
                    }
                }

            case "cancelTrip":
                Task { @MainActor in
                    TripTrackingManager.shared.cancelTrip()
                    replyHandler?(["success": true])
                }

            case "getStatus":
                Task { @MainActor in
                    let manager = TripTrackingManager.shared
                    replyHandler?([
                        "isTracking": manager.isTracking,
                        "miles": manager.totalMiles,
                        "elapsedTime": manager.elapsedTime
                    ])
                }

            default:
                print("Unknown message type: \(type)")
                replyHandler?(["error": "Unknown message type"])
            }
        }
    }
}
