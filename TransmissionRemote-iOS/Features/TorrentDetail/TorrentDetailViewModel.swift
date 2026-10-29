//
//  TorrentDetailViewModel.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class TorrentDetailViewModel {
    // MARK: - Published State

    var torrent: Torrent
    var isLoading: Bool = false
    var errorMessage: String?
    var isDeleted: Bool = false

    // MARK: - Dependencies & Polling Configuration

    weak var environment: AppEnvironment?
    private var explicitClient: TransmissionClientProtocol?
    var pollingInterval: TimeInterval

    nonisolated(unsafe) private var pollingTask: Task<Void, Never>?

    /// Tracks an optimistic status transition (e.g. paused/resumed) until the server catches up.
    private var pendingStatus: TorrentStatus?
    private var pendingStatusTimestamp: Date?

    /// Indicates whether background polling is currently running.
    var isPolling: Bool {
        pollingTask != nil && !(pollingTask?.isCancelled ?? true)
    }

    var client: TransmissionClientProtocol? {
        explicitClient ?? environment?.currentClient
    }

    // MARK: - Initialization

    init(
        torrent: Torrent,
        client: TransmissionClientProtocol? = nil,
        environment: AppEnvironment? = nil,
        pollingInterval: TimeInterval = 2.5
    ) {
        self.torrent = torrent
        self.explicitClient = client
        self.environment = environment
        self.pollingInterval = pollingInterval
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Polling Management

    /// Starts polling the server every `pollingInterval` seconds.
    func startPolling() {
        guard pollingTask == nil || pollingTask?.isCancelled == true else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
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

    /// Cancels active polling to conserve battery when inactive or in the background.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Handles scene phase changes: suspends polling in background, resumes when active.
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

    // MARK: - Actions

    /// Toggles the running/stopped state of the torrent.
    func toggleState() async {
        if torrent.status.isRunning {
            await stop()
        } else {
            await start()
        }
    }

    /// Starts or resumes the torrent.
    func start() async {
        guard let client = client else {
            self.errorMessage = "Немає активного сервера"
            return
        }

        let targetStatus: TorrentStatus = torrent.isCompleted ? .seed : .download
        pendingStatus = targetStatus
        pendingStatusTimestamp = Date()
        torrent.status = targetStatus
        errorMessage = nil

        do {
            try await client.startTorrents(ids: [torrent.id])
            await refresh()
        } catch {
            pendingStatus = nil
            self.errorMessage = error.localizedDescription
            await refresh()
        }
    }

    /// Stops or pauses the torrent.
    func stop() async {
        guard let client = client else {
            self.errorMessage = "Немає активного сервера"
            return
        }

        pendingStatus = .stopped
        pendingStatusTimestamp = Date()
        torrent.status = .stopped
        torrent.rateDownload = 0
        torrent.rateUpload = 0
        errorMessage = nil

        do {
            try await client.stopTorrents(ids: [torrent.id])
            await refresh()
        } catch {
            pendingStatus = nil
            self.errorMessage = error.localizedDescription
            await refresh()
        }
    }

    /// Deletes the torrent, with an option to remove downloaded local data.
    func delete(deleteLocalData: Bool) async throws {
        guard let client = client else {
            let error = TransmissionError.noActiveServer
            self.errorMessage = error.localizedDescription
            throw error
        }

        stopPolling()
        do {
            try await client.removeTorrents(ids: [torrent.id], deleteLocalData: deleteLocalData)
            self.isDeleted = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Refreshes the torrent details by fetching latest data from the server.
    func refresh() async {
        guard !isDeleted, let client = client else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let torrents = try await client.fetchTorrents()
            if var updated = torrents.first(where: { $0.id == torrent.id }) {
                if let pending = pendingStatus {
                    let now = Date()
                    if let ts = pendingStatusTimestamp, now.timeIntervalSince(ts) > 10 {
                        // Optimistic transition timed out, trust the server state
                        pendingStatus = nil
                    } else if (pending == .stopped && updated.status == .stopped) ||
                              (pending != .stopped && updated.status.isRunning) {
                        // Server caught up with requested status
                        pendingStatus = nil
                    } else {
                        // Server is still in asynchronous transition; keep optimistic user-intended status
                        updated.status = pending
                        if pending == .stopped {
                            updated.rateDownload = 0
                            updated.rateUpload = 0
                        }
                    }
                }
                self.torrent = updated
            }
            self.errorMessage = nil
        } catch is CancellationError {
            // Task was cancelled, do nothing
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
