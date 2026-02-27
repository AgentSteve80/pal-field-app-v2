//
//  JobRouteMapView.swift
//  Pal Field
//
//  Smart job routing — shows today's jobs on a map with optimal drive order.
//
//  INFO.PLIST ENTRIES NEEDED:
//  - NSLocationWhenInUseUsageDescription: "Pal Field uses your location to calculate optimal job routes."
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - Job Map Annotation

struct JobAnnotation: Identifiable {
    let id: UUID
    let job: Job
    let coordinate: CLLocationCoordinate2D
    var routeOrder: Int = 0
}

// MARK: - Route Map View

struct JobRouteMapView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings
    @Query(sort: \Job.jobDate, order: .reverse) private var allJobs: [Job]

    @State private var annotations: [JobAnnotation] = []
    @State private var routePolylines: [MKPolyline] = []
    @State private var totalDriveTime: TimeInterval = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedAnnotation: JobAnnotation?

    private var todaysJobs: [Job] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let currentUserEmail = GmailAuthManager.shared.userEmail.lowercased()
        return allJobs.filter { job in
            let jobDay = calendar.startOfDay(for: job.jobDate)
            let isOwner = job.ownerEmail.isEmpty || job.ownerEmail.lowercased() == currentUserEmail
            return jobDay >= today && jobDay < tomorrow && isOwner
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    ForEach(annotations) { annotation in
                        Annotation(
                            "\(annotation.routeOrder). Lot \(annotation.job.lotNumber)",
                            coordinate: annotation.coordinate
                        ) {
                            Button {
                                selectedAnnotation = annotation
                            } label: {
                                VStack(spacing: 2) {
                                    ZStack {
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 32, height: 32)
                                        Text("\(annotation.routeOrder)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                    Text(annotation.job.subdivision.prefix(12))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }

                // Drive time overlay
                VStack {
                    Spacer()
                    if !annotations.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(annotations.count) Jobs")
                                    .font(.headline)
                                if totalDriveTime > 0 {
                                    Text("Est. drive: \(formatTime(totalDriveTime))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if let selected = selectedAnnotation {
                                Button {
                                    openInAppleMaps(annotation: selected)
                                } label: {
                                    Label("Navigate", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                        .font(.subheadline.bold())
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .padding()
                    }
                }

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Geocoding jobs...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }

                if let error = errorMessage {
                    VStack {
                        Text(error)
                            .foregroundStyle(.red)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Job Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedAnnotation) { annotation in
                jobDetailSheet(annotation)
            }
            .task {
                await geocodeAndRoute()
            }
        }
    }

    // MARK: - Job Detail Sheet

    @ViewBuilder
    private func jobDetailSheet(_ annotation: JobAnnotation) -> some View {
        NavigationStack {
            List {
                Section("Job Details") {
                    LabeledContent("Job #", value: annotation.job.jobNumber)
                    LabeledContent("Lot", value: annotation.job.lotNumber)
                    LabeledContent("Subdivision", value: annotation.job.subdivision)
                    LabeledContent("Address", value: annotation.job.address)
                    LabeledContent("Route Order", value: "#\(annotation.routeOrder)")
                }

                Section {
                    Button {
                        openInAppleMaps(annotation: annotation)
                    } label: {
                        Label("Open in Apple Maps", systemImage: "map.fill")
                    }
                }
            }
            .navigationTitle("Lot \(annotation.job.lotNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selectedAnnotation = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Geocoding & Routing

    private func geocodeAndRoute() async {
        let jobs = todaysJobs
        guard !jobs.isEmpty else {
            isLoading = false
            errorMessage = "No jobs scheduled for today"
            return
        }

        let geocoder = CLGeocoder()
        var geocoded: [JobAnnotation] = []

        for job in jobs {
            let query = "\(job.subdivision), \(job.address), Indianapolis, IN"
            do {
                let placemarks = try await geocoder.geocodeAddressString(query)
                if let coord = placemarks.first?.location?.coordinate {
                    geocoded.append(JobAnnotation(id: job.id, job: job, coordinate: coord))
                }
                // Rate limit geocoding
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                print("📍 Geocode failed for \(job.lotNumber): \(error.localizedDescription)")
            }
        }

        guard !geocoded.isEmpty else {
            await MainActor.run {
                isLoading = false
                errorMessage = "Could not geocode any job addresses"
            }
            return
        }

        // Nearest-neighbor routing
        let sorted = await calculateOptimalRoute(annotations: geocoded)

        await MainActor.run {
            annotations = sorted
            isLoading = false
        }

        // Calculate route directions
        await calculateDriveTimes(for: sorted)
    }

    private func calculateOptimalRoute(annotations: [JobAnnotation]) async -> [JobAnnotation] {
        var remaining = annotations
        var ordered: [JobAnnotation] = []
        var order = 1

        // Start from user's current location or first job
        let locationManager = CLLocationManager()
        var currentCoord = remaining.first?.coordinate ?? CLLocationCoordinate2D(latitude: 39.7684, longitude: -86.1581) // Indianapolis default

        if let userLocation = locationManager.location?.coordinate {
            currentCoord = userLocation
        }

        while !remaining.isEmpty {
            // Find nearest unvisited
            var nearestIndex = 0
            var nearestDistance = CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude)
                .distance(from: CLLocation(latitude: remaining[0].coordinate.latitude, longitude: remaining[0].coordinate.longitude))

            for i in 1..<remaining.count {
                let dist = CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude)
                    .distance(from: CLLocation(latitude: remaining[i].coordinate.latitude, longitude: remaining[i].coordinate.longitude))
                if dist < nearestDistance {
                    nearestDistance = dist
                    nearestIndex = i
                }
            }

            var annotation = remaining.remove(at: nearestIndex)
            annotation.routeOrder = order
            ordered.append(annotation)
            currentCoord = annotation.coordinate
            order += 1
        }

        return ordered
    }

    private func calculateDriveTimes(for annotations: [JobAnnotation]) async {
        guard annotations.count >= 2 else { return }

        var totalTime: TimeInterval = 0

        for i in 0..<(annotations.count - 1) {
            let source = MKMapItem(placemark: MKPlacemark(coordinate: annotations[i].coordinate))
            let destination = MKMapItem(placemark: MKPlacemark(coordinate: annotations[i + 1].coordinate))

            let request = MKDirections.Request()
            request.source = source
            request.destination = destination
            request.transportType = .automobile

            do {
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    totalTime += route.expectedTravelTime
                }
            } catch {
                print("📍 Route calc error: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            totalDriveTime = totalTime
        }
    }

    // MARK: - Helpers

    private func openInAppleMaps(annotation: JobAnnotation) {
        let placemark = MKPlacemark(coordinate: annotation.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Lot \(annotation.job.lotNumber) - \(annotation.job.subdivision)"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}
