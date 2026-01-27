//
//  NetworkMonitor.swift
//  FinancialAnalyzer
//
//  Monitors network connectivity for offline mode handling
//

import Foundation
import Network
import Combine

/// Network connectivity monitor using NWPathMonitor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.financialanalyzer.networkmonitor")

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown

                if path.status == .satisfied {
                    print("🌐 [Network] Connected via \(self?.connectionType ?? .unknown)")
                } else {
                    print("📴 [Network] Disconnected")
                }
            }
        }

        monitor.start(queue: queue)
        print("🌐 [Network] Started monitoring")
    }

    private func stopMonitoring() {
        monitor.cancel()
        print("🌐 [Network] Stopped monitoring")
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .unknown
    }
}
