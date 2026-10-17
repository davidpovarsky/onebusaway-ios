//
//  GooglePolylineEncoder.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

/// Encodes and decodes Google Encoded Polyline (E5 precision) strings.
nonisolated public enum GooglePolylineEncoder {
    /// Decodes a Google encoded polyline string into an array of coordinates.
    public static func decode(_ encodedString: String) -> [CLLocationCoordinate2D] {
        guard !encodedString.isEmpty else { return [] }
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encodedString.startIndex
        var lat = 0
        var lng = 0

        while index < encodedString.endIndex {
            var b = 0
            var shift = 0
            var result = 0
            repeat {
                guard index < encodedString.endIndex else { break }
                let char = encodedString[index]
                b = Int(char.asciiValue ?? 63) - 63
                index = encodedString.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20

            let dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += dlat

            shift = 0
            result = 0
            repeat {
                guard index < encodedString.endIndex else { break }
                let char = encodedString[index]
                b = Int(char.asciiValue ?? 63) - 63
                index = encodedString.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20

            let dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += dlng

            let latitude = Double(lat) * 1e-5
            let longitude = Double(lng) * 1e-5
            coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }

        return coordinates
    }

    /// Encodes an array of coordinates into a Google Polyline string (precision E5).
    public static func encode(_ coordinates: [CLLocationCoordinate2D]) -> String {
        var result = ""
        var prevLat = 0
        var prevLng = 0

        for coord in coordinates {
            let lat = Int(round(coord.latitude * 1e5))
            let lng = Int(round(coord.longitude * 1e5))

            encodeSignedNumber(lat - prevLat, into: &result)
            encodeSignedNumber(lng - prevLng, into: &result)

            prevLat = lat
            prevLng = lng
        }

        return result
    }

    private static func encodeSignedNumber(_ num: Int, into result: inout String) {
        var snum = num < 0 ? ~(num << 1) : (num << 1)
        while snum >= 0x20 {
            let nextChar = Character(UnicodeScalar((0x20 | (snum & 0x1f)) + 63)!)
            result.append(nextChar)
            snum >>= 5
        }
        let lastChar = Character(UnicodeScalar(snum + 63)!)
        result.append(lastChar)
    }
}
