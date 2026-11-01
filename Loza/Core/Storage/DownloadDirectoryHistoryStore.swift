//
//  DownloadDirectoryHistoryStore.swift
//  Loza
//
//  Created by Roman Simenok on 01.11.2026.
//

import Foundation

public final class DownloadDirectoryHistoryStore: Sendable {
    private let userDefaults: UserDefaults
    private let maxEntries: Int

    public init(userDefaults: UserDefaults = .standard, maxEntries: Int = 10) {
        self.userDefaults = userDefaults
        self.maxEntries = maxEntries
    }

    private func storageKey(forServerId serverId: UUID) -> String {
        "download_dir_history_\(serverId.uuidString)"
    }

    public func getRecentPaths(forServerId serverId: UUID) -> [String] {
        userDefaults.stringArray(forKey: storageKey(forServerId: serverId)) ?? []
    }

    public func recordPath(_ path: String, forServerId serverId: UUID) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed != "-" && trimmed != "—" && trimmed != "--" else { return }

        var current = getRecentPaths(forServerId: serverId)
        current.removeAll { $0 == trimmed }
        current.insert(trimmed, at: 0)
        if current.count > maxEntries {
            current = Array(current.prefix(maxEntries))
        }
        userDefaults.set(current, forKey: storageKey(forServerId: serverId))
    }

    public func clearHistory(forServerId serverId: UUID) {
        userDefaults.removeObject(forKey: storageKey(forServerId: serverId))
    }
}
