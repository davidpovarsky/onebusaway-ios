//
//  MOTSectionModeMapper.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

#if canImport(OTPKit)
import OTPKit
#endif

nonisolated public enum MOTSectionModeMapper {
    public static func isWalkSection(_ section: SectionDTO) -> Bool {
        let type = section.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if type == "pedestrian" || type == "walk" {
            return true
        }
        let mode = section.transport?.mode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if mode == "pedestrian" || mode == "walk" {
            return true
        }
        return section.transport == nil
    }

    public static func modeString(for section: SectionDTO) -> String {
        if isWalkSection(section) {
            return "WALK"
        }
        guard let mode = section.transport?.mode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return "BUS"
        }
        switch mode {
        case "bus", "privatebus":
            return "BUS"
        case "lightrail", "tram":
            return "TRAM"
        case "regionaltrain", "train":
            return "RAIL"
        case "subway", "carmelit":
            return "SUBWAY"
        case "cablecar", "gondola", "rahbalit":
            return "CABLE_CAR"
        default:
            return mode.uppercased()
        }
    }

    #if canImport(OTPKit)
    public static func routeType(for section: SectionDTO) -> RouteType {
        if isWalkSection(section) {
            return .nonTransit
        }
        let mode = modeString(for: section)
        switch mode {
        case "TRAM":
            return .tram
        case "RAIL":
            return .train
        case "SUBWAY":
            return .subway
        case "CABLE_CAR":
            return .cableCar
        default:
            return .bus
        }
    }
    #endif
}
