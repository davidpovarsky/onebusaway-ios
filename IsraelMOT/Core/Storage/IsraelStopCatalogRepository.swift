//
//  IsraelStopCatalogRepository.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (Local Spatial Stop Catalog)
//

import Foundation
import CoreLocation
import SQLite3

/// Repository managing the bundled nationwide SQLite station catalog with R-Tree spatial indexing.
/// Provides sub-5ms viewport bounding-box queries, ensuring 0 network requests during map pan/zoom.
public final class IsraelStopCatalogRepository: @unchecked Sendable {
    public static let shared = IsraelStopCatalogRepository()

    private let lock = NSLock()
    private var db: OpaquePointer?
    public let databaseURL: URL?

    public init(databaseURL: URL? = nil) {
        let resolvedURL: URL? = {
            if let custom = databaseURL, FileManager.default.fileExists(atPath: custom.path) {
                return custom
            }
            // 1. App Bundle
            if let bundleURL = Bundle.main.url(forResource: "IsraelStopCatalog", withExtension: "sqlite") {
                return bundleURL
            }
            // 2. Framework Bundle
            let frameworkBundle = Bundle(for: IsraelStopCatalogRepository.self)
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
    public func stops(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        limit: Int = 350
    ) -> [TransitStop] {
        lock.lock()
        defer { lock.unlock() }
        guard let db = db else { return [] }

        let sql = """
        SELECT s.stop_id, s.stop_code, s.name_he, s.name_en, s.name_ar,
               s.street, s.city, s.platform_code, s.lat, s.lon, s.location_type, s.parent_station
        FROM stops_rtree r
        JOIN stops s ON r.id = s.stop_id
        WHERE r.min_lat >= ? AND r.max_lat <= ?
          AND r.min_lon >= ? AND r.max_lon <= ?
        LIMIT ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, minLat)
        sqlite3_bind_double(stmt, 2, maxLat)
        sqlite3_bind_double(stmt, 3, minLon)
        sqlite3_bind_double(stmt, 4, maxLon)
        sqlite3_bind_int(stmt, 5, Int32(limit))

        var result: [TransitStop] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let stop = parseStop(from: stmt) {
                result.append(stop)
            }
        }
        return result
    }

    // MARK: - Point & Code Lookups

    /// Retrieves a single stop by its public signpost code (e.g., 5997).
    public func stop(forCode code: MOTStopCode) -> TransitStop? {
        lock.lock()
        defer { lock.unlock() }
        guard let db = db else { return nil }

        let sql = """
        SELECT stop_id, stop_code, name_he, name_en, name_ar,
               street, city, platform_code, lat, lon, location_type, parent_station
        FROM stops
        WHERE stop_code = ?
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
            ORDER BY stop_code = ? DESC, stop_code ASC
            LIMIT ?;
            """
        } else {
            sql = """
            SELECT stop_id, stop_code, name_he, name_en, name_ar,
                   street, city, platform_code, lat, lon, location_type, parent_station
            FROM stops
            WHERE name_he LIKE ? OR city LIKE ?
            ORDER BY name_he LIKE ? DESC, name_he ASC
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
