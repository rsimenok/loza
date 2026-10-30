//
//  ServerRepository.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import Observation

@MainActor
public protocol ServerRepositoryProtocol: AnyObject, Sendable {
    var servers: [ServerConfig] { get }
    var activeServerId: UUID? { get }
    var activeServer: ServerConfig? { get }

    func getActiveServer() -> ServerConfig?
    func addServer(_ server: ServerConfig, password: String?) throws
    func updateServer(_ server: ServerConfig, password: String?) throws
    func deleteServer(id: UUID) throws
    func setActiveServer(id: UUID?)
    func getPassword(for serverId: UUID) -> String?
    func setPassword(_ password: String?, for serverId: UUID) throws
}

@Observable
@MainActor
public final class ServerRepository: ServerRepositoryProtocol, Sendable {
    public private(set) var servers: [ServerConfig] = []
    public private(set) var activeServerId: UUID?

    private let userDefaults: UserDefaults
    private let keychainService: KeychainServiceProtocol

    private let serversKey: String
    private let activeServerIdKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        keychainService: KeychainServiceProtocol = KeychainService.shared,
        serversKey: String = "transmission_remote_servers_v1",
        activeServerIdKey: String = "transmission_remote_active_server_id_v1"
    ) {
        self.userDefaults = userDefaults
        self.keychainService = keychainService
        self.serversKey = serversKey
        self.activeServerIdKey = activeServerIdKey

        loadFromStorage()
    }

    // MARK: - Active Server

    public var activeServer: ServerConfig? {
        getActiveServer()
    }

    public func getActiveServer() -> ServerConfig? {
        if let activeId = activeServerId,
           let server = servers.first(where: { $0.id == activeId }) {
            return server
        }
        return servers.first
    }

    public func setActiveServer(id: UUID?) {
        if let id = id {
            guard servers.contains(where: { $0.id == id }) else { return }
            activeServerId = id
            userDefaults.set(id.uuidString, forKey: activeServerIdKey)
        } else {
            activeServerId = nil
            userDefaults.removeObject(forKey: activeServerIdKey)
        }
    }

    // MARK: - Server Management

    public func addServer(_ server: ServerConfig, password: String? = nil) throws {
        if let existingIndex = servers.firstIndex(where: { $0.id == server.id }) {
            servers[existingIndex] = server
        } else {
            servers.append(server)
        }

        if let password = password {
            try keychainService.save(password: password, forServerId: server.id)
        }

        // If this is the only server or no active server is set, make it active
        if activeServerId == nil || servers.count == 1 {
            setActiveServer(id: server.id)
        }

        saveToStorage()
    }

    public func updateServer(_ server: ServerConfig, password: String? = nil) throws {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
        } else {
            servers.append(server)
        }

        try setPassword(password, for: server.id)

        saveToStorage()
    }

    public func deleteServer(id: UUID) throws {
        servers.removeAll { $0.id == id }

        try? keychainService.deletePassword(forServerId: id)

        if activeServerId == id {
            setActiveServer(id: servers.first?.id)
        }

        saveToStorage()
    }

    // MARK: - Password Management

    public func getPassword(for serverId: UUID) -> String? {
        keychainService.getPassword(forServerId: serverId)
    }

    public func setPassword(_ password: String?, for serverId: UUID) throws {
        if let password = password {
            try keychainService.save(password: password, forServerId: serverId)
        } else {
            try keychainService.deletePassword(forServerId: serverId)
        }
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        if let data = userDefaults.data(forKey: serversKey) {
            do {
                let decoded = try JSONDecoder().decode([ServerConfig].self, from: data)
                self.servers = decoded
            } catch {
                self.servers = []
            }
        }

        if let activeIdString = userDefaults.string(forKey: activeServerIdKey),
           let uuid = UUID(uuidString: activeIdString),
           servers.contains(where: { $0.id == uuid }) {
            self.activeServerId = uuid
        } else {
            self.activeServerId = servers.first?.id
        }
    }

    private func saveToStorage() {
        do {
            let data = try JSONEncoder().encode(servers)
            userDefaults.set(data, forKey: serversKey)
        } catch {
            // Encode error
        }
    }
}
