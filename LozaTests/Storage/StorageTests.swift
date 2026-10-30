//
//  StorageTests.swift
//  TransmissionRemote-iOSTests
//
//  Created by Roman Simenok on 29.10.2026.
//

import Testing
import Foundation
@testable import TransmissionRemote_iOS

// MARK: - Mock Keychain Service for isolated tests

final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private var storage: [UUID: String] = [:]
    private let lock = NSLock()

    func save(password: String, forServerId id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[id] = password
    }

    func getPassword(forServerId id: UUID) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[id]
    }

    func deletePassword(forServerId id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: id)
    }

    func deleteAllPasswords() throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}

// MARK: - ServerRepository Tests

@MainActor
struct StorageTests {

    private func createTestEnvironment() -> (ServerRepository, UserDefaults, MockKeychainService) {
        let suiteName = "test_repo_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let mockKeychain = MockKeychainService()
        let repository = ServerRepository(
            userDefaults: defaults,
            keychainService: mockKeychain,
            serversKey: "test_servers",
            activeServerIdKey: "test_active_id"
        )
        return (repository, defaults, mockKeychain)
    }

    @Test func testEmptyRepositoryInitialization() async throws {
        let (repo, _, _) = createTestEnvironment()
        #expect(repo.servers.isEmpty)
        #expect(repo.activeServerId == nil)
        #expect(repo.getActiveServer() == nil)
    }

    @Test func testAddServerSetsActiveServerIfFirst() async throws {
        let (repo, _, keychain) = createTestEnvironment()

        let server1 = ServerConfig(
            name: "Server 1",
            scheme: .http,
            host: "192.168.1.10",
            port: 9091,
            username: "user1"
        )

        try repo.addServer(server1, password: "secretPassword1")

        #expect(repo.servers.count == 1)
        #expect(repo.activeServerId == server1.id)
        #expect(repo.getActiveServer()?.id == server1.id)
        #expect(keychain.getPassword(forServerId: server1.id) == "secretPassword1")
        #expect(repo.getPassword(for: server1.id) == "secretPassword1")
    }

    @Test func testAddMultipleServersAndSwitchActive() async throws {
        let (repo, _, _) = createTestEnvironment()

        let server1 = ServerConfig(name: "Server 1", host: "10.0.0.1")
        let server2 = ServerConfig(name: "Server 2", host: "10.0.0.2")

        try repo.addServer(server1)
        try repo.addServer(server2)

        #expect(repo.servers.count == 2)
        #expect(repo.activeServerId == server1.id)

        // Switch active server to server2
        repo.setActiveServer(id: server2.id)
        #expect(repo.activeServerId == server2.id)
        #expect(repo.getActiveServer()?.name == "Server 2")

        // Try setting non-existent id - should be ignored
        repo.setActiveServer(id: UUID())
        #expect(repo.activeServerId == server2.id)
    }

    @Test func testUpdateServer() async throws {
        let (repo, _, keychain) = createTestEnvironment()

        var server = ServerConfig(name: "Initial Name", host: "1.2.3.4")
        try repo.addServer(server, password: "oldPassword")

        server.name = "Updated Name"
        server.port = 8080
        try repo.updateServer(server, password: "newPassword")

        #expect(repo.servers.count == 1)
        #expect(repo.servers.first?.name == "Updated Name")
        #expect(repo.servers.first?.port == 8080)
        #expect(keychain.getPassword(forServerId: server.id) == "newPassword")
    }

    @Test func testDeleteServer() async throws {
        let (repo, _, keychain) = createTestEnvironment()

        let server1 = ServerConfig(name: "Server 1", host: "10.0.0.1")
        let server2 = ServerConfig(name: "Server 2", host: "10.0.0.2")

        try repo.addServer(server1, password: "pwd1")
        try repo.addServer(server2, password: "pwd2")

        #expect(repo.activeServerId == server1.id)

        // Delete active server (server1)
        try repo.deleteServer(id: server1.id)

        #expect(repo.servers.count == 1)
        #expect(keychain.getPassword(forServerId: server1.id) == nil)
        // Active server should automatically fall back to server2
        #expect(repo.activeServerId == server2.id)
        #expect(repo.getActiveServer()?.id == server2.id)

        // Delete remaining server
        try repo.deleteServer(id: server2.id)
        #expect(repo.servers.isEmpty)
        #expect(repo.activeServerId == nil)
        #expect(repo.getActiveServer() == nil)
    }

    @Test func testPersistenceAcrossInstances() async throws {
        let suiteName = "test_persistence_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let mockKeychain = MockKeychainService()

        let server = ServerConfig(name: "Persisted Server", host: "remote.host")

        // Instance 1
        let repo1 = ServerRepository(
            userDefaults: defaults,
            keychainService: mockKeychain,
            serversKey: "servers_key",
            activeServerIdKey: "active_id_key"
        )
        try repo1.addServer(server, password: "securePass")

        // Instance 2 with same defaults & keychain
        let repo2 = ServerRepository(
            userDefaults: defaults,
            keychainService: mockKeychain,
            serversKey: "servers_key",
            activeServerIdKey: "active_id_key"
        )

        #expect(repo2.servers.count == 1)
        #expect(repo2.servers.first?.name == "Persisted Server")
        #expect(repo2.activeServerId == server.id)
        #expect(repo2.getPassword(for: server.id) == "securePass")
    }
}
