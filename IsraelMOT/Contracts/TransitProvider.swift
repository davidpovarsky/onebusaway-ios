//
//  TransitProvider.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (Multi-Provider Architecture)
//

import Foundation
import Combine

/// Strongly-typed provider identifiers.
public struct TransitProviderID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static let israelMOT = TransitProviderID("israel-mot")
    public static let oneBusAwayNative = TransitProviderID("onebusaway-native")
    public static let busNearby = TransitProviderID("bus-nearby")
}

/// Runtime status of a specific capability.
public enum CapabilityStatus: Hashable, Codable, Sendable {
    case supported
    case unsupported
    case degraded(reason: String)
    case temporarilyUnavailable(reason: String)
    case futurePlaceholder(description: String)

    public var isSupported: Bool {
        switch self {
        case .supported, .degraded:
            return true
        default:
            return false
        }
    }
}

/// Granular capabilities descriptor for transit data providers.
public struct TransitProviderCapabilities: Hashable, Codable, Sendable {
    public var nearbyStops: CapabilityStatus
    public var mapViewportStops: CapabilityStatus
    public var searchLines: CapabilityStatus
    public var routeDetails: CapabilityStatus
    public var routeStops: CapabilityStatus
    public var scheduleByRoute: CapabilityStatus
    public var planJourney: CapabilityStatus
    public var arriveBy: CapabilityStatus
    public var routePreferences: CapabilityStatus
    public var predictions: CapabilityStatus
    public var vehicleLocations: CapabilityStatus
    public var serviceAlerts: CapabilityStatus
    public var fares: CapabilityStatus
    public var accessibility: CapabilityStatus

    public init(
        nearbyStops: CapabilityStatus = .unsupported,
        mapViewportStops: CapabilityStatus = .unsupported,
        searchLines: CapabilityStatus = .unsupported,
        routeDetails: CapabilityStatus = .unsupported,
        routeStops: CapabilityStatus = .unsupported,
        scheduleByRoute: CapabilityStatus = .unsupported,
        planJourney: CapabilityStatus = .unsupported,
        arriveBy: CapabilityStatus = .unsupported,
        routePreferences: CapabilityStatus = .unsupported,
        predictions: CapabilityStatus = .unsupported,
        vehicleLocations: CapabilityStatus = .unsupported,
        serviceAlerts: CapabilityStatus = .unsupported,
        fares: CapabilityStatus = .unsupported,
        accessibility: CapabilityStatus = .unsupported
    ) {
        self.nearbyStops = nearbyStops
        self.mapViewportStops = mapViewportStops
        self.searchLines = searchLines
        self.routeDetails = routeDetails
        self.routeStops = routeStops
        self.scheduleByRoute = scheduleByRoute
        self.planJourney = planJourney
        self.arriveBy = arriveBy
        self.routePreferences = routePreferences
        self.predictions = predictions
        self.vehicleLocations = vehicleLocations
        self.serviceAlerts = serviceAlerts
        self.fares = fares
        self.accessibility = accessibility
    }

    /// Capabilities of the Israel Ministry of Transport (MOT) provider.
    /// Note: mapViewportStops is served locally via IsraelStopCatalogRepository.
    public static let israelMOT = TransitProviderCapabilities(
        nearbyStops: .supported,
        mapViewportStops: .supported, // Provided locally by IsraelStopCatalogRepository
        searchLines: .supported,
        routeDetails: .supported,
        routeStops: .supported,
        scheduleByRoute: .supported,
        planJourney: .supported,
        arriveBy: .supported,
        routePreferences: .supported,
        predictions: .supported,
        vehicleLocations: .degraded(reason: "Single-bus real-time route location when reported"),
        serviceAlerts: .supported,
        fares: .supported,
        accessibility: .supported
    )

    /// Native OneBusAway REST API capabilities.
    public static let oneBusAwayNative = TransitProviderCapabilities(
        nearbyStops: .supported,
        mapViewportStops: .supported,
        searchLines: .supported,
        routeDetails: .supported,
        routeStops: .supported,
        scheduleByRoute: .supported,
        planJourney: .supported,
        arriveBy: .supported,
        routePreferences: .supported,
        predictions: .supported,
        vehicleLocations: .supported,
        serviceAlerts: .supported,
        fares: .unsupported,
        accessibility: .supported
    )

    /// Placeholder capabilities for future Bus Nearby provider.
    public static let busNearbyPlaceholder = TransitProviderCapabilities(
        nearbyStops: .futurePlaceholder(description: "Awaiting API specification and contract testing"),
        mapViewportStops: .supported, // Shared local catalog
        searchLines: .futurePlaceholder(description: "Not yet implemented"),
        routeDetails: .futurePlaceholder(description: "Not yet implemented"),
        routeStops: .futurePlaceholder(description: "Not yet implemented"),
        scheduleByRoute: .futurePlaceholder(description: "Not yet implemented"),
        planJourney: .futurePlaceholder(description: "Not yet implemented"),
        arriveBy: .futurePlaceholder(description: "Not yet implemented"),
        routePreferences: .futurePlaceholder(description: "Not yet implemented"),
        predictions: .futurePlaceholder(description: "Not yet implemented"),
        vehicleLocations: .futurePlaceholder(description: "Not yet implemented"),
        serviceAlerts: .futurePlaceholder(description: "Not yet implemented"),
        fares: .futurePlaceholder(description: "Not yet implemented"),
        accessibility: .futurePlaceholder(description: "Not yet implemented")
    )
}

