//
//  TripTrackingManager.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import Foundation
import CoreLocation
import Combine
import UIKit
import SwiftData

@MainActor
class TripTrackingManager: NSObject, ObservableObject {
    static let shared = TripTrackingManager()

    @Published var isTracking = false
    @Published var currentTrip: MileageTrip?
    @Published var totalMiles: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var accumulatedDistance: Double = 0
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var modelContainer: ModelContainer?
    private var lastSaveTime: Date = .distantPast
    private var timer: Timer?
    private var tripStartTime: Date?

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.activityType = .automotiveNavigation

        // Listen for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        // Resume timer when app becomes active
        if isTracking {
            startTimer()
        }
    }

    @objc private func appWillResignActive() {
        // Timer continues in background via location updates
    }

    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    private func startTimer() {
        stopTimer() // Make sure old timer is stopped

        // Create timer and add to main RunLoop explicitly
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.updateElapsedTime()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer

        // Also update immediately
        updateElapsedTime()

        print("⏱️ Timer started")
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        print("⏱️ Timer stopped")
    }

    private func updateElapsedTime() {
        if let startTime = tripStartTime, isTracking {
            elapsedTime = Date().timeIntervalSince(startTime)
        }
    }

    func startTrip() {
        print("🚗 startTrip() called - isTracking: \(isTracking)")

        guard !isTracking else {
            print("⚠️ Already tracking, ignoring startTrip()")
            return
        }

        // Request background execution time
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "MileageTracking") { [weak self] in
            self?.handleBackgroundExpiration()
        }

        // Request location permission if needed
        if authorizationStatus == .notDetermined {
            requestLocationPermission()
        } else if authorizationStatus == .authorizedWhenInUse {
            // Prompt for "Always" permission
            locationManager.requestAlwaysAuthorization()
        }

        isTracking = true
        accumulatedDistance = 0
        totalMiles = 0
        elapsedTime = 0
        lastLocation = nil
        tripStartTime = Date()

        // Create new trip record with owner info
        currentTrip = MileageTrip(
            startDate: Date(),
            miles: 0,
            ownerEmail: GmailAuthManager.shared.userEmail,
            ownerName: Settings.shared.workerName
        )

        // Start the timer
        startTimer()

        // Enable background tracking - CRITICAL for background location
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false  // Don't pause!
        locationManager.showsBackgroundLocationIndicator = true

        // Start tracking location
        locationManager.startUpdatingLocation()

        // Notify watch
        WatchConnectivityManager.shared.notifyTripStarted()
        WatchConnectivityManager.shared.updateApplicationContext(isTracking: true, miles: 0, elapsedTime: 0)

        print("🚗 Trip started at \(Date())")
    }

    func stopTrip() -> MileageTrip? {
        print("🛑 stopTrip() called - isTracking: \(isTracking), currentTrip: \(currentTrip != nil)")

        guard let trip = currentTrip else {
            print("⚠️ No current trip to stop")
            return nil
        }

        // Stop tracking
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false

        // Stop timer
        stopTimer()

        // Update trip with final data
        trip.endDate = Date()
        trip.miles = totalMiles

        let finalMiles = totalMiles
        print("🛑 Trip stopped - \(finalMiles) miles")

        // End background task
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }

        // Clear current trip state
        let completedTrip = trip
        currentTrip = nil
        lastLocation = nil
        accumulatedDistance = 0
        totalMiles = 0
        elapsedTime = 0
        tripStartTime = nil

        // Notify watch
        WatchConnectivityManager.shared.notifyTripStopped(miles: finalMiles)
        WatchConnectivityManager.shared.updateApplicationContext(isTracking: false, miles: 0, elapsedTime: 0)

        return completedTrip
    }

    func cancelTrip() {
        print("🚫 cancelTrip() called - isTracking was: \(isTracking)")

        // IMMEDIATELY set isTracking to false FIRST
        isTracking = false

        // Stop location services
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false

        // Stop timer
        stopTimer()

        // End background task
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }

        // Clear all other state
        currentTrip = nil
        lastLocation = nil
        accumulatedDistance = 0
        totalMiles = 0
        elapsedTime = 0
        tripStartTime = nil

        // Notify watch
        WatchConnectivityManager.shared.updateApplicationContext(isTracking: false, miles: 0, elapsedTime: 0)

        print("🚫 cancelTrip() done - isTracking is now: \(isTracking)")

        print("🚫 Trip cancelled")
    }

    private func handleBackgroundExpiration() {
        print("⏱ Background time expiring - saving trip data")

        if let trip = currentTrip {
            trip.miles = totalMiles
            Task {
                await persistActiveTrip(trip)
            }
        }

        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    private func metersToMiles(_ meters: Double) -> Double {
        return meters / 1609.34
    }

    // MARK: - Persistence

    func setModelContainer(_ container: ModelContainer) {
        self.modelContainer = container
    }

    private func persistActiveTrip(_ trip: MileageTrip) async {
        // Rate limit saves to every 30 seconds
        let now = Date()
        guard now.timeIntervalSince(lastSaveTime) >= 30 else { return }
        lastSaveTime = now

        guard let container = modelContainer else { return }

        let context = ModelContext(container)

        do {
            let tripId = trip.id
            let descriptor = FetchDescriptor<MileageTrip>(
                predicate: #Predicate { $0.id == tripId }
            )
            let existing = try context.fetch(descriptor).first

            if existing == nil {
                context.insert(trip)
            }

            try context.save()
            print("💾 Auto-saved trip: \(trip.miles) miles")
        } catch {
            print("❌ Failed to persist trip: \(error)")
        }
    }

    func recoverActiveTrip(from container: ModelContainer) async -> MileageTrip? {
        let context = ModelContext(container)

        do {
            let descriptor = FetchDescriptor<MileageTrip>(
                predicate: #Predicate { $0.endDate == nil },
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )

            let activeTrips = try context.fetch(descriptor)

            // Delete any incomplete trips - they're orphaned from previous sessions
            for trip in activeTrips {
                print("🗑️ Deleting orphaned trip from \(trip.startDate)")
                context.delete(trip)
            }
            try context.save()

            // Don't recover - start fresh
            currentTrip = nil
            isTracking = false

        } catch {
            print("❌ Failed to clean up trips: \(error)")
        }

        return nil
    }

    /// Clean up any orphaned trips in the database
    func cleanupOrphanedTrips(from container: ModelContainer) async {
        let context = ModelContext(container)

        do {
            let descriptor = FetchDescriptor<MileageTrip>(
                predicate: #Predicate { $0.endDate == nil }
            )

            let orphanedTrips = try context.fetch(descriptor)

            for trip in orphanedTrips {
                print("🗑️ Cleaning up orphaned trip: \(trip.miles) miles from \(trip.startDate)")
                context.delete(trip)
            }

            if !orphanedTrips.isEmpty {
                try context.save()
                print("✅ Cleaned up \(orphanedTrips.count) orphaned trip(s)")
            }
        } catch {
            print("❌ Failed to clean up orphaned trips: \(error)")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension TripTrackingManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Filter accuracy OFF main thread
        let validLocations = locations.filter {
            $0.horizontalAccuracy > 0 && $0.horizontalAccuracy < 50
        }

        guard !validLocations.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let self = self, self.isTracking else { return }
            await self.processLocations(validLocations)
        }
    }

    private func processLocations(_ locations: [CLLocation]) async {
        for location in locations {
            guard location.horizontalAccuracy < 50 else { continue }

            if let lastLoc = lastLocation {
                let distance = location.distance(from: lastLoc)

                if distance > 0 && distance < 1000 {
                    accumulatedDistance += distance
                    totalMiles = metersToMiles(accumulatedDistance)

                    // Auto-save periodically
                    if let trip = currentTrip {
                        trip.miles = totalMiles
                        await persistActiveTrip(trip)
                    }

                    // Send update to watch (throttled by rate limiting in persistActiveTrip)
                    WatchConnectivityManager.shared.sendTripUpdate(
                        isTracking: isTracking,
                        miles: totalMiles,
                        elapsedTime: elapsedTime
                    )
                }
            }

            lastLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            print("❌ Location error: \(error.localizedDescription)")

            // Don't stop tracking on temporary errors
            if let clError = error as? CLError {
                switch clError.code {
                case .locationUnknown:
                    break // Temporary GPS loss - continue tracking
                case .denied:
                    if self.isTracking {
                        _ = self.stopTrip()
                    }
                default:
                    break
                }
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.authorizationStatus = manager.authorizationStatus

            switch manager.authorizationStatus {
            case .authorizedAlways:
                print("✅ Background location permission granted")
            case .authorizedWhenInUse:
                print("⚠️ Only 'When In Use' permission - request 'Always' for background tracking")
            case .denied, .restricted:
                print("❌ Location permission denied")
                if self.isTracking {
                    _ = self.stopTrip()
                }
            case .notDetermined:
                print("⚠️ Location permission not determined")
            @unknown default:
                break
            }
        }
    }
}
