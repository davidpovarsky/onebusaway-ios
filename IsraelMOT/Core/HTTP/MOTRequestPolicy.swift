//
//  MOTRequestPolicy.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

/// Request policy defining timeouts, caching headers, and rate limiting rules.
public struct MOTRequestPolicy: Sendable {
    public let timeoutInterval: TimeInterval
    public let maxRetryAttempts: Int
    public let maxConcurrentRequests: Int

    public init(
        timeoutInterval: TimeInterval = 15.0,
        maxRetryAttempts: Int = 2,
        maxConcurrentRequests: Int = 4
    ) {
        self.timeoutInterval = timeoutInterval
        self.maxRetryAttempts = maxRetryAttempts
        self.maxConcurrentRequests = maxConcurrentRequests
    }

    public static let standard = MOTRequestPolicy()
}