/// Metadata and descriptor for a transit provider.
public struct TransitProviderDescriptor: Identifiable, Hashable, Sendable {
    public var id: TransitProviderID
    public var displayName: String
    public var localizedDescription: String
    public var dataSourceAttribution: String
    public var isAvailable: Bool
    public var isExperimental: Bool
    public var capabilities: TransitProviderCapabilities
    public var statusMessage: String?

    public init(
        id: TransitProviderID,
        displayName: String,
        localizedDescription: String,
        dataSourceAttribution: String,
        isAvailable: Bool,
        isExperimental: Bool,
        capabilities: TransitProviderCapabilities,
        statusMessage: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.localizedDescription = localizedDescription
        self.dataSourceAttribution = dataSourceAttribution
        self.isAvailable = isAvailable
        self.isExperimental = isExperimental
        self.capabilities = capabilities
        self.statusMessage = statusMessage
    }
}

extension Notification.Name {
    public static let transitProviderDidChange = Notification.Name("org.onebusaway.israel.transitProviderDidChange")
}

/// Registry of known transit providers and capability provider for the app.
nonisolated public final class TransitProviderRegistry: @unchecked Sendable {
    nonisolated public static let shared = TransitProviderRegistry()

    private let lock = NSLock()
    private var providers: [TransitProviderID: TransitProviderDescriptor] = [:]

    private init() {
        registerDefaultProviders()
    }

    private func registerDefaultProviders() {
        // 1. Israel Ministry of Transport (Active primary provider)
        let mot = TransitProviderDescriptor(
            id: .israelMOT,
            displayName: "משרד התחבורה (ישראל)",
            localizedDescription: "נתוני לוחות זמנים, תכנון מסלול, זמני הגעה וחיפוש קווים משרתי משרד התחבורה הרשמיים ומאגר תחנות ארצי מקומי.",
            dataSourceAttribution: "משרד התחבורה / הרשות הארצית לתחבורה ציבורית",
            isAvailable: true,
            isExperimental: false,
            capabilities: .israelMOT,
            statusMessage: "פעיל"
        )
        providers[.israelMOT] = mot

        // 2. Bus Nearby (Future integration placeholder)
        let busNearby = TransitProviderDescriptor(
            id: .busNearby,
            displayName: "Bus Nearby (ספק עתידי)",
            localizedDescription: "שילוב עתידי של שירות Bus Nearby. הספק אינו פעיל עד להשלמת מחקר החוזים והאימות הטכני.",
            dataSourceAttribution: "Bus Nearby (ממתין לאינטגרציה)",
            isAvailable: false,
            isExperimental: true,
            capabilities: .busNearbyPlaceholder,
            statusMessage: "ממתין למימוש חוזה ואימות טכני"
        )
        providers[.busNearby] = busNearby

        // 3. OneBusAway Native (Stock fallback for OBA servers)
        let oba = TransitProviderDescriptor(
            id: .oneBusAwayNative,
            displayName: "OneBusAway Native REST API",
            localizedDescription: "שרת OneBusAway קלאסי מבוסס פרוטוקול REST של OBAKit.",
            dataSourceAttribution: "OneBusAway Community",
            isAvailable: true,
            isExperimental: false,
            capabilities: .oneBusAwayNative,
            statusMessage: "זמין לאזורי חו\"ל"
        )
        providers[.oneBusAwayNative] = oba
    }

    public func allProviders() -> [TransitProviderDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return Array(providers.values).sorted { $0.displayName < $1.displayName }
    }

    public var allProviders: [TransitProviderDescriptor] {
        return allProviders()
    }

    public func provider(for id: TransitProviderID) -> TransitProviderDescriptor? {
        lock.lock()
        defer { lock.unlock() }
        return providers[id]
    }

    public func register(descriptor: TransitProviderDescriptor) {
        lock.lock()
        defer { lock.unlock() }
        providers[descriptor.id] = descriptor
    }
}

/// Observable store managing provider selection and persistence.
@MainActor
public final class TransitProviderSelectionStore: ObservableObject {
    public static let shared = TransitProviderSelectionStore()

    public static let userDefaultsKey = "org.onebusaway.israel.selected_provider"

    nonisolated public static func currentProviderID() -> TransitProviderID {
        if let savedRaw = UserDefaults.standard.string(forKey: userDefaultsKey) {
            return TransitProviderID(savedRaw)
        }
        return .israelMOT
    }

    @Published public private(set) var activeProviderID: TransitProviderID {
        didSet {
            UserDefaults.standard.set(activeProviderID.rawValue, forKey: Self.userDefaultsKey)
            NotificationCenter.default.post(name: .transitProviderDidChange, object: activeProviderID)
        }
    }

    @Published public private(set) var activeDescriptor: TransitProviderDescriptor

    private init() {
        let registry = TransitProviderRegistry.shared
        if let savedRaw = UserDefaults.standard.string(forKey: Self.userDefaultsKey) {
            let savedID = TransitProviderID(savedRaw)
            if let desc = registry.provider(for: savedID), desc.isAvailable {
                self.activeProviderID = savedID
                self.activeDescriptor = desc
                return
            }
        }

        // Default to Israel MOT
        self.activeProviderID = .israelMOT
        self.activeDescriptor = registry.provider(for: .israelMOT)!
    }

    public func selectProvider(_ id: TransitProviderID) -> Bool {
        guard let descriptor = TransitProviderRegistry.shared.provider(for: id) else {
            return false
        }
        guard descriptor.isAvailable else {
            // Cannot activate disabled future provider
            return false
        }

        self.activeProviderID = id
        self.activeDescriptor = descriptor
        return true
    }

    public func isFeatureSupported(_ keyPath: KeyPath<TransitProviderCapabilities, CapabilityStatus>) -> Bool {
        let status = activeDescriptor.capabilities[keyPath: keyPath]
        return status.isSupported
    }
}
