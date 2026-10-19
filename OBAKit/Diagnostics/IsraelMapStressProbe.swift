//
//  IsraelMapStressProbe.swift
//  OBAKit
//
//  Created for OneBusAway Israel Map Zoom Stress Diagnostics
//

#if DEBUG
import Foundation
import UIKit
import CoreLocation
import MapKit
import OBAKitCore
import IsraelMOT

/// Diagnostic probe for the automated Israel map zoom stress reproduction.
/// Active ONLY in DEBUG builds when `ISRAEL_MAP_STRESS_TEST=1` is passed in the environment.
public final class IsraelMapStressProbe: @unchecked Sendable {
    public static let shared = IsraelMapStressProbe()
    public static let statusAccessibilityIdentifier = "israel.map.stress.status"

    public static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["ISRAEL_MAP_STRESS_TEST"] == "1"
    }

    private let lock = NSLock()
    public private(set) var mapMode: String = "unknown"
    public private(set) var regionID: Int = 0
    public private(set) var providerID: String = "none"
    public private(set) var centerLatitude: Double = 0.0
    public private(set) var centerLongitude: Double = 0.0
    public private(set) var latitudeSpan: Double = 0.0
    public private(set) var longitudeSpan: Double = 0.0
    public private(set) var visibleMapRectHeight: Double = 0.0
    public private(set) var catalogAvailable: Bool = false
    public private(set) var loadedStopsCount: Int = 0
    public private(set) var renderedStopsCount: Int = 0
    public private(set) var pendingRequests: Int = 0
    public private(set) var lastCameraSettledAt: TimeInterval = 0.0

    /// Returns resident memory in megabytes for the current process.
    public var memoryFootprintMB: Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024.0 * 1024.0)
        }
        return 0.0
    }

    public func serializedStatus() -> String {
        lock.lock()
        defer { lock.unlock() }
        let mem = String(format: "%.1f", memoryFootprintMB)
        let cLat = String(format: "%.6f", centerLatitude)
        let cLon = String(format: "%.6f", centerLongitude)
        let latSp = String(format: "%.6f", latitudeSpan)
        let lonSp = String(format: "%.6f", longitudeSpan)
        let rectH = String(format: "%.1f", visibleMapRectHeight)
        let settled = String(format: "%.3f", lastCameraSettledAt)

        return "mapMode=\(mapMode);" +
               "regionID=\(regionID);" +
               "providerID=\(providerID);" +
               "centerLatitude=\(cLat);" +
               "centerLongitude=\(cLon);" +
               "latitudeSpan=\(latSp);" +
               "longitudeSpan=\(lonSp);" +
               "visibleMapRectHeight=\(rectH);" +
               "catalogAvailable=\(catalogAvailable);" +
               "loadedStopsCount=\(loadedStopsCount);" +
               "renderedStopsCount=\(renderedStopsCount);" +
               "pendingRequests=\(pendingRequests);" +
               "memoryFootprintMB=\(mem);" +
               "lastCameraSettledAt=\(settled)"
    }

    public func update(
        mapMode: String? = nil,
        regionID: Int? = nil,
        providerID: String? = nil,
        centerLatitude: Double? = nil,
        centerLongitude: Double? = nil,
        latitudeSpan: Double? = nil,
        longitudeSpan: Double? = nil,
        visibleMapRectHeight: Double? = nil,
        catalogAvailable: Bool? = nil,
        loadedStopsCount: Int? = nil,
        renderedStopsCount: Int? = nil,
        pendingRequests: Int? = nil
    ) {
        guard Self.isEnabled else { return }
        lock.lock()
        if let mapMode = mapMode { self.mapMode = mapMode }
        if let regionID = regionID { self.regionID = regionID }
        if let providerID = providerID { self.providerID = providerID }
        if let centerLatitude = centerLatitude { self.centerLatitude = centerLatitude }
        if let centerLongitude = centerLongitude { self.centerLongitude = centerLongitude }
        if let latitudeSpan = latitudeSpan { self.latitudeSpan = latitudeSpan }
        if let longitudeSpan = longitudeSpan { self.longitudeSpan = longitudeSpan }
        if let visibleMapRectHeight = visibleMapRectHeight { self.visibleMapRectHeight = visibleMapRectHeight }
        if let catalogAvailable = catalogAvailable { self.catalogAvailable = catalogAvailable }
        if let loadedStopsCount = loadedStopsCount { self.loadedStopsCount = loadedStopsCount }
        if let renderedStopsCount = renderedStopsCount { self.renderedStopsCount = renderedStopsCount }
        if let pendingRequests = pendingRequests { self.pendingRequests = pendingRequests }
        self.lastCameraSettledAt = Date().timeIntervalSince1970
        let statusString = serializedStatus()
        lock.unlock()

        print("ISRAEL_MAP_STRESS: \(statusString)")
    }
}
#endif
