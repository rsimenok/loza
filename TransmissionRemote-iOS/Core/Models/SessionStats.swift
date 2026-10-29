//
//  SessionStats.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation

nonisolated public struct SessionStats: Codable, Sendable, Equatable, Hashable {
    public var downloadSpeed: Int64
    public var uploadSpeed: Int64
    public var torrentCount: Int
    public var activeTorrentCount: Int
    public var pausedTorrentCount: Int

    public init(
        downloadSpeed: Int64 = 0,
        uploadSpeed: Int64 = 0,
        torrentCount: Int = 0,
        activeTorrentCount: Int = 0,
        pausedTorrentCount: Int = 0
    ) {
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.torrentCount = torrentCount
        self.activeTorrentCount = activeTorrentCount
        self.pausedTorrentCount = pausedTorrentCount
    }

    enum CodingKeys: String, CodingKey {
        case downloadSpeed
        case uploadSpeed
        case torrentCount
        case activeTorrentCount
        case pausedTorrentCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.downloadSpeed = try container.decodeIfPresent(Int64.self, forKey: .downloadSpeed) ?? 0
        self.uploadSpeed = try container.decodeIfPresent(Int64.self, forKey: .uploadSpeed) ?? 0
        self.torrentCount = try container.decodeIfPresent(Int.self, forKey: .torrentCount) ?? 0
        self.activeTorrentCount = try container.decodeIfPresent(Int.self, forKey: .activeTorrentCount) ?? 0
        self.pausedTorrentCount = try container.decodeIfPresent(Int.self, forKey: .pausedTorrentCount) ?? 0
    }

    public var formattedDownloadSpeed: String {
        Torrent.formatSpeed(downloadSpeed)
    }

    public var formattedUploadSpeed: String {
        Torrent.formatSpeed(uploadSpeed)
    }

    public var formattedSpeedSummary: String {
        "↓ \(formattedDownloadSpeed)  ↑ \(formattedUploadSpeed)"
    }
}
