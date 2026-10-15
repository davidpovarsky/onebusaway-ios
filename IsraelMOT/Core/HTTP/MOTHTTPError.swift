//
//  MOTHTTPError.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

/// Specific errors returned or detected when interacting with the MOT transit API.
public enum MOTHTTPError: LocalizedError, Sendable {
    /// The request was rejected by the F5 Web Application Firewall (HTTP 403 Forbidden).
    case wafBlocked(supportID: String?)

    /// The remote endpoint returned HTTP 503 Service Unavailable.
    case serviceUnavailable(statusCode: Int, message: String?)

    /// The remote endpoint returned HTTP 429 Too Many Requests.
    case rateLimited(retryAfterSeconds: Int?)

    /// HTTP response status code indicates an error.
    case httpError(statusCode: Int, responseBody: String?)

    /// Missing or invalid JSON response.
    case invalidResponse(expected: String, actual: String?)

    /// Service returned success: false with an error message.
    case serviceError(message: String)

    /// JSON decoding failed.
    case decodingError(message: String)

    /// General underlying network connection failure.
    case networkFailure(message: String)

    public var errorDescription: String? {
        switch self {
        case .wafBlocked(let id):
            let ref = id != nil ? " (מזהה תמיכה: \(id!))" : ""
            return "הגישה לשירות תכנון המסלול נחסמה ע״י שרתי משרד התחבורה (חומת אש F5)\(ref)."
        case .serviceUnavailable(let code, _):
            return "שרת משרד התחבורה אינו זמין זמנית (קוד שגיאה \(code))."
        case .rateLimited(let sec):
            let wait = sec != nil ? " אנא המתן \(sec!) שניות." : ""
            return "נשלחו יותר מדי בקשות בזמן קצר.\(wait)"
        case .httpError(let code, _):
            return "שגיאת תקשורת מול שרת משרד התחבורה (קוד \(code))."
        case .invalidResponse(let exp, let act):
            return "התקבלה תשובה לא תקינה מהשרת (צפוי: \(exp), התקבל: \(act ?? "ריק"))."
        case .serviceError(let msg):
            return msg.isEmpty ? "שגיאה בעיבוד הבקשה בשרת משרד התחבורה." : msg
        case .decodingError(let msg):
            return "שגיאה בפענוח נתוני התחבורה: \(msg)"
        case .networkFailure(let msg):
            return "שגיאת חיבור לרשת: \(msg)"
        }
    }
}
