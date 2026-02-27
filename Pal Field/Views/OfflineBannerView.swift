//
//  OfflineBannerView.swift
//  Pal Field
//
//  Displays a subtle connectivity banner using NWPathMonitor.
//

import SwiftUI
import Combine

struct OfflineBannerView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var showReconnected = false
    @State private var previouslyOffline = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                    Text("No Signal — Working Offline")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.9))
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if showReconnected {
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .font(.caption2)
                    Text("Back Online — Syncing")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.85))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .animation(.easeInOut(duration: 0.3), value: showReconnected)
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            if !isConnected {
                previouslyOffline = true
                showReconnected = false
            } else if previouslyOffline {
                previouslyOffline = false
                showReconnected = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showReconnected = false
                }
            }
        }
    }
}
