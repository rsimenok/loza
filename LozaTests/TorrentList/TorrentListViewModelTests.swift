//
//  TorrentListViewModelTests.swift
//  LozaTests
//
//  Created by Roman Simenok on 29.10.2026.
//

import XCTest
import SwiftUI
@testable import Loza

@MainActor
final class TorrentListViewModelTests: XCTestCase {

    private func makeSampleTorrents() -> [Torrent] {
        [
            Torrent(
                id: 1,
                name: "Ubuntu 24.04 Desktop amd64",
                status: .download,
                rateDownload: 4_500_000,
                rateUpload: 120_000,
                percentDone: 0.5,
                totalSize: 6_000_000_000
            ),
            Torrent(
                id: 2,
                name: "Debian 12 Netinst",
                status: .downloadWait,
                rateDownload: 0,
                rateUpload: 0,
                percentDone: 0.1,
                totalSize: 700_000_000
            ),
            Torrent(
                id: 3,
                name: "Fedora 40 Workstation Live",
                status: .seed,
                rateDownload: 0,
                rateUpload: 1_200_000,
                percentDone: 1.0,
                totalSize: 2_000_000_000
            ),
            Torrent(
                id: 4,
                name: "CentOS Stream 9",
                status: .seedWait,
                rateDownload: 0,
                rateUpload: 0,
                percentDone: 1.0,
                totalSize: 1_500_000_000
            ),
            Torrent(
                id: 5,
                name: "Arch Linux 2024",
                status: .stopped,
                rateDownload: 0,
                rateUpload: 0,
                percentDone: 0.35,
                totalSize: 1_100_000_000
            ),
            Torrent(
                id: 6,
                name: "LibreOffice dmg",
                status: .stopped,
                rateDownload: 0,
                rateUpload: 0,
                percentDone: 0.2,
                totalSize: 300_000_000,
                errorString: "Tracker returned 404"
            ),
            Torrent(
                id: 7,
                name: "Alpine Linux Standard",
                status: .check,
                rateDownload: 0,
                rateUpload: 0,
                percentDone: 0.05,
                totalSize: 200_000_000
            )
        ]
    }

    // MARK: - Filter Tests

    func testFilterAll() {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        vm.torrents = makeSampleTorrents()
        vm.selectedFilter = .all

        XCTAssertEqual(vm.filteredTorrents.count, 7)
        XCTAssertEqual(vm.filteredTorrents.map(\.id), [7, 5, 4, 2, 3, 6, 1])
    }

    func testTorrentsSortedByName() {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        vm.torrents = [
            Torrent(id: 1, name: "Ubuntu 24.10"),
            Torrent(id: 2, name: "Ubuntu 24.2"),
            Torrent(id: 3, name: "alpine linux"),
            Torrent(id: 4, name: "Fedora Workstation")
        ]

        // Natural case-insensitive alphabetical sort: alpine -> Fedora -> Ubuntu 24.2 -> Ubuntu 24.10
        XCTAssertEqual(vm.filteredTorrents.map(\.id), [3, 4, 2, 1])
    }

    func testFilterDownloading() {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        vm.torrents = makeSampleTorrents()
        vm.selectedFilter = .downloading

        let ids = vm.filteredTorrents.map(\.id)
        XCTAssertEqual(ids, [2, 1])
    }

    func testFilterSeeding() {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        vm.torrents = makeSampleTorrents()
        vm.selectedFilter = .seeding

        let ids = vm.filteredTorrents.map(\.id)
        XCTAssertEqual(ids, [4, 3])
    }

    func testFilterPaused() {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        vm.torrents = makeSampleTorrents()
        vm.selectedFilter = .paused

        let ids = vm.filteredTorrents.map(\.id)
        XCTAssertEqual(ids, [5, 6])
    }

    func testFilterError() {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        vm.torrents = makeSampleTorrents()
        vm.selectedFilter = .error

        let ids = vm.filteredTorrents.map(\.id)
        XCTAssertEqual(ids, [6])
    }

    // MARK: - Search Query Tests

    func testSearchQueryFiltering() {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        vm.torrents = makeSampleTorrents()

        // 1. Exact case match
        vm.searchQuery = "Ubuntu"
        XCTAssertEqual(vm.filteredTorrents.map(\.id), [1])

        // 2. Case-insensitive search (Alpine Linux Standard = 7, Arch Linux 2024 = 5)
        vm.searchQuery = "linux"
        XCTAssertEqual(vm.filteredTorrents.map(\.id), [7, 5])

        // 3. Search with surrounding whitespace
        vm.searchQuery = "  Debian  "
        XCTAssertEqual(vm.filteredTorrents.map(\.id), [2])

        // 4. Combined with category filter
        vm.selectedFilter = .downloading
        vm.searchQuery = "debian"
        XCTAssertEqual(vm.filteredTorrents.map(\.id), [2])

        vm.searchQuery = "arch"
        XCTAssertTrue(vm.filteredTorrents.isEmpty)

        // 5. Empty search resets to full category filter
        vm.searchQuery = "   "
        XCTAssertEqual(vm.filteredTorrents.map(\.id), [2, 1])
    }

