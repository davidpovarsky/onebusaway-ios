//
//  IsraelAppServices.swift
//  OBAKit
//
//  Authoritative composition root for Israeli transit services within OBAKit.
//

import Foundation
import CoreLocation
import OBAKitCore
import IsraelMOT

@MainActor
public final class IsraelAppServices: ObservableObject {
    public static let shared = IsraelAppServices()

    public private(set) var isInitialized: Bool = false
    private weak var application: Application?

    public init() {}

    /// Configures all Israel transit services proactively at application startup.
    public func configure(with application: Application) {
        guard !isInitialized else { return }
        self.application = application
        self.isInitialized = true

        Logger.info("[IsraelAppServices] Initialized Israel transit services composition root.")

        // Proactively configure unified Live Activity lifecycle
        IsraelActivityLifecycleService.shared.configure(
            apiServiceProvider: { [weak application] in application?.apiService },
            userDefaults: application.userDefaults
        )
    }

    /// Resolves the data loader for the active region.
    public func dataLoader(for region: Region?, fallbackLoader: URLDataLoader) -> URLDataLoader {
        IsraelProviderBootstrap.dataLoader(for: region, fallbackLoader: fallbackLoader)
    }
}
