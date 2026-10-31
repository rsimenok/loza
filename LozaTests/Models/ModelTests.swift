//
//  ModelTests.swift
//  LozaTests
//
//  Created by Roman Simenok on 29.10.2026.
//

import Testing
import Foundation
@testable import Loza

struct ModelTests {

    // MARK: - ServerConfig Tests

    @Test func testServerConfigEncodingDecoding() throws {
        let server = ServerConfig(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            name: "Home NAS",
            scheme: .https,
            host: "nas.local",
            port: 9091,
            rpcPath: "/transmission/rpc",
            trustSelfSignedCertificates: true,
            username: "admin"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(server)
        let decoded = try JSONDecoder().decode(ServerConfig.self, from: data)

        #expect(decoded.id == server.id)
        #expect(decoded.name == "Home NAS")
        #expect(decoded.scheme == .https)
        #expect(decoded.host == "nas.local")
        #expect(decoded.port == 9091)
        #expect(decoded.rpcPath == "/transmission/rpc")
        #expect(decoded.trustSelfSignedCertificates == true)
        #expect(decoded.username == "admin")
        #expect(decoded.url?.absoluteString == "https://nas.local:9091/transmission/rpc")
        #expect(decoded.displayAddress == "https://nas.local:9091")
    }

    // MARK: - TorrentStatus Tests

    @Test func testTorrentStatusValuesAndProperties() throws {
        #expect(TorrentStatus.stopped.rawValue == 0)
        #expect(TorrentStatus.checkWait.rawValue == 1)
        #expect(TorrentStatus.check.rawValue == 2)
        #expect(TorrentStatus.downloadWait.rawValue == 3)
        #expect(TorrentStatus.download.rawValue == 4)
        #expect(TorrentStatus.seedWait.rawValue == 5)
        #expect(TorrentStatus.seed.rawValue == 6)

        #expect(!TorrentStatus.stopped.isRunning)
        #expect(TorrentStatus.download.isRunning)
        #expect(TorrentStatus.download.isDownloading)
        #expect(TorrentStatus.seed.isSeeding)
        #expect(TorrentStatus.check.isChecking)

        #expect(TorrentStatus.stopped.systemImageName == "pause.fill")
        #expect(TorrentStatus.download.systemImageName == "arrow.down.circle.fill")
        #expect(TorrentStatus.seed.systemImageName == "arrow.up.circle.fill")
    }

    @Test func testTorrentStatusDecodingFallback() throws {
        // Known status
        let json = "4".data(using: .utf8)!
        let status = try JSONDecoder().decode(TorrentStatus.self, from: json)
        #expect(status == .download)

        // Unknown future status code should safely fallback to stopped
        let unknownJson = "99".data(using: .utf8)!
        let fallbackStatus = try JSONDecoder().decode(TorrentStatus.self, from: unknownJson)
        #expect(fallbackStatus == .stopped)
    }

    // MARK: - TorrentFile Tests

    @Test func testTorrentFileProgressAndFormatting() throws {
        let file = TorrentFile(
            id: 0,
            name: "ubuntu-24.04-desktop-amd64.iso",
            bytesCompleted: 1_000_000_000,
            length: 2_000_000_000,
            wanted: true,
            priority: 1
        )

        #expect(file.progress == 0.5)
        #expect(file.percentDoneString == "50.0%")
        #expect(file.fileExtension == "iso")
        #expect(!file.formattedLength.isEmpty)
        #expect(!file.formattedBytesCompleted.isEmpty)
    }

    // MARK: - Torrent Tests

    @Test func testTorrentDecodingFromRPCPayload() throws {
        let json = """
        {
            "id": 42,
            "name": "Ubuntu 24.04 LTS",
            "status": 4,
            "rateDownload": 1048576,
            "rateUpload": 524288,
            "percentDone": 0.654,
            "totalSize": 4294967296,
            "eta": 3665,
            "errorString": "",
            "peersConnected": 25,
            "peersSendingToUs": 10,
            "peersGettingFromUs": 5,
            "uploadedEver": 1073741824,
            "downloadedEver": 2807693312,
            "uploadRatio": 0.38,
            "files": [
                {
                    "bytesCompleted": 2807693312,
                    "length": 4294967296,
                    "name": "ubuntu.iso"
                }
            ]
        }
        """.data(using: .utf8)!

        let torrent = try JSONDecoder().decode(Torrent.self, from: json)

        #expect(torrent.id == 42)
        #expect(torrent.name == "Ubuntu 24.04 LTS")
        #expect(torrent.status == .download)
        #expect(torrent.percentDone == 0.654)
        #expect(torrent.percentDoneString == "65.4%")
        #expect(!torrent.hasError)
        #expect(!torrent.isCompleted)
        #expect(torrent.files.count == 1)
        #expect(torrent.files.first?.id == 0)
        #expect(torrent.formattedETA == "1h 1m")
        #expect(!torrent.formattedDownloadSpeed.isEmpty)
        #expect(!torrent.formattedUploadSpeed.isEmpty)
    }

    @Test func testTorrentETAFormatting() {
        #expect(Torrent.formatETA(-1) == "—")
        #expect(Torrent.formatETA(-2) == "—")
        #expect(Torrent.formatETA(0) == "0s")
        #expect(Torrent.formatETA(45) == "45s")
        #expect(Torrent.formatETA(125) == "2m 5s")
        #expect(Torrent.formatETA(3720) == "1h 2m")
        #expect(Torrent.formatETA(90000) == "1d 1h")
    }

    @Test func testTorrentSpeedAndBytesZeroNumericFormatting() {
        let zeroBytes = Torrent.formatBytes(0)
        let zeroSpeed = Torrent.formatSpeed(0)

        #expect(zeroBytes.contains("0"))
        #expect(!zeroBytes.localizedCaseInsensitiveContains("zero"))
        #expect(!zeroBytes.localizedCaseInsensitiveContains("нуль"))

        #expect(zeroSpeed.contains("0"))
        #expect(!zeroSpeed.localizedCaseInsensitiveContains("zero"))
        #expect(!zeroSpeed.localizedCaseInsensitiveContains("нуль"))
    }

    // MARK: - SessionStats Tests

    @Test func testSessionStatsDecoding() throws {
        let json = """
        {
            "downloadSpeed": 2048000,
            "uploadSpeed": 512000,
            "torrentCount": 12,
            "activeTorrentCount": 4,
            "pausedTorrentCount": 8
        }
        """.data(using: .utf8)!

        let stats = try JSONDecoder().decode(SessionStats.self, from: json)

        #expect(stats.downloadSpeed == 2048000)
        #expect(stats.uploadSpeed == 512000)
        #expect(stats.torrentCount == 12)
        #expect(stats.activeTorrentCount == 4)
        #expect(stats.pausedTorrentCount == 8)
        #expect(!stats.formattedDownloadSpeed.isEmpty)
        #expect(!stats.formattedUploadSpeed.isEmpty)
        #expect(stats.formattedSpeedSummary.contains("↓"))
        #expect(stats.formattedSpeedSummary.contains("↑"))
    }
}
