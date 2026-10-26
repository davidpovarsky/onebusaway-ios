//
//  RouteDirectionLabelResolver.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation
import OBAKitCore

/// Bridge forwarding to the extracted `IsraelRouteDirectionFormatter` in IsraelMOT.
public struct RouteDirectionLabelResolver: Sendable, Equatable {
    public let destination: String
    public let origin: String?

    public init(headsign: String, routeLongName: String? = nil) {
        let result = IsraelRouteDirectionFormatter.format(headsign: headsign, routeLongName: routeLongName)
        self.destination = result.destination
        self.origin = result.origin
    }
}
