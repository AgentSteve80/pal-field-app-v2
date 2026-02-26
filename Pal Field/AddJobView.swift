//
//  AddJobView.swift
//  Pal Low Voltage Pro
//
//  Created by Andrew Stewart on 11/13/25.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import WidgetKit

struct AddJobView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings
    @Query(sort: \Job.jobDate, order: .reverse) private var allJobs: [Job]

    @State private var jobNumber = ""
    @State private var jobDate = Date()
    @State private var lotNumber = ""
    @State private var address = ""
    @State private var subdivision = ""
    @State private var prospect = ""
    @State private var wireRuns = 0
    @State private var enclosure = 0
    @State private var flatPanelStud = 0
    @State private var flatPanelWall = 0
    @State private var flatPanelRemote = 0
    @State private var flexTube = 0
    @State private var mediaBox = 0
    @State private var dryRun = 0
    @State private var serviceRun = 0
    @State private var miles = 0.0
    @State private var calculatingMiles = false
    @State private var showGeocodeQuery = false
    @State private var geocodeQuery = ""

    var nextJobNumber: String {
        Job.generateNextJobNumber(existingJobs: allJobs)
    }

    var liveTotal: Double {
        let tempJob = Job(
            wireRuns: wireRuns,
            enclosure: enclosure,
            flatPanelStud: flatPanelStud,
            flatPanelWall: flatPanelWall,
            flatPanelRemote: flatPanelRemote,
            flexTube: flexTube,
            mediaBox: mediaBox,
            dryRun: dryRun,
            serviceRun: serviceRun,
            miles: miles,
            payTierValue: settings.payTier.rawValue
        )
        return tempJob.total(settings: settings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    HStack {
                        Text("Job #")
                        Spacer()
                        TextField("JB001", text: $jobNumber)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("Job Date", selection: $jobDate, displayedComponents: .date)
                    HStack {
                        Text("Lot #")
                        Spacer()
                        TextField("123", text: $lotNumber)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Address")
                        Spacer()
                        TextField("123 Main St", text: $address)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Subdivision")
                        Spacer()
                        TextField("Courtyards Russell", text: $subdivision)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Prospect #")
                        Spacer()
                        TextField("52260357", text: $prospect)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Pricing Items (Tier \(settings.payTier.rawValue))") {
                    Stepper("Wire Runs (\(settings.priceForWireRun(), specifier: "$%.0f") ea): \(wireRuns)", value: $wireRuns, in: 0...50)
                    Stepper("Enclosure (\(settings.priceForEnclosure(), specifier: "$%.0f") ea): \(enclosure)", value: $enclosure, in: 0...10)
                    Stepper("Flex Tube (\(settings.priceForFlexTube(), specifier: "$%.0f") ea): \(flexTube)", value: $flexTube, in: 0...5)
                    Stepper("Flat Panel Same Stud (\(settings.priceForFlatPanelStud(), specifier: "$%.0f") ea): \(flatPanelStud)", value: $flatPanelStud, in: 0...10)
                    Stepper("Flat Panel Same Wall (\(settings.priceForFlatPanelWall(), specifier: "$%.0f") ea): \(flatPanelWall)", value: $flatPanelWall, in: 0...10)
                    Stepper("Remote (\(settings.priceForFlatPanelRemote(), specifier: "$%.0f") ea): \(flatPanelRemote)", value: $flatPanelRemote, in: 0...10)
                    Stepper("Media Box (\(settings.priceForMediaBox(), specifier: "$%.0f") ea): \(mediaBox)", value: $mediaBox, in: 0...5)
                    Stepper("Dry Run (\(settings.priceForDryRun(), specifier: "$%.0f")): \(dryRun)", value: $dryRun, in: 0...3)
                    Stepper("Service Run 30min (\(settings.priceForServiceRun(), specifier: "$%.0f")): \(serviceRun)", value: $serviceRun, in: 0...10)
                }

                Section("Mileage (For Tax Purposes)") {
                    HStack {
                        Text("Miles (one-way):")
                        Spacer()
                        Text("\(miles, specifier: "%.1f")")
                            .foregroundStyle(.secondary)
                    }
                    if showGeocodeQuery {
                        Text("Could not locate address. Refine the search query below:")
                            .foregroundStyle(.red)
                            .font(.caption)
                        TextField("Geocode Search Query", text: $geocodeQuery)
                    }
                    Button("Calculate from Address") {
                        calculatingMiles = true
                        Task {
                            await calculateMiles()
                            calculatingMiles = false
                        }
                    }
                    .disabled(calculatingMiles || address.isEmpty)
                    if calculatingMiles {
                        ProgressView("Calculating...")
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("JOB TOTAL")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("$\(liveTotal, specifier: "%.2f")")
                                .font(.title.bold())
                                .foregroundStyle(.green)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Add Job")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let newJob = Job(
                            jobNumber: jobNumber,
                            jobDate: jobDate,
                            lotNumber: lotNumber,
                            address: address,
                            subdivision: subdivision,
                            prospect: prospect,
                            wireRuns: wireRuns,
                            enclosure: enclosure,
                            flatPanelStud: flatPanelStud,
                            flatPanelWall: flatPanelWall,
                            flatPanelRemote: flatPanelRemote,
                            flexTube: flexTube,
                            mediaBox: mediaBox,
                            dryRun: dryRun,
                            serviceRun: serviceRun,
                            miles: miles,
                            payTierValue: settings.payTier.rawValue
                        )

                        // Set owner info from current user
                        newJob.ownerEmail = GmailAuthManager.shared.userEmail
                        newJob.ownerName = settings.workerName

                        modelContext.insert(newJob)

                        // If miles were entered, also create a MileageTrip for tax records
                        if miles > 0 {
                            let mileageTrip = MileageTrip(
                                startDate: jobDate,
                                endDate: jobDate,
                                miles: miles,
                                purpose: "Work",
                                notes: "Job \(jobNumber) - \(address)",
                                ownerEmail: GmailAuthManager.shared.userEmail,
                                ownerName: settings.workerName
                            )
                            modelContext.insert(mileageTrip)
                            print("📍 Mileage trip created: \(miles) miles for Job \(jobNumber)")
                        }

                        // Ensure changes are processed and saved
                        do {
                            try modelContext.save()
                            // Notify that job data changed (for widget cache update)
                            NotificationCenter.default.post(name: .jobDataDidChange, object: nil)
                            // Small delay to ensure SwiftData processes the save
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        } catch {
                            print("Failed to save job: \(error)")
                        }
                    }
                    .disabled(jobNumber.isEmpty || lotNumber.isEmpty || address.isEmpty)
                }
            }
            .onChange(of: address) { _, newValue in
                geocodeQuery = newValue + " subdivision, north Indianapolis, IN"
            }
            .onAppear {
                // Set job number every time view appears
                jobNumber = nextJobNumber
            }
        }
    }

    private func calculateMiles() async {
        let home = settings.homeAddress
        let destination = geocodeQuery

        func mapItem(for address: String) async throws -> MKMapItem? {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = address
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return response.mapItems.first
        }

        do {
            guard let homeMapItem = try await mapItem(for: home) else { return }
            guard let destMapItem = try await mapItem(for: destination) else { throw NSError(domain: "Geocode", code: 1) }

            let request = MKDirections.Request()
            request.source = homeMapItem
            request.destination = destMapItem
            request.transportType = .automobile

            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            guard let route = response.routes.first else { return }

            let distanceMiles = route.distance / 1609.34  // One-way in miles
            miles = round(distanceMiles * 100) / 100  // 2 decimal places
            showGeocodeQuery = false
        } catch {
            print("Miles calculation error: \(error.localizedDescription)")
            showGeocodeQuery = true
        }
    }
}
