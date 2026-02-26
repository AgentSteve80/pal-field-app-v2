//
//  WeatherView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import SwiftUI

struct WeatherView: View {
    @State private var weatherData: WeatherData?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var lastUpdated: Date?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                Group {
                    if isLoading && weatherData == nil {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading weather data...")
                                .foregroundStyle(.secondary)
                        }
                    } else if let weather = weatherData {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Location Header
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(.blue)
                                    Text("Indianapolis Area")
                                        .font(.title2.bold())
                                }

                                if let updated = lastUpdated {
                                    Text("Updated \(updated, style: .relative)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top)

                            // Weather Alerts
                            if !weather.alerts.isEmpty {
                                ForEach(weather.alerts) { alert in
                                    WeatherAlertCard(alert: alert)
                                }
                                .padding(.horizontal)
                            }

                            // Current Weather Card
                            CurrentWeatherCard(current: weather.current)
                                .padding(.horizontal)

                            // 5-Day Forecast
                            VStack(alignment: .leading, spacing: 12) {
                                Text("5-Day Forecast")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(weather.forecast) { day in
                                    ForecastRow(forecast: day)
                                }
                            }
                            .padding(.bottom)
                        }
                    }
                    .refreshable {
                        await loadWeather()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)

                        Text("Weather Setup Required")
                            .font(.title2.bold())

                        Text(errorMessage ?? "Unable to load weather data")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Setup:")
                                .font(.headline)

                            Text("1. Sign up at openweathermap.org")
                                .font(.caption)
                            Text("2. Get your free API key")
                                .font(.caption)
                            Text("3. Add it to WeatherService.swift")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)

                        Button("Retry") {
                            Task {
                                await loadWeather()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                }
            }
            .navigationTitle("Weather")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await loadWeather()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .alert("Weather Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
        .task {
            await loadWeather()
        }
    }

    private func loadWeather() async {
        print("🌤️ Starting weather load...")
        isLoading = true
        errorMessage = nil

        do {
            let data = try await WeatherService.shared.fetchWeather()
            print("✅ Weather data loaded successfully")
            await MainActor.run {
                weatherData = data
                lastUpdated = Date()
                isLoading = false
            }
        } catch {
            print("❌ Weather load failed: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false

                if weatherData == nil {
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Current Weather Card

struct CurrentWeatherCard: View {
    let current: CurrentWeather

    var body: some View {
        VStack(spacing: 20) {
            // Temperature and Icon
            HStack(spacing: 20) {
                AsyncImage(url: WeatherService.shared.getWeatherIconURL(icon: current.icon)) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                } placeholder: {
                    ProgressView()
                        .frame(width: 100, height: 100)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(current.tempF)°F")
                        .font(.system(size: 56, weight: .bold))

                    Text(current.description)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Feels like \(current.feelsLikeF)°F")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // High/Low
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(.red)
                    Text("\(current.highF)°F")
                        .font(.title3.bold())
                    Text("High")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.blue)
                    Text("\(current.lowF)°F")
                        .font(.title3.bold())
                    Text("Low")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Additional Details
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Image(systemName: "humidity.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    Text("\(current.humidity)%")
                        .font(.headline)
                    Text("Humidity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Image(systemName: "wind")
                        .foregroundStyle(.green)
                        .font(.title2)
                    Text("\(Int(current.windSpeed)) mph")
                        .font(.headline)
                    Text("Wind Speed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.2), .cyan.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

// MARK: - Forecast Row

struct ForecastRow: View {
    let forecast: DailyForecast

    var body: some View {
        HStack(spacing: 16) {
            // Day
            Text(forecast.shortDayName)
                .font(.headline)
                .frame(width: 50, alignment: .leading)

            // Icon
            AsyncImage(url: WeatherService.shared.getWeatherIconURL(icon: forecast.icon)) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            } placeholder: {
                ProgressView()
                    .frame(width: 40, height: 40)
            }

            // Description
            Text(forecast.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // High/Low
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text("\(forecast.highF)°")
                        .font(.headline)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("\(forecast.lowF)°")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Weather Alert Card

struct WeatherAlertCard: View {
    let alert: WeatherAlert

    var alertColor: Color {
        switch alert.severityColor {
        case "red":
            return .red
        case "orange":
            return .orange
        default:
            return .yellow
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(alertColor)
                    .font(.title3)
                Text(alert.event)
                    .font(.headline)
                    .foregroundStyle(alertColor)
            }

            // Headline
            Text(alert.headline)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Divider()

            // Description
            Text(alert.description)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Instruction (if available)
            if let instruction = alert.instruction, !instruction.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("What to do:")
                            .font(.subheadline.bold())
                    }

                    Text(instruction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Footer info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(alert.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let endsDate = alert.endsDate {
                        Text("Ends \(endsDate, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Expires \(alert.expiresDate, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(alert.areaDesc.components(separatedBy: ";").prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(alertColor.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(alertColor.opacity(0.5), lineWidth: 2)
        )
    }
}
