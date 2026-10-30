//
//  TorrentListViewModel.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class TorrentListViewModel {
    // MARK: - Published State

    var torrents: [Torrent] = []
    var sessionStats: SessionStats?
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedFilter: TorrentFilter = .all
    var searchQuery: String = ""
    var torrentToDelete: Torrent?
    var showDeleteConfirmation: Bool = false

    // MARK: - Dependencies & Configuration

    weak var environment: AppEnvironment?
    private var explicitClient: TransmissionClientProtocol?
    var pollingInterval: TimeInterval

    nonisolated(unsafe) private var pollingTask: Task<Void, Never>?
    private var pendingStatusByTorrentId: [Int: (status: TorrentStatus, timestamp: Date)] = [:]

    /// Indicates whether background polling is currently running.
    var isPolling: Bool {
        pollingTask != nil && !(pollingTask?.isCancelled ?? true)
    }

    /// Resolves the active Transmission client from explicit injection or current AppEnvironment.
    var client: TransmissionClientProtocol? {
        explicitClient ?? environment?.currentClient
    }

    // MARK: - Initialization

    init(
        client: TransmissionClientProtocol? = nil,
        environment: AppEnvironment? = nil,
        pollingInterval: TimeInterval = 2.5
    ) {
        self.explicitClient = client
        self.environment = environment
        self.pollingInterval = pollingInterval
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Computed Properties

    /// Filtered list of torrents based on selectedFilter and searchQuery, sorted by name.
    var filteredTorrents: [Torrent] {
        let filter = selectedFilter
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        return torrents
            .filter { torrent in
                guard filter.matches(torrent) else { return false }
                if !trimmedQuery.isEmpty {
                    return torrent.name.localizedCaseInsensitiveContains(trimmedQuery)
                }
                return true
            }
            .sorted { lhs, rhs in
                let comparison = lhs.name.localizedStandardCompare(rhs.name)
                if comparison == .orderedSame {
                    return lhs.id < rhs.id
                }
                return comparison == .orderedAscending
            }
    }

    /// Returns the number of torrents matching the given filter.
    func count(for filter: TorrentFilter) -> Int {
        torrents.filter { filter.matches($0) }.count
    }

    // MARK: - Polling Management

    /// Starts polling the server every `pollingInterval` seconds.
    func startPolling() {
        guard pollingTask == nil || pollingTask?.isCancelled == true else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                guard !Task.isCancelled else { break }

                let interval = self?.pollingInterval ?? 2.5
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }

    /// Cancels active polling to conserve battery when the app is inactive or in background.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Handles lifecycle phase changes: cancels polling when backgrounded, resumes when active.
    func handleScenePhaseChange(to phase: ScenePhase) {
        switch phase {
        case .active:
            startPolling()
        case .background, .inactive:
            stopPolling()
        @unknown default:
            stopPolling()
        }
    }

    // MARK: - Data Fetching

    /// Refreshes torrents and session stats.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        await pollOnce()
    }

    /// Fetches the latest torrents and session statistics in parallel.
    func pollOnce() async {
        guard let client = client else {
            return
        }

        do {
            async let fetchedTorrents = client.fetchTorrents()
            async let fetchedStats = client.fetchSessionStats()
            var (newTorrents, newStats) = try await (fetchedTorrents, fetchedStats)

            let now = Date()
            for index in newTorrents.indices {
                let id = newTorrents[index].id
                if let pending = pendingStatusByTorrentId[id] {
                    if now.timeIntervalSince(pending.timestamp) > 10 {
                        pendingStatusByTorrentId.removeValue(forKey: id)
                    } else if (pending.status == .stopped && newTorrents[index].status == .stopped) ||
                              (pending.status != .stopped && newTorrents[index].status.isRunning) {
                        pendingStatusByTorrentId.removeValue(forKey: id)
                    } else {
                        newTorrents[index].status = pending.status
                        if pending.status == .stopped {
                            newTorrents[index].rateDownload = 0
                            newTorrents[index].rateUpload = 0
                        }
                    }
                }
            }

            if self.torrents != newTorrents {
                self.torrents = newTorrents
            }
            if self.sessionStats != newStats {
                self.sessionStats = newStats
            }
            if self.errorMessage != nil {
                self.errorMessage = nil
            }
        } catch is CancellationError {
            // Task cancelled, don't set error
        } catch {
            let message = error.localizedDescription
            if self.errorMessage != message {
                self.errorMessage = message
            }
        }
    }

    /// Resets state when switching to a different active server.
    func resetForNewServer() {
        torrents = []
        sessionStats = nil
        errorMessage = nil
        Task {
            await refresh()
        }
    }

    // MARK: - Torrent Actions

    /// Toggles the running/stopped state of a torrent.
    func toggleTorrentState(torrent: Torrent) async {
        if torrent.status.isRunning {
            await stopTorrent(id: torrent.id)
        } else {
            await startTorrent(id: torrent.id)
        }
    }

    /// Starts a torrent by ID.
    func startTorrent(id: Int) async {
        guard let client = client else { return }
        let isCompleted = torrents.first(where: { $0.id == id })?.isCompleted ?? false
        let targetStatus: TorrentStatus = isCompleted ? .seed : .download
        pendingStatusByTorrentId[id] = (targetStatus, Date())
        if let index = torrents.firstIndex(where: { $0.id == id }) {
            torrents[index].status = targetStatus
        }
        do {
            try await client.startTorrents(ids: [id])
            await pollOnce()
        } catch {
            pendingStatusByTorrentId.removeValue(forKey: id)
            self.errorMessage = error.localizedDescription
            await pollOnce()
        }
    }

    /// Stops / pauses a torrent by ID.
    func stopTorrent(id: Int) async {
        guard let client = client else { return }
        pendingStatusByTorrentId[id] = (.stopped, Date())
        if let index = torrents.firstIndex(where: { $0.id == id }) {
            torrents[index].status = .stopped
            torrents[index].rateDownload = 0
            torrents[index].rateUpload = 0
        }
        do {
            try await client.stopTorrents(ids: [id])
            await pollOnce()
        } catch {
            pendingStatusByTorrentId.removeValue(forKey: id)
            self.errorMessage = error.localizedDescription
            await pollOnce()
        }
    }

    /// Deletes a torrent, optionally removing downloaded data.
    func deleteTorrent(id: Int, deleteLocalData: Bool) async {
        guard let client = client else { return }
        do {
            try await client.removeTorrents(ids: [id], deleteLocalData: deleteLocalData)
            torrents.removeAll { $0.id == id }
            if torrentToDelete?.id == id {
                torrentToDelete = nil
                showDeleteConfirmation = false
            }
            await pollOnce()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// Prepares confirmation dialog for deleting the specified torrent.
    func confirmDelete(for torrent: Torrent) {
        self.torrentToDelete = torrent
        self.showDeleteConfirmation = true
    }
}
