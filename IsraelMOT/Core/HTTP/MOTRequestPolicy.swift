//
//  MOTRequestPolicy.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

/// Request policy defining timeouts, caching headers, and rate limiting rules.
nonisolated public struct MOTRequestPolicy: Sendable {
    public let timeoutInterval: TimeInterval
    public let maxRetryAttempts: Int
    public let maxConcurrentRequests: Int

    public nonisolated init(
        timeoutInterval: TimeInterval = 15.0,
        maxRetryAttempts: Int = 2,
        maxConcurrentRequests: Int = 4
    ) {
        self.timeoutInterval = timeoutInterval
        self.maxRetryAttempts = maxRetryAttempts
        self.maxConcurrentRequests = maxConcurrentRequests
    }

    public nonisolated static let standard = MOTRequestPolicy()
}
