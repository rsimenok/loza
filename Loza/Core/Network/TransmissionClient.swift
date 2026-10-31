//
//  TransmissionClient.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import Alamofire
import os

/// Alamofire-backed implementation of `TransmissionClientProtocol`.
public final class TransmissionClient: TransmissionClientProtocol, @unchecked Sendable {
    private struct ClientState: Sendable {
        var config: ServerConfig?
        var password: String?
        var session: Session?
        var interceptor: TransmissionInterceptor?
    }

    private let keychainService: KeychainServiceProtocol
    private let stateLock: OSAllocatedUnfairLock<ClientState>

    public init(
        config: ServerConfig? = nil,
        password: String? = nil,
        keychainService: KeychainServiceProtocol = KeychainService.shared
    ) {
        self.keychainService = keychainService

        if let config = config {
            let resolvedPassword = password ?? keychainService.getPassword(forServerId: config.id)
            let (session, interceptor) = Self.makeSession(config: config, password: resolvedPassword)
            self.stateLock = OSAllocatedUnfairLock(initialState: ClientState(
                config: config,
                password: resolvedPassword,
                session: session,
                interceptor: interceptor
            ))
        } else {
            self.stateLock = OSAllocatedUnfairLock(initialState: ClientState(
                config: nil,
                password: nil,
                session: nil,
                interceptor: nil
            ))
        }
    }

    /// Update the active server configuration and rebuild network session
    public func updateConfig(_ config: ServerConfig, password: String? = nil) {
        let resolvedPassword = password ?? keychainService.getPassword(forServerId: config.id)
        let (session, interceptor) = Self.makeSession(config: config, password: resolvedPassword)
        stateLock.withLock {
            $0.config = config
            $0.password = resolvedPassword
            $0.session = session
            $0.interceptor = interceptor
        }
    }

    // MARK: - TransmissionClientProtocol

    public func testConnection(config: ServerConfig) async throws -> SessionStats {
        try await testConnection(config: config, password: nil)
    }

    public func testConnection(config: ServerConfig, password: String?) async throws -> SessionStats {
        let resolvedPassword = password ?? keychainService.getPassword(forServerId: config.id)
        let (session, _) = Self.makeSession(config: config, password: resolvedPassword)
        guard let url = config.url else {
            throw TransmissionError.invalidURL
        }

        return try await execute(
            session: session,
            url: url,
            method: "session-stats",
            arguments: EmptyArguments()
        )
    }

    public func fetchTorrents() async throws -> [Torrent] {
        let (session, config) = try getActiveSessionAndConfig()
        guard let url = config.url else {
            throw TransmissionError.invalidURL
        }

        let response: TorrentGetResponse = try await execute(
            session: session,
            url: url,
            method: "torrent-get",
            arguments: TorrentGetArguments()
        )
        return response.torrents
    }

    public func fetchSessionStats() async throws -> SessionStats {
        let (session, config) = try getActiveSessionAndConfig()
        guard let url = config.url else {
            throw TransmissionError.invalidURL
        }

        return try await execute(
            session: session,
            url: url,
            method: "session-stats",
            arguments: EmptyArguments()
        )
    }

    public func startTorrents(ids: [Int]) async throws {
        let (session, config) = try getActiveSessionAndConfig()
        guard let url = config.url else {
            throw TransmissionError.invalidURL
        }

        let _: EmptyResponse = try await execute(
            session: session,
            url: url,
            method: "torrent-start",
            arguments: TorrentActionArguments(ids: ids)
        )
    }

    public func stopTorrents(ids: [Int]) async throws {
        let (session, config) = try getActiveSessionAndConfig()
        guard let url = config.url else {
            throw TransmissionError.invalidURL
        }

        let _: EmptyResponse = try await execute(
            session: session,
            url: url,
            method: "torrent-stop",
            arguments: TorrentActionArguments(ids: ids)
        )
    }

    public func removeTorrents(ids: [Int], deleteLocalData: Bool) async throws {
        let (session, config) = try getActiveSessionAndConfig()
        guard let url = config.url else {
            throw TransmissionError.invalidURL
        }

        let _: EmptyResponse = try await execute(
            session: session,
            url: url,
            method: "torrent-remove",
            arguments: TorrentRemoveArguments(ids: ids, deleteLocalData: deleteLocalData)
        )
    }

    public func addTorrent(
        magnetOrUrl: String?,
        base64Metainfo: String?,
        downloadDir: String?
    ) async throws {
        try await addTorrent(magnetOrUrl: magnetOrUrl, base64Metainfo: base64Metainfo, downloadDir: downloadDir, paused: nil)
    }

