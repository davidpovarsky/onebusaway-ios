//
//  MOTTestFixtures.swift
//  IsraelMOTTests
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

nonisolated public enum MOTTestFixtures {
    public static func loadData(named fileName: String) -> Data {
        // 1. Search across all loaded test bundles
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: fileName, withExtension: nil) {
                if let data = try? Data(contentsOf: url) {
                    return data
                }
            }
            if let path = bundle.path(forResource: fileName, ofType: nil) {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    return data
                }
            }
        }

        // 2. Search relative to #filePath (local dev, SPM, or direct test runner)
        let sourceFile = URL(fileURLWithPath: #filePath)
        let fixturesDir = sourceFile.deletingLastPathComponent().appendingPathComponent("Fixtures")
        let targetFile = fixturesDir.appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: targetFile) {
            return data
        }

        // 3. Search under repository root
        let repoRoot = sourceFile
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // IsraelMOT
        let fallbackFile = repoRoot
            .appendingPathComponent("IsraelMOT")
            .appendingPathComponent("Tests")
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(fileName)

        if let data = try? Data(contentsOf: fallbackFile) {
            return data
        }

        fatalError("Failed to find fixture file: \(fileName)")
    }

    public static func loadFixture(named fileName: String) throws -> Data {
        return loadData(named: fileName)
    }

    public static func decode<T: Decodable>(fixture named: String, as type: T.Type = T.self) throws -> T {
        let data = loadData(named: named)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
