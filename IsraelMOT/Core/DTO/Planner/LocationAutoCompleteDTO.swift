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

    public init(
        title: String,
        id: String? = nil,
        addressDetails: AddressLocationDTO? = nil,
        coordinates: CoordinateDTO? = nil,
        isStop: Bool? = nil,
        isPoi: Bool? = nil,
        isCity: Bool? = nil
    ) {
        self.title = title
        self.id = id
        self.addressDetails = addressDetails
        self.coordinates = coordinates
        self.isStop = isStop
        self.isPoi = isPoi
        self.isCity = isCity
    }
}

nonisolated public struct AddressLocationDTO: Codable, Sendable {
    public let label: String?
    public let countryName: String?
    public let city: String?
    public let street: String?
    public let houseNumber: String?

    public init(
        label: String? = nil,
        countryName: String? = nil,
        city: String? = nil,
        street: String? = nil,
        houseNumber: String? = nil
    ) {
        self.label = label
        self.countryName = countryName
        self.city = city
        self.street = street
        self.houseNumber = houseNumber
    }
}

nonisolated public struct CoordinateDTO: Codable, Sendable {
    public let lat: Double
    public let lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}
