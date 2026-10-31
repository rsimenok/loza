//
//  TorrentDetailViewModelTests.swift
//  LozaTests
//
//  Created by Roman Simenok on 29.10.2026.
//

import XCTest
import SwiftUI
@testable import Loza

@MainActor
final class TorrentDetailViewModelTests: XCTestCase {

    private func makeSampleTorrent() -> Torrent {
        Torrent(
            id: 3,
            name: "archlinux-2024.10.01-x86_64.iso",
            status: .stopped,
            rateDownload: 0,
            rateUpload: 0,
            percentDone: 0.42,
            totalSize: 1_180_000_000,
            eta: -1,
            errorString: "",
            peersConnected: 0,
            peersSendingToUs: 0,
            peersGettingFromUs: 0,
            uploadedEver: 120_000_000,
            downloadedEver: 495_600_000,
            uploadRatio: 0.24,
            files: [
                TorrentFile(
                    id: 0,
                    name: "archlinux-2024.10.01-x86_64.iso",
                    bytesCompleted: 495_600_000,
                    length: 1_180_000_000,
                    wanted: true,
                    priority: 0
                )
            ],
            hashString: "e4d909c290d0fb1ca068ffaddf22cbd000e3408a",
            addedDate: Date(timeIntervalSince1970: 1729900000)
        )
    }

    private func makeClient() -> MockTransmissionClient {
        MockTransmissionClient(simulatedDelayNanoseconds: 0)
    }

    // MARK: - Initial State Tests

