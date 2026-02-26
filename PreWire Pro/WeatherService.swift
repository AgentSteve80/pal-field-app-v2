//
//  WeatherService.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import Foundation

class WeatherService {
    static let shared = WeatherService()

    // Indianapolis coordinates
    private let latitude = 39.7684
    private let longitude = -86.1581

    // OpenWeatherMap API key - Sign up at https://openweathermap.org/api
    // Free tier includes: current weather, 5-day forecast, and weather alerts
    private let apiKey = "80e051a47b1ccec262800576521bcfa1"

    private let baseURL = "https://api.openweathermap.org/data/2.5"

    private init() {}

    // MARK: - Fetch Weather Data

    func fetchWeather() async throws -> WeatherData {
        print("🌤️ Fetching weather data...")

        // Check API key
        if apiKey == "YOUR_API_KEY_HERE" {
            print("⚠️ API key not set - will show error")
            throw WeatherError.apiKeyNotSet
        }

        do {
            async let current = fetchCurrentWeather()
            async let forecast = fetchForecast()
            async let alerts = fetchAlerts()

            let currentWeather = try await current
            let forecastData = try await forecast
            let alertsData = try await alerts

            print("✅ All weather data fetched successfully")
            return WeatherData(
                current: currentWeather,
                forecast: forecastData,
                alerts: alertsData
            )
        } catch {
            print("❌ Error fetching weather: \(error)")
            throw error
        }
    }

    // MARK: - Current Weather

    private func fetchCurrentWeather() async throws -> CurrentWeather {
        let urlString = "\(baseURL)/weather?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=imperial"

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            // Try to decode error message from API
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let message = errorResponse["message"] {
                print("❌ OpenWeatherMap API error (\(httpResponse.statusCode)): \(message)")
                throw WeatherError.apiError(message)
            }
            print("❌ Weather API returned status code: \(httpResponse.statusCode)")
            throw WeatherError.invalidResponse
        }

        let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)

        return CurrentWeather(
            temperature: weatherResponse.main.temp,
            feelsLike: weatherResponse.main.feelsLike,
            condition: weatherResponse.weather.first?.main ?? "Unknown",
            description: weatherResponse.weather.first?.description.capitalized ?? "N/A",
            icon: weatherResponse.weather.first?.icon ?? "01d",
            humidity: weatherResponse.main.humidity,
            windSpeed: weatherResponse.wind.speed,
            high: weatherResponse.main.tempMax,
            low: weatherResponse.main.tempMin
        )
    }

    // MARK: - 5-Day Forecast

    private func fetchForecast() async throws -> [DailyForecast] {
        let urlString = "\(baseURL)/forecast?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=imperial"

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }

        let forecastResponse = try JSONDecoder().decode(ForecastResponse.self, from: data)

        // Group forecast items by day and get daily highs/lows
        let calendar = Calendar.current
        var dailyData: [Date: [ForecastItem]] = [:]

        for item in forecastResponse.list {
            let date = Date(timeIntervalSince1970: TimeInterval(item.dt))
            let dayStart = calendar.startOfDay(for: date)

            if dailyData[dayStart] == nil {
                dailyData[dayStart] = []
            }
            dailyData[dayStart]?.append(item)
        }

        // Convert to DailyForecast objects
        let forecasts = dailyData.sorted { $0.key < $1.key }.prefix(5).map { date, items in
            let high = items.map { $0.main.tempMax }.max() ?? 0
            let low = items.map { $0.main.tempMin }.min() ?? 0
            let midday = items.first { calendar.component(.hour, from: Date(timeIntervalSince1970: TimeInterval($0.dt))) == 12 } ?? items.first!

            return DailyForecast(
                date: date,
                high: high,
                low: low,
                condition: midday.weather.first?.main ?? "Unknown",
                description: midday.weather.first?.description.capitalized ?? "N/A",
                icon: midday.weather.first?.icon ?? "01d",
                humidity: midday.main.humidity,
                windSpeed: midday.wind.speed
            )
        }

        return Array(forecasts)
    }

    // MARK: - Weather Alerts (NWS API - Free!)

    private func fetchAlerts() async throws -> [WeatherAlert] {
        // Using National Weather Service API for alerts - completely free!
        let urlString = "https://api.weather.gov/alerts/active/area/IN"

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        request.setValue("(Pal Low Voltage Pro, contact@example.com)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                print("⚠️ NWS alerts returned status code: \(httpResponse.statusCode)")
                return []
            }

            let alertsResponse = try JSONDecoder().decode(NWSAlertsResponse.self, from: data)

            // Convert NWS alerts to our WeatherAlert model
            let alerts = alertsResponse.features.map { feature in
                WeatherAlert(from: feature.properties)
            }

            print("✅ Fetched \(alerts.count) weather alerts from NWS")
            return alerts

        } catch {
            // If alerts fail, return empty array instead of crashing
            print("⚠️ Could not fetch weather alerts: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Weather Icon

    func getWeatherIconURL(icon: String) -> URL? {
        URL(string: "https://openweathermap.org/img/wn/\(icon)@2x.png")
    }
}

// MARK: - Errors

enum WeatherError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case apiKeyNotSet
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid weather service URL"
        case .invalidResponse:
            return "Invalid response from weather service"
        case .decodingError:
            return "Failed to decode weather data"
        case .apiKeyNotSet:
            return "OpenWeatherMap API key not set. Please add your free API key in WeatherService.swift (line 18). See WEATHER_SETUP.md for instructions."
        case .apiError(let message):
            return "Weather API Error: \(message)"
        }
    }
}
