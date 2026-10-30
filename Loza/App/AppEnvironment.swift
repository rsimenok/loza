//
//  AppEnvironment.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import Observation

@Observable
@MainActor
final class AppEnvironment {
    let serverRepository: ServerRepositoryProtocol
    let purchaseManager: PurchaseManager
    private(set) var activeServer: ServerConfig?
    private(set) var currentClient: TransmissionClientProtocol?
    private(set) var clientUpdateToken: UUID = UUID()

    /// Pending magnet URL queued from deep linking (e.g. magnet:?xt=...)
    var pendingMagnetURL: String?
    /// Flag controlling whether the Add Torrent sheet is presented.
    var showAddTorrentSheet: Bool = false

    private let clientFactory: (ServerConfig) -> TransmissionClientProtocol

    /// Returns true if at least one server is configured in the repository.
    var hasConfiguredServer: Bool {
        !serverRepository.servers.isEmpty
    }

    init(
        serverRepository: ServerRepositoryProtocol? = nil,
        clientFactory: ((ServerConfig) -> TransmissionClientProtocol)? = nil,
        purchaseManager: PurchaseManager? = nil
    ) {
        self.serverRepository = serverRepository ?? ServerRepository()
        self.clientFactory = clientFactory ?? { config in
            TransmissionClient(config: config)
        }
        self.purchaseManager = purchaseManager ?? PurchaseManager()
        self.syncActiveServer()
    }

    /// Factory method to create a TransmissionClientProtocol instance for any server configuration.
    func makeClient(for config: ServerConfig) -> TransmissionClientProtocol {
        clientFactory(config)
    }

    /// Select an active server by ID and update the active client.
    func selectServer(id: UUID?) {
        serverRepository.setActiveServer(id: id)
        syncActiveServer()
    }

    /// Switch active server to the given configuration and update the active client.
    func switchServer(to config: ServerConfig) {
        serverRepository.setActiveServer(id: config.id)
        syncActiveServer()
    }

    /// Synchronizes active server and current client with the repository's current state.
    func syncActiveServer() {
        let latestServer = serverRepository.activeServer
        activeServer = latestServer
        if let latestServer {
            currentClient = clientFactory(latestServer)
        } else {
            currentClient = nil
        }
        clientUpdateToken = UUID()
    }

    func addServer(_ server: ServerConfig, password: String? = nil) throws {
        try serverRepository.addServer(server, password: password)
        syncActiveServer()
    }

    func updateServer(_ server: ServerConfig, password: String? = nil) throws {
        try serverRepository.updateServer(server, password: password)
        syncActiveServer()
    }

    func deleteServer(id: UUID) throws {
        try serverRepository.deleteServer(id: id)
        syncActiveServer()
    }

    /// Handles incoming deep links (e.g. magnet: URLs).
    func handleOpenURL(_ url: URL) {
        if url.scheme?.lowercased() == "magnet" {
            self.pendingMagnetURL = url.absoluteString
            self.showAddTorrentSheet = true
        }
    }
}
