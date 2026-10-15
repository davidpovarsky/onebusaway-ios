//
//  MOTTripPlanningErrorMapper.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

#if canImport(OTPKit)
import OTPKit
#endif

public enum MOTTripPlanningError: LocalizedError, Sendable {
    case wafBlocked(supportID: String?)
    case unsupportedTravelMode(String)
    case serverError(String)
    case noRoutesFound

    public var errorDescription: String? {
        switch self {
        case .wafBlocked(let id):
            let ref = id != nil ? " (מזהה תמיכה: \(id!))" : ""
            return "שירות תכנון המסלול של משרד התחבורה חוסם כרגע פניות ישירות מהאפליקציה (חומת אש F5)\(ref)."
        case .unsupportedTravelMode(let mode):
            return "אמצעי תחבורה זה אינו נתמך במערכת משרד התחבורה בישראל (\(mode))."
        case .serverError(let msg):
            return "שגיאה משרת התחבורה: \(msg)"
        case .noRoutesFound:
            return "לא נמצאו מסלולים בין נקודת המוצא ליעד בזמן המבוקש."
        }
    }
}
