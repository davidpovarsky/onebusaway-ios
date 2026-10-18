//
//  MOTLocationWeatherTests.swift
//  IsraelMOTTests
//
//  Offline contract checks for coordinate-based weather, not a fixed OBA region.
//

import Foundation
import Testing
@testable import OBAKit

@Suite(.serialized)
struct MOTLocationWeatherTests {
    @Test
    func testDecodeMETNorwayHourlyForecastForCoordinates() throws {
        let json = """
        {
          "properties": {
            "timeseries": [
              {
                "time": "2026-10-17T23:00:00Z",
                "data": {
                  "instant": { "details": { "air_temperature": 14.5, "wind_speed": 1.6 } },
                  "next_1_hours": {
                    "summary": { "symbol_code": "clearsky_night" },
                    "details": { "probability_of_precipitation": 15.0 }
                  }
                }
              },
              {
                "time": "2026-10-18T00:00:00Z",
                "data": {
                  "instant": { "details": { "air_temperature": 13.5, "wind_speed": 2.0 } },
                  "next_1_hours": {
                    "summary": { "symbol_code": "rain" },
                    "details": {}
                  }
                }
              }
            ]
          }
        }
        """
        let snapshot = try MOTLocationWeatherService.decodeForecast(
            data: Data(json.utf8),
            latitude: 31.78,
            longitude: 35.21
        )
        #expect(snapshot.hours.count == 2)
        #expect(snapshot.locationLatitude == 31.78)
        #expect(snapshot.locationLongitude == 35.21)
        #expect(snapshot.hours[0].temperatureCelsius == 14.5)
        #expect(snapshot.hours[0].windMetersPerSecond == 1.6)
        #expect(snapshot.hours[0].precipitationChancePercent == 15)
        #expect(snapshot.hours[0].iconKey == "clear-night")
        #expect(snapshot.hours[1].iconKey == "rain")
        #expect(snapshot.hours[1].precipitationChancePercent == nil)

        let timestamp = try #require(ISO8601DateFormatter().date(from: "2026-10-17T23:15:00Z"))
        let display = try #require(
            WeatherDisplay(
                locationForecast: snapshot,
                locationName: "ירושלים",
                locale: Locale(identifier: "he_IL"),
                now: timestamp
            )
        )
        #expect(display.header.regionName == "ירושלים")
        #expect(display.header.iconName == "clear-night")
        #expect(display.stats.precipText == "15%")
        #expect(display.sourceAttribution?.contains("MET Norway") == true)
    }

    @Test
    func testBadMETDataFailsInsteadOfShowingAnotherCity() {
        #expect(throws: (any Error).self) {
            try MOTLocationWeatherService.decodeForecast(
                data: Data("{}".utf8),
                latitude: 31.78,
                longitude: 35.21
            )
        }
    }
}
