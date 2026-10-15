//
//  MOTBackoff.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

/// Exponential backoff calculator with jitter to prevent server stampedes.
public struct MOTBackoff: Sendable {
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let multiplier: Double

    public nonisolated init(baseDelay: TimeInterval = 0.5, maxDelay: TimeInterval = 10.0, multiplier: Double = 2.0) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
    }

    public nonisolated func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let exponential = baseDelay * pow(multiplier, Double(attempt - 1))
        let capped = min(maxDelay, exponential)
        // Add +/- 20% random jitter
        let jitter = capped * Double.random(in: 0.8...1.2)
        return jitter
    }
}
