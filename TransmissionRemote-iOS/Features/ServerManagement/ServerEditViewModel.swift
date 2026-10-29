//
//  ServerEditViewModel.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import Observation

@Observable
@MainActor
public final class ServerEditViewModel {
    public var name: String
    public var scheme: ServerScheme {
        didSet {
            guard oldValue != scheme else { return }
            let trimmedPort = portString.trimmingCharacters(in: .whitespacesAndNewlines)
            if scheme == .http && trimmedPort == "443" {
                portString = "9091"
            } else if scheme == .https && trimmedPort == "9091" {
                portString = "443"
            }
        }
    }
    public var host: String
    public var portString: String
    public var rpcPath: String
    public var trustSelfSigned: Bool
    public var username: String
    public var password: String

    public private(set) var isTestingConnection: Bool = false
    public var testResult: Result<SessionStats, Error>?

    public let existingServerId: UUID?
    public var isEditing: Bool { existingServerId != nil }

    private let clientFactory: (ServerConfig, String?) -> TransmissionClientProtocol

    public init(
        server: ServerConfig? = nil,
        initialPassword: String? = nil,
        repository: ServerRepositoryProtocol? = nil,
        clientFactory: ((ServerConfig, String?) -> TransmissionClientProtocol)? = nil
    ) {
        self.existingServerId = server?.id
        let resolvedPassword = initialPassword ?? (server.flatMap { repository?.getPassword(for: $0.id) }) ?? ""

        if let server = server {
            self.name = server.name
            self.scheme = server.scheme
            self.host = server.host
            self.portString = String(server.port)
            self.rpcPath = server.rpcPath
            self.trustSelfSigned = server.trustSelfSignedCertificates
            self.username = server.username ?? ""
            self.password = resolvedPassword
        } else {
            self.name = ""
            self.scheme = .http
            self.host = ""
            self.portString = "9091"
            self.rpcPath = "/transmission/rpc"
            self.trustSelfSigned = false
            self.username = ""
            self.password = resolvedPassword
        }

        self.clientFactory = clientFactory ?? { config, password in
            TransmissionClient(config: config, password: password)
        }
    }

    public convenience init(
        server: ServerConfig? = nil,
        password: String? = nil,
        client: TransmissionClientProtocol
    ) {
        self.init(
            server: server,
            initialPassword: password,
            clientFactory: { _, _ in client }
        )
    }

    // MARK: - Validation

    public var parsedPort: Int? {
        guard let port = Int(portString.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65535).contains(port) else {
            return nil
        }
        return port
    }

    public var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var isHostValid: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var isPortValid: Bool {
        parsedPort != nil
    }

    public var isValid: Bool {
        isNameValid && isHostValid && isPortValid
    }

    // MARK: - Actions

    public func buildConfig() -> ServerConfig? {
        guard let port = parsedPort else { return nil }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleanRpcPath = rpcPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanRpcPath.isEmpty {
            cleanRpcPath = "/transmission/rpc"
        } else if !cleanRpcPath.hasPrefix("/") {
            cleanRpcPath = "/" + cleanRpcPath
        }
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedUsername = cleanUsername.isEmpty ? nil : cleanUsername

        return ServerConfig(
            id: existingServerId ?? UUID(),
            name: cleanName,
            scheme: scheme,
            host: cleanHost,
            port: port,
            rpcPath: cleanRpcPath,
            trustSelfSignedCertificates: trustSelfSigned,
            username: resolvedUsername
        )
    }

    public func testConnection() async {
        guard isValid, let config = buildConfig() else {
            testResult = .failure(TransmissionError.invalidURL)
            return
        }

        isTestingConnection = true
        testResult = nil
        defer { isTestingConnection = false }

        let resolvedPassword = password.isEmpty ? nil : password
        let client = clientFactory(config, resolvedPassword)
        do {
            let stats = try await client.testConnection(config: config, password: resolvedPassword)
            testResult = .success(stats)
        } catch {
            testResult = .failure(error)
        }
    }

    @discardableResult
    public func save(to repository: ServerRepositoryProtocol) async throws -> ServerConfig {
        guard isValid, let config = buildConfig() else {
            throw TransmissionError.invalidURL
        }

        let resolvedPassword = password.isEmpty ? nil : password

        if isEditing {
            try repository.updateServer(config, password: resolvedPassword)
        } else {
            try repository.addServer(config, password: resolvedPassword)
        }

        return config
    }
}