    public func addTorrent(
        magnetOrUrl: String?,
        base64Metainfo: String?,
        downloadDir: String?,
        paused: Bool?
    ) async throws {
        let (session, config) = try getActiveSessionAndConfig()
        guard let url = config.url else {
            throw TransmissionError.invalidURL
        }

        let _: EmptyResponse = try await execute(
            session: session,
            url: url,
            method: "torrent-add",
            arguments: TorrentAddArguments(
                filename: magnetOrUrl,
                metainfo: base64Metainfo,
                downloadDir: downloadDir,
                paused: paused
            )
        )
    }

    // MARK: - Private Helpers

    private func getActiveSessionAndConfig() throws -> (session: Session, config: ServerConfig) {
        let (session, config) = stateLock.withLock { ($0.session, $0.config) }
        guard let session = session, let config = config else {
            throw TransmissionError.noActiveServer
        }
        return (session, config)
    }

    private static func makeSession(
        config: ServerConfig,
        password: String?,
        timeout: TimeInterval = 10.0
    ) -> (session: Session, interceptor: TransmissionInterceptor) {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout

        let interceptor = TransmissionInterceptor(config: config, password: password)

        var serverTrustManager: ServerTrustManager? = nil
        if config.trustSelfSignedCertificates {
            let evaluators: [String: ServerTrustEvaluating] = [
                config.host: DisabledTrustEvaluator()
            ]
            serverTrustManager = ServerTrustManager(allHostsMustBeEvaluated: false, evaluators: evaluators)
        }

        let session = Session(
            configuration: configuration,
            interceptor: interceptor,
            serverTrustManager: serverTrustManager
        )

        return (session, interceptor)
    }

    private func execute<T: Encodable & Sendable, R: Decodable & Sendable>(
        session: Session,
        url: URL,
        method: String,
        arguments: T
    ) async throws -> R {
        let rpcRequest = RPCRequest(method: method, arguments: arguments)

        let dataRequest = session.request(
            url,
            method: .post,
            parameters: rpcRequest,
            encoder: JSONParameterEncoder.default,
            headers: ["Content-Type": "application/json"]
        )

        let response = await dataRequest.serializingDecodable(RPCResponse<R>.self).response

        switch response.result {
        case .success(let rpcResponse):
            guard rpcResponse.isSuccess else {
                throw TransmissionError.rpcError(message: rpcResponse.result)
            }

            if let args = rpcResponse.arguments {
                return args
            } else if let empty = EmptyResponse() as? R {
                return empty
            } else {
                throw TransmissionError.decodingFailed(
                    underlying: NSError(
                        domain: "TransmissionClient",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Missing arguments in successful response for '\(method)'"]
                    )
                )
            }

        case .failure(let afError):
            throw Self.mapError(afError, statusCode: response.response?.statusCode)
        }
    }

    private static func mapError(_ error: Error, statusCode: Int?) -> TransmissionError {
        if statusCode == 401 {
            return .unauthorized
        }

        if let afError = error as? AFError {
            switch afError {
            case .serverTrustEvaluationFailed:
                return .sslCertificateUntrusted

            case .responseValidationFailed(let reason):
                if case .unacceptableStatusCode(let code) = reason, code == 401 {
                    return .unauthorized
                }

            case .responseSerializationFailed:
                return .decodingFailed(underlying: afError)

            case .sessionTaskFailed(let underlying):
                if let urlError = underlying as? URLError {
                    switch urlError.code {
                    case .serverCertificateUntrusted,
                         .serverCertificateHasBadDate,
                         .serverCertificateNotYetValid,
                         .serverCertificateHasUnknownRoot:
                        return .sslCertificateUntrusted
                    case .userCancelledAuthentication,
                         .userAuthenticationRequired:
                        return .unauthorized
                    case .badURL, .unsupportedURL:
                        return .invalidURL
                    case .timedOut,
                         .cannotFindHost,
                         .cannotConnectToHost,
                         .networkConnectionLost,
                         .notConnectedToInternet:
                        return .serverUnreachable(underlying: urlError)
                    default:
                        return .serverUnreachable(underlying: urlError)
                    }
                }
                let sendableErr = (underlying as? (any Error & Sendable)) ?? NSError(
                    domain: "Network",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: underlying.localizedDescription]
                )
                return .serverUnreachable(underlying: sendableErr)

            default:
                break
            }
        }

        let sendableErr = (error as? (any Error & Sendable)) ?? NSError(
            domain: "Network",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
        )
        return .serverUnreachable(underlying: sendableErr)
    }
}
