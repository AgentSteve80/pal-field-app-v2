//
//  WeatherModels.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import Foundation

// MARK: - Weather Response Models

struct WeatherResponse: Codable {
    let main: WeatherMain
    let weather: [WeatherCondition]
    let wind: Wind
    let dt: Int
    let name: String
}

struct WeatherMain: Codable {
    let temp: Double
    let feelsLike: Double
    let tempMin: Double
    let tempMax: Double
    let humidity: Int

    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case tempMin = "temp_min"
        case tempMax = "temp_max"
        case humidity
    }
}

struct WeatherCondition: Codable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

struct Wind: Codable {
    let speed: Double
}

// MARK: - Forecast Response

struct ForecastResponse: Codable {
    let list: [ForecastItem]
}

struct ForecastItem: Codable {
    let dt: Int
    let main: WeatherMain
    let weather: [WeatherCondition]
    let wind: Wind
    let dtTxt: String

    enum CodingKeys: String, CodingKey {
        case dt, main, weather, wind
        case dtTxt = "dt_txt"
    }
}

// MARK: - NWS Alerts Response

struct NWSAlertsResponse: Codable {
    let features: [NWSAlertFeature]
}

struct NWSAlertFeature: Codable {
    let properties: NWSAlertProperties
}

struct NWSAlertProperties: Codable {
    let event: String
    let headline: String
    let description: String
    let instruction: String?
    let severity: String
    let certainty: String
    let urgency: String
    let effective: String
    let expires: String
    let ends: String?
    let senderName: String
    let areaDesc: String
}

struct WeatherAlert: Identifiable {
    let id = UUID()
    let event: String
    let headline: String
    let description: String
    let instruction: String?
    let severity: String
    let certainty: String
    let urgency: String
    let effectiveDate: Date
    let expiresDate: Date
    let endsDate: Date?
    let senderName: String
    let areaDesc: String

    var severityColor: String {
        switch severity.lowercased() {
        case "extreme", "severe":
            return "red"
        case "moderate":
            return "orange"
        default:
            return "yellow"
        }
    }

    init(from properties: NWSAlertProperties) {
        self.event = properties.event
        self.headline = properties.headline
        self.description = properties.description
        self.instruction = properties.instruction
        self.severity = properties.severity
        self.certainty = properties.certainty
        self.urgency = properties.urgency
        self.senderName = properties.senderName
        self.areaDesc = properties.areaDesc

        let formatter = ISO8601DateFormatter()
        self.effectiveDate = formatter.date(from: properties.effective) ?? Date()
        self.expiresDate = formatter.date(from: properties.expires) ?? Date()
        self.endsDate = properties.ends.flatMap { formatter.date(from: $0) }
    }
}

// MARK: - View Models

struct WeatherData {
    let current: CurrentWeather
    let forecast: [DailyForecast]
    let alerts: [WeatherAlert]
}

struct CurrentWeather {
    let temperature: Double
    let feelsLike: Double
    let condition: String
    let description: String
    let icon: String
    let humidity: Int
    let windSpeed: Double
    let high: Double
    let low: Double

    var tempF: Int {
        Int(temperature)
    }

    var feelsLikeF: Int {
        Int(feelsLike)
    }

    var highF: Int {
        Int(high)
    }

    var lowF: Int {
        Int(low)
    }
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let high: Double
    let low: Double
    let condition: String
    let description: String
    let icon: String
    let humidity: Int
    let windSpeed: Double

    var highF: Int {
        Int(high)
    }

    var lowF: Int {
        Int(low)
    }

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
