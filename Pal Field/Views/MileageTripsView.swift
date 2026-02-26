//
//  MileageTripsView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData

struct MileageTripsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MileageTrip.startDate, order: .reverse) private var allTrips: [MileageTrip]

    // Filter by current user (empty ownerEmail = legacy data, treat as current user's)
    private var currentUserEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }

    private var trips: [MileageTrip] {
        allTrips.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    @State private var startDate: Date = {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }()
    @State private var endDate = Date()
    @State private var showingDeleteAlert = false
    @State private var tripToDelete: MileageTrip?
    @State private var showingAddTrip = false

    var filteredTrips: [MileageTrip] {
        trips.filter { trip in
            trip.startDate >= startDate && trip.startDate <= endDate && !trip.isActive
        }
    }

    var totalMiles: Double {
        filteredTrips.reduce(0) { $0 + $1.miles }
    }

    var totalDeduction: Double {
        totalMiles * 0.67 // 2025 IRS mileage rate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Miles")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(totalMiles, specifier: "%.1f") mi")
                                .font(.title.bold())
                                .foregroundStyle(.blue)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Tax Deduction")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("$\(totalDeduction, specifier: "%.2f")")
                                .font(.title.bold())
                                .foregroundStyle(.green)
                        }
                    }

                    HStack {
                        Text("\(filteredTrips.count) trips")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("@ $0.67/mi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding()

                // Date filter
                HStack {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                    Text("to")
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }
                .font(.caption)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Trip list
                if filteredTrips.isEmpty {
                    ContentUnavailableView(
                        "No Trips",
                        systemImage: "car",
                        description: Text("Start tracking trips to log mileage for tax deductions")
                    )
                } else {
                    List {
                        ForEach(filteredTrips) { trip in
                            TripRow(trip: trip)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        tripToDelete = trip
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Mileage Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                AddMileageTripView()
            }
            .alert("Delete Trip?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let trip = tripToDelete {
                        deleteTrip(trip)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let trip = tripToDelete {
                    Text("Are you sure you want to delete this \(trip.miles, specifier: "%.1f") mile trip?")
                }
            }
        }
    }

    private func deleteTrip(_ trip: MileageTrip) {
        modelContext.delete(trip)
        try? modelContext.save()
    }
}

struct TripRow: View {
    let trip: MileageTrip

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(Color.blue)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(trip.miles, specifier: "%.1f") miles")
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(trip.startDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let end = trip.endDate {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(trip.startDate, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("-")
                            .foregroundStyle(.secondary)
                        Text(end, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !trip.notes.isEmpty {
                    Text(trip.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(trip.miles * 0.67, specifier: "%.2f")")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                Text("deduction")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
