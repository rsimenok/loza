//
//  TorrentStatus.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import SwiftUI

/// Transmission RPC torrent status codes.
/// Reference: https://github.com/transmission/transmission/blob/main/docs/rpc-spec.md
nonisolated public enum TorrentStatus: Int, Codable, Sendable, CaseIterable, Comparable, Identifiable {
    case stopped = 0
    case checkWait = 1
    case check = 2
    case downloadWait = 3
    case download = 4
    case seedWait = 5
    case seed = 6

    public var id: Int { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Int.self)
        self = TorrentStatus(rawValue: raw) ?? .stopped
    }

    public static func < (lhs: TorrentStatus, rhs: TorrentStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Human-readable title
    public var displayTitle: String {
        switch self {
        case .stopped:
            return String(localized: "Stopped")
        case .checkWait:
            return String(localized: "Queued for Check")
        case .check:
            return String(localized: "Checking")
        case .downloadWait:
            return String(localized: "Queued for Download")
        case .download:
            return String(localized: "Downloading")
        case .seedWait:
            return String(localized: "Queued for Seeding")
        case .seed:
            return String(localized: "Seeding")
        }
    }

    /// Whether the torrent is actively processing (not paused/stopped)
    public var isRunning: Bool {
        self != .stopped
    }

    /// Whether the torrent is downloading or waiting to download
    public var isDownloading: Bool {
        self == .download || self == .downloadWait
    }

    /// Whether the torrent is seeding or waiting to seed
    public var isSeeding: Bool {
        self == .seed || self == .seedWait
    }

    /// Whether the torrent is checking files
    public var isChecking: Bool {
        self == .check || self == .checkWait
    }

    /// SF Symbol icon name representing the status
    public var systemImageName: String {
        switch self {
        case .stopped:
            return "pause.fill"
        case .checkWait:
            return "hourglass"
        case .check:
            return "arrow.triangle.2.circlepath"
        case .downloadWait:
            return "clock.arrow.circlepath"
        case .download:
            return "arrow.down.circle.fill"
        case .seedWait:
            return "clock"
        case .seed:
            return "arrow.up.circle.fill"
        }
    }

    /// Localized name of the status.
    public var localizedName: String {
        displayTitle
    }

    /// Badge color representing the status.
    public var badgeColor: Color {
        switch self {
        case .download:
            return .blue
        case .seed:
            return .green
        case .stopped:
            return .secondary
        case .check, .checkWait:
            return .orange
        case .downloadWait, .seedWait:
            return .purple
        }
    }
}