    func testInitialState() async {
        let client = makeClient()
        let torrent = makeSampleTorrent()
        let vm = TorrentDetailViewModel(torrent: torrent, client: client)

        XCTAssertEqual(vm.torrent.id, 3)
        XCTAssertEqual(vm.torrent.name, "archlinux-2024.10.01-x86_64.iso")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isDeleted)
    }

    // MARK: - Start & Stop Tests

    func testStartTorrent() async {
        let client = makeClient()
        let torrent = makeSampleTorrent()
        let vm = TorrentDetailViewModel(torrent: torrent, client: client)
        XCTAssertEqual(vm.torrent.status, .stopped)

        await vm.start()

        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.torrent.status, .download)
        XCTAssertGreaterThan(vm.torrent.rateDownload, 0)
    }

    func testStopTorrent() async {
        let client = makeClient()
        let downloadingTorrent = Torrent(
            id: 1,
            name: "ubuntu.iso",
            status: .download,
            rateDownload: 2_000_000,
            rateUpload: 100_000,
            percentDone: 0.5
        )
        let vm = TorrentDetailViewModel(torrent: downloadingTorrent, client: client)

        await vm.stop()

        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.torrent.status, .stopped)
        XCTAssertEqual(vm.torrent.rateDownload, 0)
        XCTAssertEqual(vm.torrent.rateUpload, 0)
    }

    func testToggleState() async {
        let client = makeClient()
        let torrent = makeSampleTorrent()
        let vm = TorrentDetailViewModel(torrent: torrent, client: client)
        XCTAssertFalse(vm.torrent.status.isRunning)

        // 1. Toggling a stopped torrent should start it
        await vm.toggleState()
        XCTAssertTrue(vm.torrent.status.isRunning)
        XCTAssertEqual(vm.torrent.status, .download)

        // 2. Toggling a running torrent should stop it
        await vm.toggleState()
        XCTAssertFalse(vm.torrent.status.isRunning)
        XCTAssertEqual(vm.torrent.status, .stopped)
    }

    // MARK: - Delete Tests

    func testDeleteWithoutLocalData() async throws {
        let client = makeClient()
        let torrent = makeSampleTorrent()
        let vm = TorrentDetailViewModel(torrent: torrent, client: client)

        try await vm.delete(deleteLocalData: false)

        XCTAssertTrue(vm.isDeleted)
        XCTAssertNil(vm.errorMessage)

        let remaining = try await client.fetchTorrents()
        XCTAssertNil(remaining.first(where: { $0.id == torrent.id }))
    }

    func testDeleteWithLocalData() async throws {
        let client = makeClient()
        let torrent = makeSampleTorrent()
        let vm = TorrentDetailViewModel(torrent: torrent, client: client)

        try await vm.delete(deleteLocalData: true)

        XCTAssertTrue(vm.isDeleted)
        XCTAssertNil(vm.errorMessage)

        let remaining = try await client.fetchTorrents()
        XCTAssertNil(remaining.first(where: { $0.id == torrent.id }))
    }

    // MARK: - Refresh Tests

    func testRefreshSuccess() async {
        let client = makeClient()
        let torrent = makeSampleTorrent()
        let vm = TorrentDetailViewModel(torrent: torrent, client: client)

        try? await client.startTorrents(ids: [torrent.id])

        await vm.refresh()

        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.torrent.status, .download)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - Error Handling Tests

    func testErrorHandlingOnClientFailure() async {
        let client = makeClient()
        client.shouldFailWithError = .unauthorized
        let torrent = makeSampleTorrent()
        let vm = TorrentDetailViewModel(torrent: torrent, client: client)

        await vm.start()
        XCTAssertNotNil(vm.errorMessage)

        await vm.refresh()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)

        do {
            try await vm.delete(deleteLocalData: false)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertNotNil(vm.errorMessage)
        }
    }

    func testActionsWithoutClient() async {
        let torrent = makeSampleTorrent()
        let vm = TorrentDetailViewModel(torrent: torrent, client: nil, environment: nil)

        await vm.start()
        XCTAssertEqual(vm.errorMessage, "Немає активного сервера")

        await vm.stop()
        XCTAssertEqual(vm.errorMessage, "Немає активного сервера")

        do {
            try await vm.delete(deleteLocalData: false)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is TransmissionError)
        }
    }

    // MARK: - Polling & Optimistic State Tests

    func testStopTorrentPreservesOptimisticStateWhenServerTransitionsAsynchronously() async {
        // A client that simulates Transmission daemon returning stale .download status on immediate fetch
        final class AsyncStoppingMockClient: TransmissionClientProtocol, @unchecked Sendable {
            var returnedStatus: TorrentStatus = .download
            func testConnection(config: ServerConfig) async throws -> SessionStats { SessionStats(downloadSpeed: 0, uploadSpeed: 0, torrentCount: 1, activeTorrentCount: 1, pausedTorrentCount: 0) }
            func testConnection(config: ServerConfig, password: String?) async throws -> SessionStats { try await testConnection(config: config) }
            func fetchTorrents() async throws -> [Torrent] {
                [
                    Torrent(
                        id: 42,
                        name: "test.iso",
                        status: returnedStatus,
                        rateDownload: 1_500_000,
                        rateUpload: 50_000,
                        percentDone: 0.5
                    )
                ]
            }
            func fetchSessionStats() async throws -> SessionStats { SessionStats(downloadSpeed: 0, uploadSpeed: 0, torrentCount: 1, activeTorrentCount: 1, pausedTorrentCount: 0) }
            func startTorrents(ids: [Int]) async throws { returnedStatus = .download }
            func stopTorrents(ids: [Int]) async throws {
                // In real Transmission, the server returns HTTP 200 before transitioning internal state.
                // Leave returnedStatus as .download for the immediate fetch!
            }
            func removeTorrents(ids: [Int], deleteLocalData: Bool) async throws {}
            func addTorrent(magnetOrUrl: String?, base64Metainfo: String?, downloadDir: String?, paused: Bool?) async throws {}
        }

        let mockClient = AsyncStoppingMockClient()
        let initialTorrent = Torrent(id: 42, name: "test.iso", status: .download, rateDownload: 1_500_000, rateUpload: 50_000, percentDone: 0.5)
        let vm = TorrentDetailViewModel(torrent: initialTorrent, client: mockClient)

        // User pauses torrent on detail screen
        await vm.stop()

        // Even though mockClient.fetchTorrents() returned .download, the VM must preserve .stopped!
        XCTAssertEqual(vm.torrent.status, .stopped, "Torrent detail view model must not revert to .download when stopped")
        XCTAssertEqual(vm.torrent.rateDownload, 0)
        XCTAssertEqual(vm.torrent.rateUpload, 0)

        // When the server finally reports .stopped, pendingStatus clears naturally
        mockClient.returnedStatus = .stopped
        await vm.refresh()
        XCTAssertEqual(vm.torrent.status, .stopped)
    }

    func testPollingLifecycleAndScenePhase() async {
        let client = makeClient()
        let torrent = makeSampleTorrent()
        let vm = TorrentDetailViewModel(torrent: torrent, client: client, pollingInterval: 0.1)

        XCTAssertFalse(vm.isPolling)

        vm.startPolling()
        XCTAssertTrue(vm.isPolling)

        vm.handleScenePhaseChange(to: .background)
        XCTAssertFalse(vm.isPolling)

        vm.handleScenePhaseChange(to: .active)
        XCTAssertTrue(vm.isPolling)

        vm.stopPolling()
        XCTAssertFalse(vm.isPolling)
    }
}
