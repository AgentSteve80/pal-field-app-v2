//
//  TripTrackingView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData

struct TripTrackingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var tripManager: TripTrackingManager

    @State private var notes: String = ""
    @State private var showingSaveAlert = false
    @State private var isSaving = false
    @State private var isDismissing = false

    var tripDuration: String {
        let elapsed = tripManager.elapsedTime
        let hours = Int(elapsed) / 3600
        let minutes = Int(elapsed) / 60 % 60
        let seconds = Int(elapsed) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            if !tripManager.isTracking && tripManager.currentTrip == nil && !isSaving && !isDismissing {
                // Starting trip view
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Starting trip...")
                        .font(.headline)
                    Text("Make sure Location is set to 'Always' in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    // Only start if not already tracking and not dismissing
                    if !tripManager.isTracking && !isDismissing {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Double-check we're not dismissing before starting
                            if !isDismissing {
                                tripManager.startTrip()
                            }
                        }
                    }
                }
            } else if isSaving {
                // Saving view
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Saving trip...")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 24) {
                    // Trip icon with pulse animation
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 120, height: 120)

                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                    }
                    .padding(.top, 30)

                    // Trip in progress
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            Text("Trip in Progress")
                                .font(.title2.bold())
                        }

                        Text("Started \(tripManager.currentTrip?.startDate ?? Date(), style: .time)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Stats
                    VStack(spacing: 20) {
                        HStack(spacing: 30) {
                            VStack(spacing: 4) {
                                Text("\(String(format: "%.1f", tripManager.totalMiles))")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundStyle(.blue)
                                    .contentTransition(.numericText())
                                Text("Miles")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 60)

                            VStack(spacing: 4) {
                                Text(tripDuration)
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundStyle(.green)
                                    .contentTransition(.numericText())
                                Text("Duration")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)

                        // Tax deduction estimate
                        HStack {
                            Text("Est. Tax Deduction")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("$\(tripManager.totalMiles * 0.67, specifier: "%.2f")")
                                .font(.title3.bold())
                                .foregroundStyle(.orange)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Notes field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trip Notes (Optional)")
                            .font(.headline)
                        TextField("Add notes about this trip...", text: $notes, axis: .vertical)
                            .lineLimit(3...5)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    // Stop button
                    Button {
                        showingSaveAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop Trip")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .alert("End Trip?", isPresented: $showingSaveAlert) {
                    Button("Save Trip") {
                        saveTrip()
                    }
                    Button("Discard", role: .destructive) {
                        discardTrip()
                    }
                    Button("Keep Tracking", role: .cancel) { }
                } message: {
                    Text("You traveled \(String(format: "%.1f", tripManager.totalMiles)) miles.\n\nSave: Record trip for tax deductions\nDiscard: Stop tracking without saving")
                }
            }
        }
        .navigationTitle("Trip Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    discardTrip()
                }
            }
        }
        .interactiveDismissDisabled(tripManager.isTracking)
    }

    private func saveTrip() {
        isSaving = true

        guard let trip = tripManager.stopTrip() else {
            isSaving = false
            dismiss()
            return
        }

        // Add notes if provided
        trip.notes = notes

        // Save to database
        modelContext.insert(trip)
        try? modelContext.save()

        print("✅ Trip saved: \(trip.miles) miles")

        // Dismiss after a brief delay to show saving state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }

    private func discardTrip() {
        // Set flag FIRST to prevent auto-restart
        isDismissing = true
        // Cancel the trip
        tripManager.cancelTrip()
        // Dismiss
        dismiss()
    }
}
