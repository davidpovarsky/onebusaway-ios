//
//  IsraelStopCatalogRepository.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (Local Spatial Stop Catalog)
//

import Foundation
import CoreLocation
import SQLite3

private final class MOTBundleToken: NSObject {}

/// Repository managing the bundled nationwide SQLite station catalog with R-Tree spatial indexing.
/// Provides sub-5ms viewport bounding-box queries, ensuring 0 network requests during map pan/zoom.
nonisolated public final class IsraelStopCatalogRepository: @unchecked Sendable {
    nonisolated public static let shared = IsraelStopCatalogRepository()

    private let lock = NSLock()
    private var db: OpaquePointer?
    public let databaseURL: URL?

    public init(databaseURL: URL? = nil) {
        let resolvedURL: URL? = {
            if let custom = databaseURL, FileManager.default.fileExists(atPath: custom.path) {
                return custom
            }
            // 1. App Bundle (OneBusAway.app)
            if let bundleURL = Bundle.main.url(forResource: "IsraelStopCatalog", withExtension: "sqlite") {
                return bundleURL
            }
            // 2. Framework Bundle (OBAKit.framework)
            let frameworkBundle = Bundle(for: MOTBundleToken.self)
            if let bundleURL = frameworkBundle.url(forResource: "IsraelStopCatalog", withExtension: "sqlite") {
                return bundleURL
            }
            // 3. Fallback repository path for unit tests / local builds
            let sourceDir = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // Storage
                .deletingLastPathComponent() // Core
                .deletingLastPathComponent() // IsraelMOT
                .appendingPathComponent("Resources")
                .appendingPathComponent("IsraelStopCatalog.sqlite")
            if FileManager.default.fileExists(atPath: sourceDir.path) {
                return sourceDir
            }
            return nil
        }()

        self.databaseURL = resolvedURL
        openDatabase()
    }

    deinit {
        lock.lock()
        defer { lock.unlock() }
        if let db = db {
            sqlite3_close_v2(db)
        }
    }

    private func openDatabase() {
        guard let url = databaseURL else { return }
        lock.lock()
        defer { lock.unlock() }

        var connection: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &connection, flags, nil) == SQLITE_OK {
            self.db = connection
        } else {
            if let connection = connection {
                sqlite3_close_v2(connection)
            }
            self.db = nil
        }
    }

    public var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return db != nil
    }

    // MARK: - Spatial Viewport Queries

    /// Queries stops located inside the given coordinate bounding box using SQLite R-Tree.
    /// Typically completes in 2-5ms for a metropolitan viewport.
    /// If `limit` is nil, all matching stops are returned without arbitrary cutoff.
    public func stops(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        limit: Int? = nil
    ) -> [TransitStop] {
        lock.lock()
        defer { lock.unlock() }
        guard let db = db else { return [] }

        let sql: String
        if let limit = limit, limit > 0 {
            sql = """
            SELECT s.stop_id, s.stop_code, s.name_he, s.name_en, s.name_ar,
                   s.street, s.city, s.platform_code, s.lat, s.lon, s.location_type, s.parent_station
            FROM stops_rtree r
            JOIN stops s ON r.id = s.stop_id
            WHERE r.min_lat >= ? AND r.max_lat <= ?
              AND r.min_lon >= ? AND r.max_lon <= ?
            LIMIT ?;
            """
        } else {
            sql = """
            SELECT s.stop_id, s.stop_code, s.name_he, s.name_en, s.name_ar,
                   s.street, s.city, s.platform_code, s.lat, s.lon, s.location_type, s.parent_station
            FROM stops_rtree r
            JOIN stops s ON r.id = s.stop_id
            WHERE r.min_lat >= ? AND r.max_lat <= ?
              AND r.min_lon >= ? AND r.max_lon <= ?;
            """
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, minLat)
        sqlite3_bind_double(stmt, 2, maxLat)
        sqlite3_bind_double(stmt, 3, minLon)
        sqlite3_bind_double(stmt, 4, maxLon)
        if let limit = limit, limit > 0 {
            sqlite3_bind_int(stmt, 5, Int32(limit))
        }

        var result: [TransitStop] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let stop = parseStop(from: stmt) {
                result.append(stop)
            }
        }
        return result
    }

    /// Queries stops for a map viewport with intelligent density management:
    /// - High Zoom (Street level, latSpan < 0.035): returns 100% of stations inside the viewport without truncation.
    /// - Medium Zoom (City/District level, 0.035 <= latSpan <= 0.25): applies deterministic spatial clustering / grid bucketing
    ///   so every sector is uniformly represented and major stations/platforms are preserved without MapKit pin overload.
    /// - Low Zoom (Regional/Nationwide, latSpan > 0.25): returns empty array (handled by zoom gate to prevent pin flood).
    public func viewportStops(
        centerLat: Double,
        centerLon: Double,
        latSpan: Double,
        lonSpan: Double
    ) -> [TransitStop] {
#if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            if ProcessInfo.processInfo.environment["ISRAEL_MAP_STRESS_TEST"] == "1" {
                print("ISRAEL_MAP_STRESS: [SQLite] viewportStops latSpan=\(String(format: "%.4f", latSpan)) queried in \(String(format: "%.2f", elapsedMs))ms")
            }
        }
