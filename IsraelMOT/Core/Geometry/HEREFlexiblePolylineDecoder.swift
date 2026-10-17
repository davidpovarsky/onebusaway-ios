//
//  HEREFlexiblePolylineDecoder.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation
import CoreLocation

public enum HEREFlexiblePolylineError: Error, LocalizedError, Sendable {
    case emptyString
    case invalidCharacter(Character)
    case invalidHeader
    case unsupportedVersion(Int)
    case prematureEnd

    public var errorDescription: String? {
        switch self {
        case .emptyString:
            return "Encoded flexible polyline is empty."
        case .invalidCharacter(let char):
            return "Invalid character in flexible polyline: '\(char)'."
        case .invalidHeader:
            return "Invalid flexible polyline header."
        case .unsupportedVersion(let v):
            return "Unsupported flexible polyline format version: \(v)."
        case .prematureEnd:
            return "Flexible polyline ended prematurely."
        }
    }
}

/// Decodes HERE Flexible Polyline v1 format strings into arrays of coordinates.
nonisolated public enum HEREFlexiblePolylineDecoder {
    private static let formatVersion: Int64 = 1

    private static let decodingTable: [Int8] = [
        62, -1, -1, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, -1,
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
        22, 23, 24, 25, -1, -1, -1, -1, 63, -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35,
        36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51
    ]

    public struct Header: Equatable, Sendable {
        public let precision: Int
        public let thirdDimensionType: Int
        public let thirdDimensionPrecision: Int
    }

    /// Checks if an encoded string matches HERE Flexible Polyline signature (version 1).
    public static func isFlexiblePolyline(_ encoded: String) -> Bool {
        guard let first = encoded.first, first == "B" else { return false }
        return (try? decode(encoded)) != nil
    }

    /// Decodes a HERE Flexible Polyline string into `[CLLocationCoordinate2D]`.
    public static func decode(_ encoded: String) throws -> [CLLocationCoordinate2D] {
        guard !encoded.isEmpty else { return [] }

        var index = encoded.startIndex
        func nextUnsigned() throws -> Int64 {
            var result: Int64 = 0
            var shift: Int64 = 0
            while index < encoded.endIndex {
                let char = encoded[index]
                index = encoded.index(after: index)
                guard let ascii = char.asciiValue, ascii >= 45 && ascii <= 122 else {
                    throw HEREFlexiblePolylineError.invalidCharacter(char)
                }
                let val = decodingTable[Int(ascii - 45)]
                guard val >= 0 else {
                    throw HEREFlexiblePolylineError.invalidCharacter(char)
                }
                result |= Int64(val & 0x1F) << shift
                if (val & 0x20) == 0 {
                    return result
                }
                shift += 5
            }
            throw HEREFlexiblePolylineError.prematureEnd
        }

        func toSigned(_ unsignedVal: Int64) -> Int64 {
            let isNegative = (unsignedVal & 1) != 0
            let num = unsignedVal >> 1
            return isNegative ? ~num : num
        }

        // 1. Decode Header
        let version = try nextUnsigned()
        guard version == formatVersion else {
            throw HEREFlexiblePolylineError.unsupportedVersion(Int(version))
        }

        let headerVal = try nextUnsigned()
        let precision = Int(headerVal & 0x0F)
        let thirdDim = Int((headerVal >> 4) & 0x07)

        let factorDegree = pow(10.0, Double(precision))

        var lastLat: Int64 = 0
        var lastLng: Int64 = 0
        var lastZ: Int64 = 0

        var coordinates: [CLLocationCoordinate2D] = []

        while index < encoded.endIndex {
            let deltaLat = toSigned(try nextUnsigned())
            let deltaLng = toSigned(try nextUnsigned())
            if thirdDim != 0 {
                let deltaZ = toSigned(try nextUnsigned())
                lastZ += deltaZ
            }

            lastLat += deltaLat
            lastLng += deltaLng

            let lat = Double(lastLat) / factorDegree
            let lng = Double(lastLng) / factorDegree
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }

        return coordinates
    }
}
