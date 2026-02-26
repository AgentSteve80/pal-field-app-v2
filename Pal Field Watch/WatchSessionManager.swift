//
//  WatchSessionManager.swift
//  Pal Field Watch
//
//  Manages communication with iPhone from Watch
//

import Foundation
import WatchConnectivity
import Combine

class WatchSessionManager: NSObject, ObservableObject {
    @Published var isTracking = false
    @Published var currentMiles: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var isPhoneReachable = false
    @Published var lastError: String?

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    /// Request current status from iPhone
    func requestStatus() {
        guard let session = session, session.isReachable else {
            lastError = "iPhone not reachable"
            return
        }

        session.sendMessage(["type": "getStatus"], replyHandler: { [weak self] response in
            DispatchQueue.main.async {
                self?.isTracking = response["isTracking"] as? Bool ?? false
                self?.currentMiles = response["miles"] as? Double ?? 0
                self?.elapsedTime = response["elapsedTime"] as? TimeInterval ?? 0
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = error.localizedDescription
            }
        })
    }

    /// Start mileage tracking
    func startTrip() {
        guard let session = session, session.isReachable else {
            lastError = "iPhone not reachable"
            return
        }

        session.sendMessage(["type": "startTrip"], replyHandler: { [weak self] response in
            if response["success"] as? Bool == true {
                DispatchQueue.main.async {
                    self?.isTracking = true
                    self?.currentMiles = 0
                    self?.elapsedTime = 0
                }
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = error.localizedDescription
            }
        })
    }

    /// Stop mileage tracking and save
    func stopTrip(completion: @escaping (Double?) -> Void) {
        guard let session = session, session.isReachable else {
            lastError = "iPhone not reachable"
            completion(nil)
            return
        }

        session.sendMessage(["type": "stopTrip"], replyHandler: { [weak self] response in
            DispatchQueue.main.async {
                if response["success"] as? Bool == true {
                    self?.isTracking = false
                    let miles = response["miles"] as? Double
                    self?.currentMiles = 0
                    self?.elapsedTime = 0
                    completion(miles)
                } else {
                    completion(nil)
                }
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = error.localizedDescription
                completion(nil)
            }
        })
    }

    /// Cancel trip without saving
    func cancelTrip() {
        guard let session = session, session.isReachable else {
            lastError = "iPhone not reachable"
            return
        }

        session.sendMessage(["type": "cancelTrip"], replyHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.isTracking = false
                self?.currentMiles = 0
                self?.elapsedTime = 0
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = error.localizedDescription
            }
        })
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }

        if activationState == .activated {
            // Load any persisted context
            let context = session.receivedApplicationContext
            DispatchQueue.main.async {
                self.isTracking = context["isTracking"] as? Bool ?? false
                self.currentMiles = context["miles"] as? Double ?? 0
                self.elapsedTime = context["elapsedTime"] as? TimeInterval ?? 0
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            if session.isReachable {
                self.requestStatus()
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.isTracking = applicationContext["isTracking"] as? Bool ?? false
            self.currentMiles = applicationContext["miles"] as? Double ?? 0
            self.elapsedTime = applicationContext["elapsedTime"] as? TimeInterval ?? 0
        }
    }

    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        DispatchQueue.main.async {
            switch type {
            case "tripUpdate":
                self.isTracking = message["isTracking"] as? Bool ?? false
                self.currentMiles = message["miles"] as? Double ?? 0
                self.elapsedTime = message["elapsedTime"] as? TimeInterval ?? 0

            case "tripStarted":
                self.isTracking = true
                self.currentMiles = 0
                self.elapsedTime = 0

            case "tripStopped":
                self.isTracking = false
                self.currentMiles = message["finalMiles"] as? Double ?? 0

            default:
                break
            }
        }
    }
}
