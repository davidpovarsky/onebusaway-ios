//
//  MOTSearchLineDTO.swift
//  IsraelMOT
//
//  Route suggestions returned by AutoComplete/SearchLines.
//

import Foundation

nonisolated public struct MOTSearchLinesServiceResponse: Decodable, Sendable {
    public let data: [MOTSearchLineDTO]?
    public let success: Bool
    public let message: String?
}

nonisolated public struct MOTSearchLineDTO: Decodable, Sendable {
    public let routeId: Int
    public let agencyId: Int
    public let agencyName: String?
    public let routeName: String
    public let routeLongName: String?
    public let cityName: String?

    public func toTransitRouteSummary() -> TransitRouteSummary {
        let description = [routeLongName, cityName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return TransitRouteSummary(
            routeID: MOTRouteID(rawValue: routeId),
            lineName: routeName,
            destinationName: description.isEmpty ? routeName : description,
            agencyID: MOTAgencyID(rawValue: agencyId),
            agencyName: agencyName
        )
    }
}
