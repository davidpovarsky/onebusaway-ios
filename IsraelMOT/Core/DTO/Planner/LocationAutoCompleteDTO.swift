//
//  LocationAutoCompleteDTO.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

nonisolated public struct LocationAutoCompleteDTOServiceResponse: Codable, Sendable {
    public let data: [LocationAutoCompleteDTO]?
    public let success: Bool
    public let message: String?
}

nonisolated public struct LocationAutoCompleteDTO: Codable, Sendable {
    public let title: String
    public let id: String?
    public let addressDetails: AddressLocationDTO?
    public let coordinates: CoordinateDTO?
    public let isStop: Bool?
    public let isPoi: Bool?
    public let isCity: Bool?
}

nonisolated public struct AddressLocationDTO: Codable, Sendable {
    public let label: String?
    public let countryName: String?
    public let city: String?
    public let street: String?
    public let houseNumber: String?
}

nonisolated public struct CoordinateDTO: Codable, Sendable {
    public let lat: Double
    public let lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}
