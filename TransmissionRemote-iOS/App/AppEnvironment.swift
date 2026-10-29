//
//  AppEnvironment.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import Observation

@Observable
@MainActor
public final class AppEnvironment {
    public let serverRepository: ServerRepositoryProtocol
    public private(set) var activeServer: ServerConfig?
    public private(set) var currentClient: TransmissionClientProtocol?

    /// Pending magnet URL queued from deep linking (e.g. magnet:?xt=...)
    public var pendingMagnetURL: String?
    /// Flag controlling whether the Add Torrent sheet is presented.
    public var showAddTorrentSheet: Bool = false

    private let clientFactory: (ServerConfig) -> TransmissionClientProtocol

    /// Returns true if at least one server is configured in the repository.
    public var hasConfiguredServer: Bool {
        !serverRepository.servers.isEmpty
    }

    public init(
        serverRepository: ServerRepositoryProtocol? = nil,
        clientFactory: ((ServerConfig) -> TransmissionClientProtocol)? = nil
    ) {
        self.serverRepository = serverRepository ?? ServerRepository()
        self.clientFactory = clientFactory ?? { config in
            TransmissionClient(config: config)
        }
        self.syncActiveServer()
    }

    /// Factory method to create a TransmissionClientProtocol instance for any server configuration.
    public func makeClient(for config: ServerConfig) -> TransmissionClientProtocol {
        clientFactory(config)
    }

    /// Select an active server by ID and update the active client.
    public func selectServer(id: UUID?) {
        serverRepository.setActiveServer(id: id)
        syncActiveServer()
    }

    /// Switch active server to the given configuration and update the active client.
    public func switchServer(to config: ServerConfig) {
        serverRepository.setActiveServer(id: config.id)
        syncActiveServer()
    }

    /// Synchronizes active server and current client with the repository's current state.
    public func syncActiveServer() {
        let latestServer = serverRepository.activeServer
        if activeServer != latestServer {
            activeServer = latestServer
            if let latestServer {
                currentClient = clientFactory(latestServer)
            } else {
                currentClient = nil
            }
        } else if latestServer == nil {
            activeServer = nil
            currentClient = nil
        }
    }

    public func addServer(_ server: ServerConfig, password: String? = nil) throws {
        try serverRepository.addServer(server, password: password)
        syncActiveServer()
    }

    public func updateServer(_ server: ServerConfig, password: String? = nil) throws {
        try serverRepository.updateServer(server, password: password)
        syncActiveServer()
    }

    public func deleteServer(id: UUID) throws {
        try serverRepository.deleteServer(id: id)
        syncActiveServer()
    }

    /// Handles incoming deep links (e.g. magnet: URLs).
    public func handleOpenURL(_ url: URL) {
        if url.scheme?.lowercased() == "magnet" {
            self.pendingMagnetURL = url.absoluteString
            self.showAddTorrentSheet = true
        }
    }
}
