//
//  TransmissionInterceptor.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import Alamofire
import os

/// Alamofire `RequestInterceptor` handling Transmission's CSRF `X-Transmission-Session-Id` handshake and HTTP Basic Auth.
public final class TransmissionInterceptor: RequestInterceptor, @unchecked Sendable {
    private struct Credentials: Sendable {
        var username: String?
        var password: String?
    }

    private let sessionIdLock: OSAllocatedUnfairLock<String?>
    private let credentialsLock: OSAllocatedUnfairLock<Credentials>

    /// The current session token for the Transmission daemon.
    public var sessionId: String? {
        get { sessionIdLock.withLock { $0 } }
        set { sessionIdLock.withLock { $0 = newValue } }
    }

    public init(username: String? = nil, password: String? = nil, initialSessionId: String? = nil) {
        self.sessionIdLock = OSAllocatedUnfairLock(initialState: initialSessionId)
        self.credentialsLock = OSAllocatedUnfairLock(initialState: Credentials(username: username, password: password))
    }

    public convenience init(config: ServerConfig, password: String? = nil, initialSessionId: String? = nil) {
        self.init(username: config.username, password: password, initialSessionId: initialSessionId)
    }

    /// Update server credentials dynamically
    public func updateCredentials(username: String?, password: String?) {
        credentialsLock.withLock {
            $0.username = username
            $0.password = password
        }
    }

    // MARK: - RequestAdapter

    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, any Error>) -> Void
    ) {
        var adaptedRequest = urlRequest

        // 1. Add Transmission session ID if available
        if let currentSessionId = sessionId {
            adaptedRequest.setValue(currentSessionId, forHTTPHeaderField: "X-Transmission-Session-Id")
        }

        // 2. Add HTTP Basic Authentication if credentials are configured
        let creds = credentialsLock.withLock { $0 }
        if let username = creds.username, !username.isEmpty {
            let password = creds.password ?? ""
            let authString = "\(username):\(password)"
            let authData = Data(authString.utf8)
            let base64Auth = authData.base64EncodedString()
            adaptedRequest.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        completion(.success(adaptedRequest))
    }

    // MARK: - RequestRetrier

    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: any Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        guard let response = request.task?.response as? HTTPURLResponse ?? request.response else {
            completion(.doNotRetry)
            return
        }

        let allHeaders = response.allHeaderFields
        let headerSessionId = response.value(forHTTPHeaderField: "X-Transmission-Session-Id")
            ?? (allHeaders["X-Transmission-Session-Id"] as? String)
            ?? (allHeaders["x-transmission-session-id"] as? String)

        if response.statusCode == 409, let newSessionId = headerSessionId, !newSessionId.isEmpty {
            self.sessionId = newSessionId

            if request.retryCount < 2 {
                completion(.retry)
            } else {
                completion(.doNotRetry)
            }
            return
        }

        completion(.doNotRetry)
    }

    // MARK: - Synchronous Helper for Unit Tests

    /// Synchronously evaluates a response status and headers for testing retry logic
    @discardableResult
    public func evaluateRetry(
        statusCode: Int,
        headers: [String: String],
        retryCount: Int = 0
    ) -> (shouldRetry: Bool, newSessionId: String?) {
        guard statusCode == 409, retryCount < 2 else {
            return (false, nil)
        }

        guard let newId = headers.first(where: { $0.key.caseInsensitiveCompare("X-Transmission-Session-Id") == .orderedSame })?.value,
              !newId.isEmpty else {
            return (false, nil)
        }

        self.sessionId = newId
        return (true, newId)
    }
}
