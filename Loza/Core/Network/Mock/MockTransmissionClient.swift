//
//  MockTransmissionClient.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import os

/// In-memory mock client providing realistic Transmission data and behavior for tests and previews.
public final class MockTransmissionClient: TransmissionClientProtocol, @unchecked Sendable {
    private let stateLock: OSAllocatedUnfairLock<[Torrent]>
    public var simulatedDelayNanoseconds: UInt64
    public var shouldFailWithError: TransmissionError?

    public init(
        initialTorrents: [Torrent]? = nil,
        simulatedDelayNanoseconds: UInt64 = 300_000_000,
        shouldFailWithError: TransmissionError? = nil
    ) {
        let torrents = initialTorrents ?? Self.defaultSampleTorrents()
        self.stateLock = OSAllocatedUnfairLock(initialState: torrents)
        self.simulatedDelayNanoseconds = simulatedDelayNanoseconds
        self.shouldFailWithError = shouldFailWithError
    }

    public static func defaultSampleTorrents() -> [Torrent] {
        [
            // 1. Ubuntu 24.04 LTS Desktop (downloading, ~75%)
            Torrent(
                id: 1,
                name: "ubuntu-24.04-desktop-amd64.iso",
                status: .download,
                rateDownload: 4_520_000,
                rateUpload: 120_000,
                percentDone: 0.748,
                totalSize: 6_123_683_840,
                eta: 340,
                errorString: "",
                peersConnected: 42,
                peersSendingToUs: 28,
                peersGettingFromUs: 5,
                uploadedEver: 524_288_000,
                downloadedEver: 4_580_515_512,
                uploadRatio: 0.11,
                files: [
                    TorrentFile(
                        id: 0,
                        name: "ubuntu-24.04-desktop-amd64.iso",
                        bytesCompleted: 4_580_515_512,
                        length: 6_123_683_840,
                        wanted: true,
                        priority: 0
                    )
                ],
                hashString: "2b826507024190c7ef2364c1f6b5b5be3d0fa8ef",
                addedDate: Date(timeIntervalSince1970: 1730190000)
            ),
            // 2. Fedora 40 Workstation (seeding, 100%)
            Torrent(
                id: 2,
                name: "Fedora-Workstation-Live-x86_64-40-1.14.iso",
                status: .seed,
                rateDownload: 0,
                rateUpload: 1_250_000,
                percentDone: 1.0,
                totalSize: 2_147_483_648,
                eta: -1,
                errorString: "",
                peersConnected: 18,
                peersSendingToUs: 0,
                peersGettingFromUs: 12,
                uploadedEver: 4_294_967_296,
                downloadedEver: 2_147_483_648,
                uploadRatio: 2.0,
                files: [
                    TorrentFile(
                        id: 0,
                        name: "Fedora-Workstation-Live-x86_64-40-1.14.iso",
                        bytesCompleted: 2_147_483_648,
                        length: 2_147_483_648,
                        wanted: true,
                        priority: 0
                    )
                ],
                hashString: "9c372b14e6d421a1bc36ef114b3f885e3e3b97b0",
                addedDate: Date(timeIntervalSince1970: 1730100000)
            ),
            // 3. Arch Linux (paused / stopped, ~42%)
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
            ),
            // 4. LibreOffice (error state)
            Torrent(
                id: 4,
                name: "LibreOffice_24.8.2_MacOS_aarch64.dmg",
                status: .stopped,
                rateDownload: 0,
                rateUpload: 0,
                percentDone: 0.15,
                totalSize: 310_000_000,
                eta: -1,
                errorString: "Tracker returned error: connection refused",
                peersConnected: 0,
                peersSendingToUs: 0,
                peersGettingFromUs: 0,
                uploadedEver: 0,
                downloadedEver: 46_500_000,
                uploadRatio: 0.0,
                files: [
                    TorrentFile(
                        id: 0,
                        name: "LibreOffice_24.8.2_MacOS_aarch64.dmg",
                        bytesCompleted: 46_500_000,
                        length: 310_000_000,
                        wanted: true,
                        priority: 0
                    )
                ],
                hashString: "10b65d1d64d1f0c2e3519b519ef16f39eb7e7b8c",
                addedDate: Date(timeIntervalSince1970: 1729800000)
            )
        ]
    }

    private func simulateDelay() async throws {
        if let error = shouldFailWithError {
            throw error
        }
        if simulatedDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: simulatedDelayNanoseconds)
        }
    }

    public func resetToDefaults() {
        stateLock.withLock {
            $0 = Self.defaultSampleTorrents()
        }
    }

    public func setTorrents(_ torrents: [Torrent]) {
        stateLock.withLock {
            $0 = torrents
        }
    }

    // MARK: - TransmissionClientProtocol

    public func testConnection(config: ServerConfig) async throws -> SessionStats {
        try await testConnection(config: config, password: nil)
    }

    public func testConnection(config: ServerConfig, password: String?) async throws -> SessionStats {
        try await simulateDelay()
        if config.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TransmissionError.invalidURL
        }
        return try await fetchSessionStats()
    }

    public func fetchTorrents() async throws -> [Torrent] {
        try await simulateDelay()
        return stateLock.withLock { $0 }
    }

    public func fetchSessionStats() async throws -> SessionStats {
        try await simulateDelay()
        return stateLock.withLock { torrents in
            let totalDownload = torrents.reduce(Int64(0)) { $0 + $1.rateDownload }
            let totalUpload = torrents.reduce(Int64(0)) { $0 + $1.rateUpload }
            let activeCount = torrents.filter { $0.status == .download || $0.status == .seed }.count
            let pausedCount = torrents.filter { $0.status == .stopped }.count

            return SessionStats(
                downloadSpeed: totalDownload,
                uploadSpeed: totalUpload,
                torrentCount: torrents.count,
                activeTorrentCount: activeCount,
                pausedTorrentCount: pausedCount
            )
        }
    }

    public func startTorrents(ids: [Int]) async throws {
        try await simulateDelay()
        stateLock.withLock { torrents in
            for index in torrents.indices {
                if ids.isEmpty || ids.contains(torrents[index].id) {
                    if torrents[index].isCompleted {
                        torrents[index].status = .seed
                        torrents[index].rateUpload = 1_000_000
                        torrents[index].rateDownload = 0
                    } else {
                        torrents[index].status = .download
                        torrents[index].rateDownload = 2_500_000
                        torrents[index].rateUpload = 50_000
                    }
                    torrents[index].errorString = ""
                }
            }
        }
    }

    public func stopTorrents(ids: [Int]) async throws {
        try await simulateDelay()
        stateLock.withLock { torrents in
            for index in torrents.indices {
                if ids.isEmpty || ids.contains(torrents[index].id) {
                    torrents[index].status = .stopped
                    torrents[index].rateDownload = 0
                    torrents[index].rateUpload = 0
                }
            }
        }
    }

    public func removeTorrents(ids: [Int], deleteLocalData: Bool) async throws {
        try await simulateDelay()
        stateLock.withLock { torrents in
            torrents.removeAll { ids.contains($0.id) }
        }
    }

    public func addTorrent(
        magnetOrUrl: String?,
        base64Metainfo: String?,
        downloadDir: String?
    ) async throws {
        try await addTorrent(magnetOrUrl: magnetOrUrl, base64Metainfo: base64Metainfo, downloadDir: downloadDir, paused: nil)
    }

    public func addTorrent(
        magnetOrUrl: String?,
        base64Metainfo: String?,
        downloadDir: String?,
        paused: Bool?
    ) async throws {
        try await simulateDelay()
        stateLock.withLock { torrents in
            let nextId = (torrents.map(\.id).max() ?? 0) + 1

            var torrentName = "Download_\(nextId)"
            var hashString = "simulated_hash_\(nextId)"
            if let link = magnetOrUrl {
                if let dnRange = link.range(of: "dn=") {
                    let substring = link[dnRange.upperBound...]
                    let encodedName = substring.components(separatedBy: "&").first ?? ""
                    let decodedName = encodedName.removingPercentEncoding ?? encodedName
                    if !decodedName.isEmpty {
                        torrentName = decodedName
                    }
                } else if let url = URL(string: link), !url.lastPathComponent.isEmpty {
                    torrentName = url.lastPathComponent
                }

                if let xtRange = link.range(of: "urn:btih:") {
                    let substring = link[xtRange.upperBound...]
                    let rawHash = substring.components(separatedBy: "&").first ?? ""
                    if !rawHash.isEmpty {
                        hashString = rawHash.lowercased()
                    }
                }
            } else if base64Metainfo != nil {
                torrentName = "Imported_Torrent_\(nextId).torrent"
                hashString = "file_hash_\(nextId)"
            }

            let initialStatus: TorrentStatus = (paused == true) ? .stopped : .download
            let newTorrent = Torrent(
                id: nextId,
                name: torrentName,
                status: initialStatus,
                rateDownload: (initialStatus == .download) ? 1_850_000 : 0,
                rateUpload: (initialStatus == .download) ? 45_000 : 0,
                percentDone: 0.02,
                totalSize: 1_200_000_000,
                eta: (initialStatus == .download) ? 650 : -1,
                errorString: "",
                peersConnected: (initialStatus == .download) ? 12 : 0,
                peersSendingToUs: (initialStatus == .download) ? 8 : 0,
                peersGettingFromUs: (initialStatus == .download) ? 1 : 0,
                uploadedEver: 0,
                downloadedEver: 24_000_000,
                uploadRatio: 0.0,
                files: [
                    TorrentFile(
                        id: 0,
                        name: torrentName,
                        bytesCompleted: 24_000_000,
                        length: 1_200_000_000,
                        wanted: true,
                        priority: 0
                    )
                ],
                hashString: hashString,
                addedDate: Date()
            )

            torrents.append(newTorrent)
        }
    }
}
