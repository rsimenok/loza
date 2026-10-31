//
//  TorrentFilter.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation

/// Filter categories for categorizing and displaying torrent lists.
public enum TorrentFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case downloading
    case seeding
    case paused
    case error

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            return String(localized: "All")
        case .downloading:
            return String(localized: "Downloading")
        case .seeding:
            return String(localized: "Seeding")
        case .paused:
            return String(localized: "Paused")
        case .error:
            return String(localized: "Errors")
        }
    }

    public var systemImage: String {
        switch self {
        case .all:
            return "tray.full"
        case .downloading:
            return "arrow.down.circle"
        case .seeding:
            return "arrow.up.circle"
        case .paused:
            return "pause.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    /// Evaluates if a given torrent matches this filter category.
    public func matches(_ torrent: Torrent) -> Bool {
        switch self {
        case .all:
            return true
        case .downloading:
            return torrent.status.isDownloading
        case .seeding:
            return torrent.status.isSeeding
        case .paused:
            return torrent.status == .stopped
        case .error:
            return torrent.hasError
        }
    }
}
