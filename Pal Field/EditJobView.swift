//
//  EditJobView.swift
//  Pal Low Voltage Pro
//
//  Created by Andrew Stewart on 11/13/25.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import WidgetKit

struct EditJobView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings

    let job: Job

    @State private var jobNumber: String
    @State private var jobDate: Date
    @State private var lotNumber: String
    @State private var address: String
    @State private var subdivision: String
    @State private var prospect: String
    @State private var wireRuns: Int
    @State private var enclosure: Int
    @State private var flatPanelStud: Int
    @State private var flatPanelWall: Int
    @State private var flatPanelRemote: Int
    @State private var flexTube: Int
    @State private var mediaBox: Int
    @State private var dryRun: Int
    @State private var serviceRun: Int
    @State private var miles: Double
    private let originalMiles: Double  // Track original miles to detect new mileage
    @State private var calculatingMiles = false
    @State private var showGeocodeQuery = false
    @State private var geocodeQuery: String
    @State private var showDeleteAlert = false
    @State private var showingCloseout = false
    @State private var voiceNotePath: String?
    @State private var jobNotes: String

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

    init(job: Job) {
        self.job = job
        self.originalMiles = job.miles  // Store original miles
        _jobNumber = State(initialValue: job.jobNumber)
        _jobDate = State(initialValue: job.jobDate)
        _lotNumber = State(initialValue: job.lotNumber)
        _address = State(initialValue: job.address)
        _subdivision = State(initialValue: job.subdivision)
        _prospect = State(initialValue: job.prospect)
        _wireRuns = State(initialValue: job.wireRuns)
        _enclosure = State(initialValue: job.enclosure)
        _flatPanelStud = State(initialValue: job.flatPanelStud)
        _flatPanelWall = State(initialValue: job.flatPanelWall)
        _flatPanelRemote = State(initialValue: job.flatPanelRemote)
        _flexTube = State(initialValue: job.flexTube)
        _mediaBox = State(initialValue: job.mediaBox)
        _dryRun = State(initialValue: job.dryRun)
        _serviceRun = State(initialValue: job.serviceRun)
        _miles = State(initialValue: job.miles)
        _geocodeQuery = State(initialValue: job.address + " subdivision, north Indianapolis, IN")
        _voiceNotePath = State(initialValue: job.voiceNotePath)
        _jobNotes = State(initialValue: job.superNotes)
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

                Section("Voice Note") {
                    VoiceNoteView(voiceNotePath: $voiceNotePath, notes: $jobNotes)
                    if !jobNotes.isEmpty {
                        Text(jobNotes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            .navigationTitle("Edit Job")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCloseout = true
                    } label: {
                        Label("Closeout", systemImage: "checkmark.circle.fill")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        job.jobNumber = jobNumber
                        job.jobDate = jobDate
                        job.lotNumber = lotNumber
                        job.address = address
                        job.subdivision = subdivision
                        job.prospect = prospect
                        job.wireRuns = wireRuns
                        job.enclosure = enclosure
                        job.flatPanelStud = flatPanelStud
                        job.flatPanelWall = flatPanelWall
                        job.flatPanelRemote = flatPanelRemote
                        job.flexTube = flexTube
                        job.mediaBox = mediaBox
                        job.dryRun = dryRun
                        job.serviceRun = serviceRun
                        job.miles = miles
                        job.payTierValue = settings.payTier.rawValue
                        job.voiceNotePath = voiceNotePath
                        job.superNotes = jobNotes

                        // If miles were added (from 0 or increased), create a MileageTrip
                        if miles > originalMiles && originalMiles == 0 {
                            // New mileage added where there was none
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
                            HapticManager.success()
                            // Notify that job data changed (for widget cache update)
                            NotificationCenter.default.post(name: .jobDataDidChange, object: nil)
                            // Small delay to ensure SwiftData processes the save
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        } catch {
                            HapticManager.error()
                            print("Failed to save job: \(error)")
                        }
                    }
                    .disabled(lotNumber.isEmpty)
                }
            }
            .alert("Delete Job", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteJob()
                }
            } message: {
                Text("Are you sure you want to delete job #\(jobNumber)? This action cannot be undone.")
            }
            .onChange(of: address) { _, newValue in
                geocodeQuery = newValue + " subdivision, north Indianapolis, IN"
            }
            .sheet(isPresented: $showingCloseout) {
                CloseoutView(job: job)
            }
        }
    }

    private func deleteJob() {
        HapticManager.warning()
        modelContext.delete(job)
        dismiss()
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

            let distanceMiles = route.distance / 1609.34  // One-way
            miles = round(distanceMiles * 100) / 100
            showGeocodeQuery = false
        } catch {
            print("Miles calculation error: \(error.localizedDescription)")
            showGeocodeQuery = true
        }
    }
}
