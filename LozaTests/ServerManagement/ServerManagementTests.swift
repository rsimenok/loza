//
//  ServerManagementTests.swift
//  TransmissionRemote-iOSTests
//
//  Created by Roman Simenok on 29.10.2026.
//

import Testing
import Foundation
@testable import TransmissionRemote_iOS

// MARK: - InMemoryServerRepository for Isolated Testing

@MainActor
private final class InMemoryKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private var passwords: [UUID: String] = [:]

    func save(password: String, forServerId id: UUID) throws {
        passwords[id] = password
    }

    func getPassword(forServerId id: UUID) -> String? {
        passwords[id]
    }

    func deletePassword(forServerId id: UUID) throws {
        passwords.removeValue(forKey: id)
    }

    func deleteAllPasswords() throws {
        passwords.removeAll()
    }
}

@MainActor
struct ServerManagementTests {

    private func createTestRepository() -> (ServerRepository, UserDefaults) {
        let suiteName = "test_server_mgmt_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let keychain = InMemoryKeychainService()
        let repo = ServerRepository(
            userDefaults: defaults,
            keychainService: keychain,
            serversKey: "test_servers_\(suiteName)",
            activeServerIdKey: "test_active_\(suiteName)"
        )
        return (repo, defaults)
    }

    // MARK: - 1. Validation Tests

    @Test func testFieldValidation() async {
        let vm = ServerEditViewModel()

        // Initially invalid: empty name and host
        #expect(!vm.isValid)
        #expect(!vm.isNameValid)
        #expect(!vm.isHostValid)
        #expect(vm.isPortValid) // Default is 9091

        // Provide name only
        vm.name = "Home Server"
        #expect(vm.isNameValid)
        #expect(!vm.isValid) // Host still empty

        // Provide whitespace name
        vm.name = "   "
        #expect(!vm.isNameValid)
        #expect(!vm.isValid)

        // Set valid name and host
        vm.name = "Home Server"
        vm.host = "192.168.1.100"
        #expect(vm.isNameValid)
        #expect(vm.isHostValid)
        #expect(vm.isValid)

        // Test port bounds
        vm.portString = "0"
        #expect(!vm.isPortValid)
        #expect(!vm.isValid)

        vm.portString = "65536"
        #expect(!vm.isPortValid)
        #expect(!vm.isValid)

        vm.portString = "not_a_number"
        #expect(!vm.isPortValid)
        #expect(!vm.isValid)

        vm.portString = "1"
        #expect(vm.isPortValid)
        #expect(vm.isValid)

        vm.portString = "65535"
        #expect(vm.isPortValid)
        #expect(vm.isValid)

        vm.portString = "9091"
        #expect(vm.isPortValid)
        #expect(vm.isValid)
    }

    // MARK: - 2. Port Auto-Substitution Tests

    @Test func testPortAutoSubstitutionOnSchemeChange() async {
        let vm = ServerEditViewModel()
        #expect(vm.scheme == .http)
        #expect(vm.portString == "9091")

        // Switch to HTTPS -> port 9091 should automatically become 443
        vm.scheme = .https
        #expect(vm.portString == "443")

        // Switch back to HTTP -> port 443 should automatically become 9091
        vm.scheme = .http
        #expect(vm.portString == "9091")

        // Custom port should NOT be overwritten
        vm.portString = "8080"
        vm.scheme = .https
        #expect(vm.portString == "8080")

        vm.scheme = .http
        #expect(vm.portString == "8080")

        // Custom port set to 443 on HTTP, then switching to HTTP keeps it or stays same
        vm.portString = "443"
        vm.scheme = .http // already http
        #expect(vm.portString == "443")

        // If scheme was https with 443 and switches to http -> 9091
        vm.scheme = .https
        vm.portString = "443"
        vm.scheme = .http
        #expect(vm.portString == "9091")
    }

    // MARK: - 3. Save New Server & Update Existing Tests

    @Test func testSaveNewServerAndUpdatingExisting() async throws {
        let (repo, _) = createTestRepository()

        // 1. Save new server
        let newVm = ServerEditViewModel()
        newVm.name = "My Transmission"
        newVm.scheme = .https
        newVm.host = "remote.seedbox.com"
        newVm.portString = "443"
        newVm.rpcPath = "/rpc"
        newVm.trustSelfSigned = true
        newVm.username = "seedbox_user"
        newVm.password = "secret_seed_password"

        let savedServer = try await newVm.save(to: repo)

        #expect(repo.servers.count == 1)
        #expect(savedServer.name == "My Transmission")
        #expect(savedServer.scheme == .https)
        #expect(savedServer.host == "remote.seedbox.com")
        #expect(savedServer.port == 443)
        #expect(savedServer.rpcPath == "/rpc")
        #expect(savedServer.trustSelfSignedCertificates == true)
        #expect(savedServer.username == "seedbox_user")
        #expect(repo.getPassword(for: savedServer.id) == "secret_seed_password")
        #expect(repo.activeServerId == savedServer.id)

        // 2. Edit existing server
        let editVm = ServerEditViewModel(server: savedServer, repository: repo)
        #expect(editVm.isEditing)
        #expect(editVm.name == "My Transmission")
        #expect(editVm.password == "secret_seed_password")

        editVm.name = "Updated Transmission NAS"
        editVm.portString = "8443"
        editVm.password = "new_secret_password"

        let updatedServer = try await editVm.save(to: repo)

        #expect(repo.servers.count == 1)
        #expect(updatedServer.id == savedServer.id)
        #expect(updatedServer.name == "Updated Transmission NAS")
        #expect(updatedServer.port == 8443)
        #expect(repo.getPassword(for: updatedServer.id) == "new_secret_password")
    }

