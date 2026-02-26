//
//  NetworkMonitor.swift
//  Pal Field
//
//  Lightweight NWPathMonitor wrapper.
//  Publishes connectivity changes for ConvexSyncManager.
//

import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected: Bool = false
    @Published var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi, cellular, wiredEthernet, unknown
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.palfield.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .wiredEthernet
                } else {
                    self.connectionType = .unknown
                }

                // Trigger sync when connectivity is restored
                if !wasConnected && self.isConnected {
                    NotificationCenter.default.post(name: .networkConnectivityRestored, object: nil)
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

extension Notification.Name {
    static let networkConnectivityRestored = Notification.Name("networkConnectivityRestored")
}
