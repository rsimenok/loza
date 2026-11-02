//
//  TorrentFilter.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation

/// Status filter categories for categorizing and displaying torrent lists.
enum TorrentStatusCategory: String, CaseIterable, Identifiable, Sendable {
    case downloading
    case seeding
    case paused
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
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

    var systemImage: String {
        switch self {
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

    /// Evaluates if a given torrent matches this status category.
    func matches(_ torrent: Torrent) -> Bool {
        switch self {
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

typealias TorrentFilter = TorrentStatusCategory