    // MARK: - 4. Test Connection with MockTransmissionClient

    @Test func testConnectionVerificationSuccess() async {
        let mockClient = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = ServerEditViewModel(client: mockClient)

        vm.name = "Local Test Server"
        vm.host = "127.0.0.1"
        vm.portString = "9091"

        #expect(!vm.isTestingConnection)
        #expect(vm.testResult == nil)

        await vm.testConnection()

        #expect(!vm.isTestingConnection)
        guard let result = vm.testResult else {
            Issue.record("Expected testResult to not be nil")
            return
        }

        switch result {
        case .success(let stats):
            #expect(stats.torrentCount == 4)
            #expect(stats.activeTorrentCount == 2)
        case .failure(let error):
            Issue.record("Expected success, but got error: \(error)")
        }
    }

    @Test func testConnectionVerificationFailure() async {
        let mockClient = MockTransmissionClient(
            simulatedDelayNanoseconds: 0,
            shouldFailWithError: .unauthorized
        )
        let vm = ServerEditViewModel(client: mockClient)

        vm.name = "Protected Server"
        vm.host = "10.0.0.1"
        vm.portString = "9091"

        await vm.testConnection()

        #expect(!vm.isTestingConnection)
        guard let result = vm.testResult else {
            Issue.record("Expected testResult to not be nil")
            return
        }

        switch result {
        case .success:
            Issue.record("Expected failure with unauthorized error")
        case .failure(let error):
            if let transError = error as? TransmissionError {
                #expect(transError == .unauthorized)
            } else {
                Issue.record("Expected TransmissionError.unauthorized")
            }
        }
    }

    // MARK: - 5. AppEnvironment Operations

    @Test func testAppEnvironmentManagement() async throws {
        let (repo, _) = createTestRepository()
        let env = AppEnvironment(
            serverRepository: repo,
            clientFactory: { config in
                MockTransmissionClient(simulatedDelayNanoseconds: 0)
            }
        )

        #expect(!env.hasConfiguredServer)
        #expect(env.activeServer == nil)
        #expect(env.currentClient == nil)

        let server1 = ServerConfig(name: "Server 1", host: "192.168.1.1")
        try env.addServer(server1, password: "pw1")

        #expect(env.hasConfiguredServer)
        #expect(env.activeServer?.id == server1.id)
        #expect(env.currentClient != nil)

        let server2 = ServerConfig(name: "Server 2", host: "192.168.1.2")
        try env.addServer(server2, password: "pw2")

        #expect(env.activeServer?.id == server1.id)

        // Switch to server2
        env.switchServer(to: server2)
        #expect(env.activeServer?.id == server2.id)

        // Switch by id
        env.selectServer(id: server1.id)
        #expect(env.activeServer?.id == server1.id)

        // Delete server1 -> server2 should become active
        try env.deleteServer(id: server1.id)
        #expect(env.activeServer?.id == server2.id)

        // Delete server2 -> no servers left
        try env.deleteServer(id: server2.id)
        #expect(!env.hasConfiguredServer)
        #expect(env.activeServer == nil)
        #expect(env.currentClient == nil)
    }

    @Test func testActiveServerPasswordUpdateRecreatesClientAndUpdatesToken() async throws {
        let (repo, _) = createTestRepository()
        let env = AppEnvironment(
            serverRepository: repo,
            clientFactory: { config in
                MockTransmissionClient(simulatedDelayNanoseconds: 0)
            }
        )

        let server = ServerConfig(name: "Home Server", host: "192.168.1.50")
        try env.addServer(server, password: "initial_password")

        let initialClient = env.currentClient
        let initialToken = env.clientUpdateToken
        #expect(initialClient != nil)

        // Updating only the password on the active server
        try env.updateServer(server, password: "new_updated_password")

        #expect(env.activeServer?.id == server.id)
        #expect(repo.getPassword(for: server.id) == "new_updated_password")
        #expect(env.clientUpdateToken != initialToken)
        #expect((env.currentClient as AnyObject) !== (initialClient as AnyObject))
    }

    @Test func testUpdateServerClearsPasswordWhenNil() async throws {
        let (repo, _) = createTestRepository()
        let server = ServerConfig(name: "Test NAS", host: "10.0.0.5")
        try repo.addServer(server, password: "secret_password")
        #expect(repo.getPassword(for: server.id) == "secret_password")

        try repo.updateServer(server, password: nil)
        #expect(repo.getPassword(for: server.id) == nil)
    }
}
