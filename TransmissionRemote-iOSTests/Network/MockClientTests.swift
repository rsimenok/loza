//
//  MockClientTests.swift
//  TransmissionRemote-iOSTests
//
//  Created by Roman Simenok on 29.10.2026.
//

import XCTest
@testable import TransmissionRemote_iOS

final class MockClientTests: XCTestCase {
    private var client: MockTransmissionClient!

    override func setUp() {
        super.setUp()
        // Use 0 delay for unit tests so they execute instantly
        client = MockTransmissionClient(simulatedDelayNanoseconds: 0)
    }

    override func tearDown() {
        client = nil
        super.tearDown()
    }

    func testInitialTorrents() async throws {
        let torrents = try await client.fetchTorrents()
        XCTAssertEqual(torrents.count, 4)

        // 1. Ubuntu
        let ubuntu = try XCTUnwrap(torrents.first(where: { $0.id == 1 }))
        XCTAssertTrue(ubuntu.name.contains("ubuntu-24.04"))
        XCTAssertEqual(ubuntu.status, .download)
        XCTAssertGreaterThan(ubuntu.rateDownload, 0)
        XCTAssertFalse(ubuntu.isCompleted)

        // 2. Fedora
        let fedora = try XCTUnwrap(torrents.first(where: { $0.id == 2 }))
        XCTAssertTrue(fedora.name.contains("Fedora"))
        XCTAssertEqual(fedora.status, .seed)
        XCTAssertEqual(fedora.percentDone, 1.0)
        XCTAssertTrue(fedora.isCompleted)

        // 3. Arch
        let arch = try XCTUnwrap(torrents.first(where: { $0.id == 3 }))
        XCTAssertTrue(arch.name.contains("archlinux"))
        XCTAssertEqual(arch.status, .stopped)

        // 4. LibreOffice
        let libre = try XCTUnwrap(torrents.first(where: { $0.id == 4 }))
        XCTAssertTrue(libre.name.contains("LibreOffice"))
        XCTAssertTrue(libre.hasError)
        XCTAssertEqual(libre.status, .stopped)
    }

    func testFetchSessionStats() async throws {
        let stats = try await client.fetchSessionStats()

        XCTAssertEqual(stats.torrentCount, 4)
        XCTAssertEqual(stats.activeTorrentCount, 2) // Ubuntu (download) + Fedora (seed)
        XCTAssertEqual(stats.pausedTorrentCount, 2) // Arch + LibreOffice (stopped)
        XCTAssertGreaterThan(stats.downloadSpeed, 0)
        XCTAssertGreaterThan(stats.uploadSpeed, 0)
    }

    func testStartTorrents() async throws {
        // Start Arch (which was stopped)
        try await client.startTorrents(ids: [3])

        let torrents = try await client.fetchTorrents()
        let arch = try XCTUnwrap(torrents.first(where: { $0.id == 3 }))
        XCTAssertEqual(arch.status, .download)
        XCTAssertGreaterThan(arch.rateDownload, 0)

        // Start Fedora (which is 100% completed)
        try await client.startTorrents(ids: [2])
        let fedora = try XCTUnwrap(torrents.first(where: { $0.id == 2 }))
        XCTAssertEqual(fedora.status, .seed)
        XCTAssertGreaterThan(fedora.rateUpload, 0)
    }

    func testStopTorrents() async throws {
        // Stop Ubuntu (which was downloading)
        try await client.stopTorrents(ids: [1])

        let torrents = try await client.fetchTorrents()
        let ubuntu = try XCTUnwrap(torrents.first(where: { $0.id == 1 }))
        XCTAssertEqual(ubuntu.status, .stopped)
        XCTAssertEqual(ubuntu.rateDownload, 0)
        XCTAssertEqual(ubuntu.rateUpload, 0)
    }

    func testRemoveTorrents() async throws {
        try await client.removeTorrents(ids: [3], deleteLocalData: false)

        let torrents = try await client.fetchTorrents()
        XCTAssertEqual(torrents.count, 3)
        XCTAssertNil(torrents.first(where: { $0.id == 3 }))
    }

    func testAddTorrentWithMagnetLink() async throws {
        let magnet = "magnet:?xt=urn:btih:1234567890abcdef&dn=Debian-12-netinst.iso"
        try await client.addTorrent(magnetOrUrl: magnet, base64Metainfo: nil, downloadDir: nil)

        let torrents = try await client.fetchTorrents()
        XCTAssertEqual(torrents.count, 5)

        let added = try XCTUnwrap(torrents.first(where: { $0.name == "Debian-12-netinst.iso" }))
        XCTAssertEqual(added.id, 5)
        XCTAssertEqual(added.status, .download)
        XCTAssertEqual(added.percentDone, 0.02)
    }

    func testTestConnectionSuccess() async throws {
        let config = ServerConfig(name: "Test Server", host: "192.168.1.100", port: 9091)
        let stats = try await client.testConnection(config: config)

        XCTAssertEqual(stats.torrentCount, 4)
    }

    func testTestConnectionInvalidURL() async throws {
        let config = ServerConfig(name: "Invalid Server", host: "")
        do {
            _ = try await client.testConnection(config: config)
            XCTFail("Should have thrown invalidURL error")
        } catch let error as TransmissionError {
            XCTAssertEqual(error, .invalidURL)
        }
    }

    func testConfiguredFailure() async throws {
        client.shouldFailWithError = .unauthorized

        do {
            _ = try await client.fetchTorrents()
            XCTFail("Should have thrown unauthorized error")
        } catch let error as TransmissionError {
            XCTAssertEqual(error, .unauthorized)
        }
    }
}