    // MARK: - Count for Filter Tests

    func testCountForFilters() {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        vm.torrents = makeSampleTorrents()

        XCTAssertEqual(vm.count(for: .all), 7)
        XCTAssertEqual(vm.count(for: .downloading), 2)
        XCTAssertEqual(vm.count(for: .seeding), 2)
        XCTAssertEqual(vm.count(for: .paused), 2)
        XCTAssertEqual(vm.count(for: .error), 1)
    }

    // MARK: - ScenePhase Polling Tests

    func testScenePhaseChanges() {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock, pollingInterval: 60)

        // Initially not polling
        XCTAssertFalse(vm.isPolling)

        // Active phase starts polling
        vm.handleScenePhaseChange(to: .active)
        XCTAssertTrue(vm.isPolling)

        // Background phase stops polling (0% battery drain)
        vm.handleScenePhaseChange(to: .background)
        XCTAssertFalse(vm.isPolling)

        // Inactive phase also stops polling
        vm.handleScenePhaseChange(to: .active)
        XCTAssertTrue(vm.isPolling)
        vm.handleScenePhaseChange(to: .inactive)
        XCTAssertFalse(vm.isPolling)

        // Stop polling manually
        vm.startPolling()
        XCTAssertTrue(vm.isPolling)
        vm.stopPolling()
        XCTAssertFalse(vm.isPolling)
    }

    // MARK: - Action Tests

    func testStartTorrent() async {
        let sample = Torrent(id: 42, name: "Test Torrent", status: .stopped, percentDone: 0.5)
        let mock = MockTransmissionClient(initialTorrents: [sample], simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        await vm.refresh()

        XCTAssertEqual(vm.torrents.first?.status, .stopped)

        await vm.startTorrent(id: 42)

        XCTAssertEqual(vm.torrents.first?.status, .download)
    }

    func testStopTorrent() async {
        let sample = Torrent(id: 42, name: "Test Torrent", status: .download, percentDone: 0.5)
        let mock = MockTransmissionClient(initialTorrents: [sample], simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        await vm.refresh()

        XCTAssertEqual(vm.torrents.first?.status, .download)

        await vm.stopTorrent(id: 42)

        XCTAssertEqual(vm.torrents.first?.status, .stopped)
    }

    func testToggleTorrentState() async {
        let sample = Torrent(id: 42, name: "Test Torrent", status: .stopped, percentDone: 0.5)
        let mock = MockTransmissionClient(initialTorrents: [sample], simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        await vm.refresh()

        // Toggle stopped -> starts download
        await vm.toggleTorrentState(torrent: vm.torrents[0])
        XCTAssertEqual(vm.torrents.first?.status, .download)

        // Toggle running -> stops
        await vm.toggleTorrentState(torrent: vm.torrents[0])
        XCTAssertEqual(vm.torrents.first?.status, .stopped)
    }

    func testDeleteTorrentWithoutLocalData() async {
        let sample1 = Torrent(id: 10, name: "Keep Me", status: .stopped)
        let sample2 = Torrent(id: 20, name: "Delete Me", status: .download)
        let mock = MockTransmissionClient(initialTorrents: [sample1, sample2], simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        await vm.refresh()

        XCTAssertEqual(vm.torrents.count, 2)

        vm.confirmDelete(for: sample2)
        XCTAssertTrue(vm.showDeleteConfirmation)
        XCTAssertEqual(vm.torrentToDelete?.id, 20)

        await vm.deleteTorrent(id: 20, deleteLocalData: false)

        XCTAssertEqual(vm.torrents.count, 1)
        XCTAssertEqual(vm.torrents.first?.id, 10)
        XCTAssertNil(vm.torrentToDelete)
        XCTAssertFalse(vm.showDeleteConfirmation)
    }

    func testDeleteTorrentWithLocalData() async {
        let sample = Torrent(id: 30, name: "Remove All", status: .seed)
        let mock = MockTransmissionClient(initialTorrents: [sample], simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        await vm.refresh()

        XCTAssertEqual(vm.torrents.count, 1)

        await vm.deleteTorrent(id: 30, deleteLocalData: true)

        XCTAssertTrue(vm.torrents.isEmpty)
    }

    func testRefreshAndErrorHandling() async {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        mock.shouldFailWithError = .rpcError(message: "Connection refused")
        let vm = TorrentListViewModel(client: mock)

        await vm.refresh()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.errorMessage?.contains("Connection refused") == true)

        // Recovery
        mock.shouldFailWithError = nil
        await vm.refresh()

        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.torrents.isEmpty)
    }

    func testResetForNewServerClearsErrorAndRefreshes() async {
        let mock = MockTransmissionClient(simulatedDelayNanoseconds: 0)
        let vm = TorrentListViewModel(client: mock)
        vm.errorMessage = "401 Unauthorized"
        vm.torrents = [Torrent(id: 999, name: "Old Server Torrent", status: .download)]

        vm.resetForNewServer()

        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.torrents.isEmpty)

        // Give the spawned task a moment to refresh from mock
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.torrents.isEmpty)
    }
}
