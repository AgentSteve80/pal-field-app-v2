//
//  TripTrackingWatchView.swift
//  Pal Field Watch
//
//  Active trip view showing miles and time
//

import SwiftUI

struct TripTrackingWatchView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @State private var showingStopConfirmation = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(brandGreen)
                    .frame(width: 8, height: 8)
                Text("Tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Miles display
            VStack(spacing: 2) {
                Text(String(format: "%.1f", sessionManager.currentMiles))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(brandGreen)
                Text("miles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Duration
            Text(formatDuration(sessionManager.elapsedTime))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            // Stop button
            Button {
                showingStopConfirmation = true
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .confirmationDialog("End Trip", isPresented: $showingStopConfirmation) {
            Button("Save Trip", role: .none) {
                sessionManager.stopTrip { miles in
                    if let miles = miles {
                        print("Trip saved: \(miles) miles")
                    }
                }
            }
            Button("Discard", role: .destructive) {
                sessionManager.cancelTrip()
            }
            Button("Continue Tracking", role: .cancel) { }
        } message: {
            Text("What would you like to do with this trip?")
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    TripTrackingWatchView()
        .environmentObject({
            let manager = WatchSessionManager()
            return manager
        }())
}
