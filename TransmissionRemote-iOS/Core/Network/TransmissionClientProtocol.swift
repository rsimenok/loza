//
//  TransmissionClientProtocol.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation

/// Protocol defining operations for interacting with a Transmission daemon.
public protocol TransmissionClientProtocol: Sendable {
    /// Test connection to the specified server configuration.
    func testConnection(config: ServerConfig) async throws -> SessionStats

    /// Test connection to the specified server configuration with explicit password.
    func testConnection(config: ServerConfig, password: String?) async throws -> SessionStats

    /// Fetch all torrents from the active server.
    func fetchTorrents() async throws -> [Torrent]

    /// Fetch session statistics from the active server.
    func fetchSessionStats() async throws -> SessionStats

    /// Start (or resume) torrents with the specified IDs.
    func startTorrents(ids: [Int]) async throws

    /// Stop (or pause) torrents with the specified IDs.
    func stopTorrents(ids: [Int]) async throws

    /// Remove torrents with option to delete downloaded files.
    func removeTorrents(ids: [Int], deleteLocalData: Bool) async throws

    /// Add a new torrent via magnet URL, HTTP/HTTPS URL, or base64-encoded .torrent file.
    func addTorrent(magnetOrUrl: String?, base64Metainfo: String?, downloadDir: String?) async throws

    /// Add a new torrent with optional paused status.
    func addTorrent(magnetOrUrl: String?, base64Metainfo: String?, downloadDir: String?, paused: Bool?) async throws
}

extension TransmissionClientProtocol {
    public func testConnection(config: ServerConfig) async throws -> SessionStats {
        try await testConnection(config: config, password: nil)
    }

    public func addTorrent(magnetOrUrl: String?, base64Metainfo: String?, downloadDir: String?) async throws {
        try await addTorrent(magnetOrUrl: magnetOrUrl, base64Metainfo: base64Metainfo, downloadDir: downloadDir, paused: nil)
    }
}
