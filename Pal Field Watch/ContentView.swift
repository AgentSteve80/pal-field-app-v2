//
//  ContentView.swift
//  Pal Field Watch
//
//  Main watch view - shows start button or active trip
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.isTracking {
                    TripTrackingWatchView()
                } else {
                    startTripView
                }
            }
            .navigationTitle("Pal Field")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            sessionManager.requestStatus()
        }
    }

    private var startTripView: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.fill")
                .font(.system(size: 44))
                .foregroundStyle(brandGreen)

            Text("Track Mileage")
                .font(.headline)

            if !sessionManager.isPhoneReachable {
                HStack {
                    Image(systemName: "iphone.slash")
                        .foregroundStyle(.orange)
                    Text("iPhone required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                sessionManager.startTrip()
            } label: {
                Label("Start Trip", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(brandGreen)
            .disabled(!sessionManager.isPhoneReachable)

            if let error = sessionManager.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSessionManager())
}
