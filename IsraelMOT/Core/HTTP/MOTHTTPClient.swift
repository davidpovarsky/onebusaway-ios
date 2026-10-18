//
//  MOTHTTPClient.swift
//  IsraelMOT
//
//  Created for OneBusAway Israel (MOT Integration)
//

import Foundation

/// HTTP client responsible for executing requests against MOT APIs with resilience,
/// F5 WAF detection, and structured error propagation.
public actor MOTHTTPClient {
    private let session: URLSession
    private let policy: MOTRequestPolicy
    private let backoff: MOTBackoff

    public init(
        session: URLSession = .shared,
        policy: MOTRequestPolicy = .standard
    ) {
        self.session = session
        self.policy = policy
        self.backoff = MOTBackoff()
    }

    private func profile(for url: URL) -> MOTHeaderProfile {
        let path = url.path.lowercased()
        if path.contains("route-planner-prod") {
            return .planner
        } else if path.contains("mot-scheduler-prod") {
            return .scheduler
        }
        return .default
    }

    /// Performs a GET request and decodes the response into the specified Decodable type.
    public func get<T: Decodable>(_ url: URL, decodeAs: T.Type = T.self) async throws -> T {
        let request = MOTRequestBuilder.buildRequest(
            url: url,
            method: "GET",
            profile: profile(for: url),
            timeoutInterval: policy.timeoutInterval
        )

        let (data, _) = try await execute(request: request)
        return try decode(data: data, as: T.self)
    }

    /// Performs a POST request with an Encodable body and decodes the response.
    public func post<B: Encodable, T: Decodable>(_ url: URL, body: B, decodeAs: T.Type = T.self) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        let request = MOTRequestBuilder.buildRequest(
            url: url,
            method: "POST",
            profile: profile(for: url),
            body: bodyData,
            timeoutInterval: policy.timeoutInterval
        )

        let (data, _) = try await execute(request: request)
        return try decode(data: data, as: T.self)
    }

    /// Executes a raw URLRequest, checking status codes and WAF blocks.
    public func execute(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var currentAttempt = 0
        while true {
            currentAttempt += 1
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw MOTHTTPError.invalidResponse(expected: "HTTPURLResponse", actual: nil)
                }

                // HTTP 403 alone does not establish F5/WAF interference.
                // F5 HTML includes "The requested URL was rejected" and a
                // support ID; normal APIs can also return 403 for other reasons.
                if httpResponse.statusCode == 403 {
                    let bodyString = String(data: data, encoding: .utf8) ?? ""
                    let looksLikeF5 = bodyString.localizedCaseInsensitiveContains("The requested URL was rejected")
                        || bodyString.localizedCaseInsensitiveContains("F5 site:")
                        || bodyString.localizedCaseInsensitiveContains("Please consult with your administrator")
                    if looksLikeF5 {
                        throw MOTHTTPError.wafBlocked(supportID: extractF5SupportID(from: bodyString))
                    }
                    throw MOTHTTPError.httpError(statusCode: 403, responseBody: bodyString)
                }

                // Check for Rate Limiting 429
                if httpResponse.statusCode == 429 {
                    let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? String
                    let seconds = retryAfter.flatMap(Int.init)
                    if currentAttempt <= policy.maxRetryAttempts {
                        let delay = seconds != nil ? TimeInterval(seconds!) : backoff.delay(forAttempt: currentAttempt)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    throw MOTHTTPError.rateLimited(retryAfterSeconds: seconds)
                }

                // Check for Service Unavailable 503
                if httpResponse.statusCode == 503 {
                    if currentAttempt <= policy.maxRetryAttempts {
                        let delay = backoff.delay(forAttempt: currentAttempt)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    let bodyString = String(data: data, encoding: .utf8)
                    throw MOTHTTPError.serviceUnavailable(statusCode: 503, message: bodyString)
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let bodyString = String(data: data, encoding: .utf8)
                    throw MOTHTTPError.httpError(statusCode: httpResponse.statusCode, responseBody: bodyString)
                }

                return (data, httpResponse)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as MOTHTTPError {
                throw error
            } catch {
                if currentAttempt <= policy.maxRetryAttempts {
                    let delay = backoff.delay(forAttempt: currentAttempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw MOTHTTPError.networkFailure(message: error.localizedDescription)
            }
        }
    }

    private func decode<T: Decodable>(data: Data, as type: T.Type) throws -> T {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MOTHTTPError.decodingError(message: error.localizedDescription)
        }
    }

    private func extractF5SupportID(from body: String) -> String? {
        guard body.localizedCaseInsensitiveContains("support ID") else { return nil }
        // Real F5 responses can use hexadecimal UUIDs, not only digits.
        let pattern = "support\\s+ID(?:\\s+is)?\\s*[:#]?\\s*([A-Fa-f0-9-]{8,})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: body, options: [], range: NSRange(location: 0, length: body.utf16.count)) else {
            return nil
        }
        guard let range = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[range])
    }
}
