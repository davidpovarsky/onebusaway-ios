//
//  IsraelRouteSearchService.swift
//  IsraelMOT
//
//  Authoritative route search, caching, ranking, and deduplication for Israeli routes.
//

import Foundation
import CoreLocation
import OBAKitCore

public final class IsraelRouteSearchService: @unchecked Sendable {
    public static let shared = IsraelRouteSearchService()

    private var queryCache: [String: [Route]] = [:]
    private let lock = NSLock()

    public init() {}

    /// Normalizes and cleans the search input query.
    public func normalizeQuery(_ raw: String) -> String {
        IsraelRouteQueryNormalizer.normalize(raw)
    }

    /// Retrieves cached search results for a normalized query, if available.
    public func cachedResults(for query: String) -> [Route]? {
        lock.lock()
        defer { lock.unlock() }
        return queryCache[query]
    }

    /// Caches search results for a normalized query.
    public func cacheResults(_ results: [Route], for query: String) {
        lock.lock()
        defer { lock.unlock() }
        queryCache[query] = results
    }

    /// Ranks candidate routes: exact line match first, prefix match second, then standard localized compare.
    public func rankRoutes(_ routes: [Route], for query: String) -> [Route] {
        let target = query.lowercased()
        return routes.sorted { first, second in
            let firstExact = first.shortName.lowercased() == target
            let secondExact = second.shortName.lowercased() == target
            if firstExact != secondExact { return firstExact }

            let firstPrefix = first.shortName.lowercased().hasPrefix(target)
            let secondPrefix = second.shortName.lowercased().hasPrefix(target)
            if firstPrefix != secondPrefix { return firstPrefix }

            return first.shortName.localizedStandardCompare(second.shortName) == .orderedAscending
        }
    }

    /// Clears the in-memory query cache.
    public func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        queryCache.removeAll()
    }
}