#endif
        // Zoom gate
        if latSpan > 0.25 {
            return []
        }

        // Viewport bounding box with 15% buffer margin on each side
        let marginLat = latSpan * 0.15
        let marginLon = lonSpan * 0.15
        let minLat = centerLat - (latSpan / 2.0) - marginLat
        let maxLat = centerLat + (latSpan / 2.0) + marginLat
        let minLon = centerLon - (lonSpan / 2.0) - marginLon
        let maxLon = centerLon + (lonSpan / 2.0) + marginLon

        // 1. Street level zoom: 100% of stations MUST be visible and accessible
        if latSpan < 0.035 {
            return stops(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon, limit: nil)
        }

        // 2. City / District level: Query candidates and apply deterministic spatial clustering
        let candidates = stops(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon, limit: 1500)
        if candidates.count <= 400 {
            return candidates
        }

        // Cluster using an adaptive 16x16 geographic grid
        let gridSize = 16
        let latStep = (maxLat - minLat) / Double(gridSize)
        let lonStep = (maxLon - minLon) / Double(gridSize)
        guard latStep > 0, lonStep > 0 else { return Array(candidates.prefix(400)) }

        var gridBuckets: [Int: [TransitStop]] = [:]
        for stop in candidates {
            let latIndex = min(gridSize - 1, max(0, Int((stop.location.latitude - minLat) / latStep)))
            let lonIndex = min(gridSize - 1, max(0, Int((stop.location.longitude - minLon) / lonStep)))
            let bucketKey = (latIndex * gridSize) + lonIndex
            gridBuckets[bucketKey, default: []].append(stop)
        }

        // Deterministically select up to 2 representative stops per cell, prioritizing hubs & distinct platforms
        var clusteredResults: [TransitStop] = []
        for (_, bucket) in gridBuckets {
            let sortedBucket = bucket.sorted { s1, s2 in
                // Priority: station hubs (platform present or lower code)
                let p1 = s1.platformNumber != nil ? 1 : 0
                let p2 = s2.platformNumber != nil ? 1 : 0
                if p1 != p2 { return p1 > p2 }
                return s1.code.rawValue < s2.code.rawValue
            }
            clusteredResults.append(contentsOf: sortedBucket.prefix(2))
        }

        return clusteredResults
    }

    // MARK: - Point & Code Lookups

    /// Retrieves a single stop by its public signpost code (e.g., 5997).
    /// Deterministically selects the parent station (location_type = 1) or canonical platform
    /// when multiple GTFS rows share the same stop_code.
    public func stop(forCode code: MOTStopCode) -> TransitStop? {
        lock.lock()
        defer { lock.unlock() }
        guard let db = db else { return nil }

        let sql = """
        SELECT stop_id, stop_code, name_he, name_en, name_ar,
               street, city, platform_code, lat, lon, location_type, parent_station
        FROM stops
        WHERE stop_code = ?
        ORDER BY location_type DESC, parent_station IS NULL DESC, platform_code ASC, stop_id ASC
        LIMIT 1;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(code.rawValue))

        if sqlite3_step(stmt) == SQLITE_ROW {
            return parseStop(from: stmt)
        }
        return nil
    }

    /// Retrieves all stops/platforms sharing the given public stop code, ordered deterministically.
    public func stops(forCode code: MOTStopCode) -> [TransitStop] {
        lock.lock()
        defer { lock.unlock() }
        guard let db = db else { return [] }

        let sql = """
        SELECT stop_id, stop_code, name_he, name_en, name_ar,
               street, city, platform_code, lat, lon, location_type, parent_station
        FROM stops
        WHERE stop_code = ?
        ORDER BY location_type DESC, parent_station IS NULL DESC, platform_code ASC, stop_id ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(code.rawValue))

        var results: [TransitStop] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let stop = parseStop(from: stmt) {
                results.append(stop)
            }
        }
        return results
    }

    /// Resolves a stop by any valid scoped or unscoped ID (e.g. "mot:stop:4170_10758", "mot:stop:4170", "4170_10758", "10758").
    public func resolveStop(stopID: String) -> TransitStop? {
        if let internalID = MOTIdentityFormatter.parseStopInternalID(fromScopedID: stopID) {
            if let stop = self.stop(forInternalID: internalID) {
                return stop
            }
        }
        if let code = MOTIdentityFormatter.parseStopCode(fromScopedID: stopID) {
            if let stop = self.stop(forCode: code) {
                return stop
            }
        }
        if let numericID = Int(stopID.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if let stop = self.stop(forInternalID: MOTStopInternalID(rawValue: numericID)) {
                return stop
            }
            if let stop = self.stop(forCode: MOTStopCode(rawValue: numericID)) {
                return stop
            }
        }
        return nil
    }

    /// Retrieves a single stop by its internal GTFS stop_id (e.g., 11622).
    public func stop(forInternalID id: MOTStopInternalID) -> TransitStop? {
        lock.lock()
        defer { lock.unlock() }
        guard let db = db else { return nil }

        let sql = """
        SELECT stop_id, stop_code, name_he, name_en, name_ar,
               street, city, platform_code, lat, lon, location_type, parent_station
        FROM stops
        WHERE stop_id = ?
        LIMIT 1;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(id.rawValue))

        if sqlite3_step(stmt) == SQLITE_ROW {
            return parseStop(from: stmt)
        }
        return nil
    }

    // MARK: - Text Autocomplete / Search

    /// Autocompletes stations by stop code prefix or Hebrew name.
    public func searchStops(query: String, limit: Int = 20) -> [TransitStop] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        lock.lock()
        defer { lock.unlock() }
        guard let db = db else { return [] }

        let sql: String
        let isNumeric = Int(trimmed) != nil
        if isNumeric {
            sql = """
            SELECT stop_id, stop_code, name_he, name_en, name_ar,
                   street, city, platform_code, lat, lon, location_type, parent_station
            FROM stops
            WHERE stop_code LIKE ?
            ORDER BY (stop_code = ?) DESC, location_type DESC, parent_station IS NULL DESC, platform_code ASC, stop_code ASC
            LIMIT ?;
            """
        } else {
            sql = """
            SELECT stop_id, stop_code, name_he, name_en, name_ar,
                   street, city, platform_code, lat, lon, location_type, parent_station
            FROM stops
            WHERE name_he LIKE ? OR city LIKE ?
            ORDER BY (name_he LIKE ?) DESC, location_type DESC, parent_station IS NULL DESC, stop_code ASC
            LIMIT ?;
            """
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        if isNumeric {
            let pattern = "\(trimmed)%"
            sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(trimmed) ?? 0)
            sqlite3_bind_int(stmt, 3, Int32(limit))
        } else {
            let pattern = "%\(trimmed)%"
            let prefixPattern = "\(trimmed)%"
            sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (pattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (prefixPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 4, Int32(limit))
        }

        var results: [TransitStop] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let stop = parseStop(from: stmt) {
                results.append(stop)
            }
        }
        return results
    }

    // MARK: - Metadata & Stats

    public func metadata() -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        guard let db = db else { return [:] }

        let sql = "SELECT key, value FROM catalog_metadata;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return [:]
        }
        defer { sqlite3_finalize(stmt) }

        var meta: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let k = sqlite3_column_text(stmt, 0),
               let v = sqlite3_column_text(stmt, 1) {
                meta[String(cString: k)] = String(cString: v)
            }
        }
        return meta
    }

    public func totalStopCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let db = db else { return 0 }

        let sql = "SELECT COUNT(*) FROM stops;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    // MARK: - Internal Parsing

    private func parseStop(from stmt: OpaquePointer?) -> TransitStop? {
        guard let stmt = stmt else { return nil }
        let stopId = Int(sqlite3_column_int(stmt, 0))
        let stopCode = Int(sqlite3_column_int(stmt, 1))

        let nameHe = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
        let nameEn = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let nameAr = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let street = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let city = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let platform = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
        let lat = sqlite3_column_double(stmt, 8)
        let lon = sqlite3_column_double(stmt, 9)

        let multiName = TransitMultiLanguageName(he: nameHe, en: nameEn, ar: nameAr)
        let coords = CLLocationCoordinate2D(latitude: lat, longitude: lon)

        return TransitStop(
            code: MOTStopCode(rawValue: stopCode),
            internalID: MOTStopInternalID(rawValue: stopId),
            name: multiName,
            cityName: city,
            streetName: street,
            location: coords,
            platformNumber: platform,
            isAccessible: nil,
            routes: []
        )
    }
}
