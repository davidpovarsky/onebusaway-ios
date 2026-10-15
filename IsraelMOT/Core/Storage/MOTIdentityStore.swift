//
//  MOTIdentityStore.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

/// Thread-safe identity store mapping between MOT stop codes, internal stop IDs, and OBA composite IDs.
public actor MOTIdentityStore {
    private var codeToInternal: [MOTStopCode: MOTStopInternalID] = [:]
    private var internalToCode: [MOTStopInternalID: MOTStopCode] = [:]

    public init() {}

    public func register(code: MOTStopCode, internalID: MOTStopInternalID) {
        codeToInternal[code] = internalID
        internalToCode[internalID] = code
    }

    public func internalID(for code: MOTStopCode) -> MOTStopInternalID? {
        return codeToInternal[code]
    }

    public func code(for internalID: MOTStopInternalID) -> MOTStopCode? {
        return internalToCode[internalID]
    }
}
