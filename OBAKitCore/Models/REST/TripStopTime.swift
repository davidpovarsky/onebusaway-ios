//
//  TripStopTime.swift
//  OBAKitCore
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation

public class TripStopTime: NSObject, Decodable, HasReferences {

    /// Time, in seconds since the start of the service date, when the trip arrives at the specified stop.
    /// Nil or negative indicates an unknown / unreported stop time.
    private let arrival: TimeInterval?

    public private(set) var arrivalDate: Date?

    /// Time, in seconds since the start of the service date, when the trip departs the specified stop.
    /// Nil or negative indicates an unknown / unreported stop time.
    private let departure: TimeInterval?

    public private(set) var departureDate: Date?

    /// The stop id of the stop visited during the trip
    public let stopID: StopID

    /// The stop visited during the trip.
    public private(set) var stop: Stop!

    var serviceDate: Date! {
        didSet {
            guard let serviceDate = serviceDate else {
                arrivalDate = nil
                departureDate = nil
                return
            }
            if let arr = arrival, arr >= 0 {
                arrivalDate = Calendar.current.date(byAdding: .second, value: Int(arr), to: serviceDate)
            } else {
                arrivalDate = nil
            }
            if let dep = departure, dep >= 0 {
                departureDate = Calendar.current.date(byAdding: .second, value: Int(dep), to: serviceDate)
            } else {
                departureDate = nil
            }
        }
    }

    public private(set) var regionIdentifier: Int?

    private enum CodingKeys: String, CodingKey {
        case arrival = "arrivalTime"
        case departure = "departureTime"
        case stopID = "stopId"
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        arrival = try container.decodeIfPresent(TimeInterval.self, forKey: .arrival)
        departure = try container.decodeIfPresent(TimeInterval.self, forKey: .departure)
        stopID = try container.decode(String.self, forKey: .stopID)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? TripStopTime else { return false }

        return
            arrival == rhs.arrival &&
            departure == rhs.departure &&
            regionIdentifier == rhs.regionIdentifier &&
            stopID == rhs.stopID
    }

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(arrival)
        hasher.combine(departure)
        hasher.combine(regionIdentifier)
        hasher.combine(stopID)
        return hasher.finalize()
    }

    public func loadReferences(_ references: References, regionIdentifier: Int?) {
        stop = references.stopWithID(stopID)!
        self.regionIdentifier = regionIdentifier
    }
}
