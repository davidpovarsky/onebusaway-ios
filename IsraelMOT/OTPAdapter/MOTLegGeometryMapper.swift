//
//  MOTLegGeometryMapper.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

#if canImport(OTPKit)
import OTPKit
#endif

nonisolated public enum MOTLegGeometryMapper {
    /// Decodes a Google encoded polyline string into an array of coordinates.
    public static func decodePolyline(_ encodedString: String) -> [CLLocationCoordinate2D] {
        return GooglePolylineEncoder.decode(encodedString)
    }

    /// Encodes an array of coordinates into a Google Polyline string.
    public static func encodePolyline(_ coordinates: [CLLocationCoordinate2D]) -> String {
        return GooglePolylineEncoder.encode(coordinates)
    }

    /// Decodes an input polyline (either HERE flexible polyline or Google format) to coordinates.
    public static func decodeToCoordinates(polyline: String?) -> [CLLocationCoordinate2D] {
        guard let poly = polyline, !poly.isEmpty else { return [] }
        if HEREFlexiblePolylineDecoder.isFlexiblePolyline(poly) {
            return (try? HEREFlexiblePolylineDecoder.decode(poly)) ?? []
        } else {
            return GooglePolylineEncoder.decode(poly)
        }
    }

    #if canImport(OTPKit)
    /// Converts a polyline from MOT (HERE flexible polyline or Google format) into OTPKit's LegGeometry,
    /// ensuring the resulting `points` is formatted as standard Google Encoded Polyline (E5).
    public static func map(
        fromPolyline polyline: String?,
        fallbackOrigin: CLLocationCoordinate2D,
        fallbackDest: CLLocationCoordinate2D
    ) -> LegGeometry {
        if let poly = polyline, !poly.isEmpty {
            let coords: [CLLocationCoordinate2D]
            if HEREFlexiblePolylineDecoder.isFlexiblePolyline(poly) {
                coords = (try? HEREFlexiblePolylineDecoder.decode(poly)) ?? []
            } else {
                coords = GooglePolylineEncoder.decode(poly)
            }

            if !coords.isEmpty {
                let googlePolyline = GooglePolylineEncoder.encode(coords)
                return LegGeometry(points: googlePolyline, length: coords.count)
            }
        }

        // Truthful straight-line fallback
        let fallbackCoords = [fallbackOrigin, fallbackDest]
        let encoded = GooglePolylineEncoder.encode(fallbackCoords)
        return LegGeometry(points: encoded, length: 2)
    }
    #endif
}
