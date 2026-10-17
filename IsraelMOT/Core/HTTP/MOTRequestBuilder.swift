//
//  MOTRequestBuilder.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

nonisolated public enum MOTHeaderProfile: Sendable {
    case planner
    case scheduler
    case `default`

    public var origin: String? {
        switch self {
        case .planner:
            return "https://route.bus.gov.il"
        case .scheduler:
            return "https://bus.gov.il"
        case .default:
            return nil
        }
    }

    public var referer: String? {
        switch self {
        case .planner:
            return "https://route.bus.gov.il/"
        case .scheduler:
            return "https://bus.gov.il/"
        case .default:
            return nil
        }
    }
}

nonisolated public enum MOTRequestBuilder {
    public static let userAgent = "OneBusAway/1.0 (iOS; Israel-MOT)"
    public static let accept = "application/json, text/plain, */*"
    public static let acceptLanguage = "he-IL,he;q=0.9,en-US;q=0.8,en;q=0.7"

    public static func buildRequest(
        url: URL,
        method: String = "GET",
        profile: MOTHeaderProfile = .default,
        body: Data? = nil,
        timeoutInterval: TimeInterval = 15.0
    ) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeoutInterval)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(acceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        if let origin = profile.origin {
            request.setValue(origin, forHTTPHeaderField: "Origin")
        }
        if let referer = profile.referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        return request
    }
}
