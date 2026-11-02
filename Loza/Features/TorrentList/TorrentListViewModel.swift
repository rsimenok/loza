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
    var selectedStatuses: Set<TorrentStatusCategory> = []
    var selectedTags: Set<String> = []
    var selectedTrackers: Set<String> = []
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

    /// Indicates whether any filter is currently applied.
    var hasActiveFilters: Bool {
        !selectedStatuses.isEmpty || !selectedTags.isEmpty || !selectedTrackers.isEmpty
    }

    /// Unique, non-empty, sorted tags collected from all loaded torrents.
    var availableTags: [String] {
        let allTags = torrents
            .flatMap { $0.labels }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(allTags)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Unique, non-empty, sorted tracker hostnames collected from all loaded torrents.
    var availableTrackers: [String] {
        let allTrackers = torrents
            .flatMap { $0.trackerHosts }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(allTrackers)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Filtered list of torrents based on selectedStatuses, selectedTags, selectedTrackers, and searchQuery, sorted by name.
    var filteredTorrents: [Torrent] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        return torrents
            .filter { torrent in
                let matchesStatus = selectedStatuses.isEmpty || selectedStatuses.contains { $0.matches(torrent) }
                guard matchesStatus else { return false }

                let matchesTags = selectedTags.isEmpty || !Set(torrent.labels).isDisjoint(with: selectedTags)
                guard matchesTags else { return false }

                let matchesTrackers = selectedTrackers.isEmpty || !torrent.trackerHosts.isDisjoint(with: selectedTrackers)
                guard matchesTrackers else { return false }

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

    /// Returns the number of torrents matching the given status category.
    func count(forStatus status: TorrentStatusCategory) -> Int {
        torrents.filter { status.matches($0) }.count
    }

    /// Returns the number of torrents containing the given tag.
    func count(forTag tag: String) -> Int {
        torrents.filter { $0.labels.contains(tag) }.count
    }

    /// Returns the number of torrents associated with the given tracker hostname.
    func count(forTracker tracker: String) -> Int {
        torrents.filter { $0.trackerHosts.contains(tracker) }.count
    }

    // MARK: - Filter Actions

    /// Toggles selection of a status category.
    func toggleStatus(_ status: TorrentStatusCategory) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }
    }

    /// Toggles selection of a tag.
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    /// Toggles selection of a tracker hostname.
    func toggleTracker(_ tracker: String) {
        if selectedTrackers.contains(tracker) {
            selectedTrackers.remove(tracker)
        } else {
            selectedTrackers.insert(tracker)
        }
    }

    /// Resets all status, tag, and tracker filters.
    func resetFilters() {
        selectedStatuses.removeAll()
        selectedTags.removeAll()
        selectedTrackers.removeAll()
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

            if self.torrents.count != newTorrents.count || self.torrents.map(\.id) != newTorrents.map(\.id) {
                self.torrents = newTorrents
            } else {
                for index in newTorrents.indices {
                    if self.torrents[index] != newTorrents[index] {
                        self.torrents[index] = newTorrents[index]
                    }
                }
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
        resetFilters()
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
