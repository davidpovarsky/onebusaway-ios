//
//  MOTRouteGeometryPipeline.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

/// Canonical pipeline for decoding, validating, and converting route and trip geometry.
/// Ensures all transit geometry provided to OneBusAway REST APIs is valid Google E5 format
/// and geographically plausible for Israel transit services.
nonisolated public enum MOTRouteGeometryPipeline {

    public enum GeometryError: Error, LocalizedError, Sendable {
        case emptySource
        case insufficientPoints(Int)
        case invalidCoordinate(CLLocationCoordinate2D)
        case outOfRegionBounds(CLLocationCoordinate2D)
        case nullIslandCoordinate
        case decodeFailed

        public var errorDescription: String? {
            switch self {
            case .emptySource:
                return "Polyline source string is empty."
            case .insufficientPoints(let count):
                return "Polyline has insufficient points (\(count)); at least 2 required."
            case .invalidCoordinate(let coord):
                return "Polyline contains invalid coordinates: (\(coord.latitude), \(coord.longitude))."
            case .outOfRegionBounds(let coord):
                return "Polyline coordinate is outside Israel service bounds: (\(coord.latitude), \(coord.longitude))."
            case .nullIslandCoordinate:
                return "Polyline coordinate is Null Island (0,0)."
            case .decodeFailed:
                return "Failed to decode polyline string."
            }
        }
    }

    /// Geographical bounds encompassing Israel transit service area (with margin).
    public static let minLatitude: Double = 29.0
    public static let maxLatitude: Double = 33.5
    public static let minLongitude: Double = 34.0
    public static let maxLongitude: Double = 36.0

    /// Decodes an encoded polyline string (HERE Flexible Polyline v1 or Google E5)
    /// into validated coordinates.
    ///
    /// - Parameters:
    ///   - source: Encoded string from Ministry of Transport or external feed.
    ///   - validateBounds: If true, verifies coordinates fall within Israel service area.
    /// - Returns: Validated array of `CLLocationCoordinate2D`.
    /// - Throws: `GeometryError` if string is empty, corrupt, or coordinates are invalid.
    public static func decode(source: String?, validateBounds: Bool = true) throws -> [CLLocationCoordinate2D] {
        guard let source = source?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty else {
            throw GeometryError.emptySource
        }

        let rawCoordinates: [CLLocationCoordinate2D]

        if HEREFlexiblePolylineDecoder.isFlexiblePolyline(source) {
            do {
                rawCoordinates = try HEREFlexiblePolylineDecoder.decode(source)
            } catch {
                throw GeometryError.decodeFailed
            }
        } else {
            rawCoordinates = GooglePolylineEncoder.decode(source)
        }

        guard rawCoordinates.count >= 2 else {
            throw GeometryError.insufficientPoints(rawCoordinates.count)
        }

        try validate(coordinates: rawCoordinates, validateBounds: validateBounds)

        return rawCoordinates
    }

    /// Validates an array of coordinates against finiteness, validity, null island, and optional region bounds.
    public static func validate(coordinates: [CLLocationCoordinate2D], validateBounds: Bool = true) throws {
        guard coordinates.count >= 2 else {
            throw GeometryError.insufficientPoints(coordinates.count)
        }

        for coord in coordinates {
            guard coord.latitude.isFinite, coord.longitude.isFinite,
                  CLLocationCoordinate2DIsValid(coord) else {
                throw GeometryError.invalidCoordinate(coord)
            }

            if abs(coord.latitude) < 0.0001 && abs(coord.longitude) < 0.0001 {
                throw GeometryError.nullIslandCoordinate
            }

            if validateBounds {
                guard coord.latitude >= minLatitude && coord.latitude <= maxLatitude &&
                      coord.longitude >= minLongitude && coord.longitude <= maxLongitude else {
                    throw GeometryError.outOfRegionBounds(coord)
                }
            }
        }
    }

    /// Converts any valid polyline (HERE Flexible or Google) to a Google E5 encoded polyline string.
    /// Returns `nil` if decoding or validation fails.
    public static func toGoogleE5(source: String?, validateBounds: Bool = true) -> String? {
        guard let coordinates = try? decode(source: source, validateBounds: validateBounds) else {
            return nil
        }
        return GooglePolylineEncoder.encode(coordinates)
    }

    /// Encodes an array of coordinates into Google E5 format after validation.
    public static func googleE5(from coordinates: [CLLocationCoordinate2D], validateBounds: Bool = true) throws -> String {
        try validate(coordinates: coordinates, validateBounds: validateBounds)
        return GooglePolylineEncoder.encode(coordinates)
    }
}
