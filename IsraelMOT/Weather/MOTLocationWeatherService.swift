//
//  MOTLocationWeatherService.swift
//  IsraelMOT
//
//  Independent coordinate-based weather source. Transit region IDs are NOT
//  weather locations. Data: Norwegian Meteorological Institute (MET Norway).
//  Forecast data licensed CC BY 4.0; attribution appears on the weather card.
//

import Foundation

nonisolated public struct MOTLocationWeatherSnapshot: Sendable {
    public let hours: [MOTLocationWeatherHour]
    public let retrievedAt: Date
    public let locationLatitude: Double
    public let locationLongitude: Double
    public static let attribution = "Weather data: MET Norway (CC BY 4.0)"
}

nonisolated public struct MOTLocationWeatherHour: Sendable {
    public let time: Date
    public let temperatureCelsius: Double
    public let windMetersPerSecond: Double?
    public let precipitationChancePercent: Double?
    public let iconKey: String
}

public actor MOTLocationWeatherService {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Retrieves a genuine forecast for GPS coordinates, never for the
    /// OneBusAway current transit region or a fixed US city.
    public func forecast(latitude: Double, longitude: Double) async throws -> MOTLocationWeatherSnapshot {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw MOTLocationWeatherError.invalidCoordinate
        }
        var parts = URLComponents(string: "https://api.met.no/weatherapi/locationforecast/2.0/compact")!
        // MET Norway requires at most 4 decimals of coordinate precision.
        parts.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.4f", longitude))
        ]
        guard let url = parts.url else { throw MOTLocationWeatherError.invalidCoordinate }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "OneBusAwayIsrael/1.0 (https://github.com/davidpovarsky/onebusaway-ios; iphone-app@onebusaway.org)",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw MOTLocationWeatherError.serverUnavailable
        }
        return try Self.decodeForecast(data: data, latitude: latitude, longitude: longitude)
    }

    /// Offline-testable mapping of MET Norway's forecast JSON.
    public nonisolated static func decodeForecast(
        data: Data, latitude: Double, longitude: Double
    ) throws -> MOTLocationWeatherSnapshot {
        let result = try JSONDecoder().decode(METLocationForecast.self, from: data)
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        let hours: [MOTLocationWeatherHour] = result.properties.timeseries.compactMap { entry in
            guard let date = parser.date(from: entry.time) else { return nil }
            let summary = entry.data.next1Hours?.summary?.symbolCode
                ?? entry.data.next6Hours?.summary?.symbolCode
                ?? entry.data.next12Hours?.summary?.symbolCode
                ?? "unknown"
            return MOTLocationWeatherHour(
                time: date,
                temperatureCelsius: entry.data.instant.details.airTemperature,
                windMetersPerSecond: entry.data.instant.details.windSpeed,
                precipitationChancePercent: entry.data.next1Hours?.details?.probabilityOfPrecipitation,
                iconKey: Self.iconKey(from: summary)
            )
        }
        guard !hours.isEmpty else { throw MOTLocationWeatherError.emptyForecast }
        return MOTLocationWeatherSnapshot(
            hours: hours.sorted { $0.time < $1.time },
            retrievedAt: Date(),
            locationLatitude: latitude,
            locationLongitude: longitude
        )
    }

    /// Convert MET Norway's symbol codes to keys already supported by WeatherFormatter.
    private nonisolated static func iconKey(from symbol: String) -> String {
        let code = symbol.lowercased()
        let isNight = code.contains("_night")
        let suffix = isNight ? "night" : "day"

        if code.contains("thunder") || code.contains("rain") || code.contains("showers") {
            return "rain"
        }
        if code.contains("snow") {
            return "snow"
        }
        if code.contains("sleet") {
            return "sleet"
        }
        if code.contains("fog") {
            return "fog"
        }
        if code.contains("clearsky") {
            return "clear-\(suffix)"
        }
        if code.contains("partlycloudy") || code.contains("fair") {
            return "partly-cloudy-\(suffix)"
        }
        if code.contains("cloudy") {
            return "cloudy"
        }
        return "unknown"
    }
}

nonisolated public enum MOTLocationWeatherError: Error {
    case invalidCoordinate
    case serverUnavailable
    case emptyForecast
}

nonisolated private struct METLocationForecast: Decodable {
    let properties: Properties

    struct Properties: Decodable {
        let timeseries: [TimeEntry]
    }

    struct TimeEntry: Decodable {
        let time: String
        let data: WeatherData
    }

    struct WeatherData: Decodable {
        let instant: Instant
        let next1Hours: NextPeriod?
        let next6Hours: NextPeriod?
        let next12Hours: NextPeriod?

        private enum CodingKeys: String, CodingKey {
            case instant
            case next1Hours = "next_1_hours"
            case next6Hours = "next_6_hours"
            case next12Hours = "next_12_hours"
        }
    }

    struct Instant: Decodable {
        let details: CurrentDetails
    }

    struct CurrentDetails: Decodable {
        let airTemperature: Double
        let windSpeed: Double?

        private enum CodingKeys: String, CodingKey {
            case airTemperature = "air_temperature"
            case windSpeed = "wind_speed"
        }
    }

    struct NextPeriod: Decodable {
        let summary: Summary?
        let details: PeriodDetails?
    }

    struct Summary: Decodable {
        let symbolCode: String

        private enum CodingKeys: String, CodingKey {
            case symbolCode = "symbol_code"
        }
    }

    struct PeriodDetails: Decodable {
        let probabilityOfPrecipitation: Double?

        private enum CodingKeys: String, CodingKey {
            case probabilityOfPrecipitation = "probability_of_precipitation"
        }
    }
}
