//
//  Torrent.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation

nonisolated public struct Torrent: Identifiable, Codable, Sendable, Equatable, Hashable {
    public var id: Int
    public var name: String
    public var status: TorrentStatus
    public var rateDownload: Int64
    public var rateUpload: Int64
    public var percentDone: Double
    public var totalSize: Int64
    public var eta: Int64
    public var errorString: String
    public var peersConnected: Int
    public var peersSendingToUs: Int
    public var peersGettingFromUs: Int
    public var uploadedEver: Int64
    public var downloadedEver: Int64
    public var uploadRatio: Double
    public var files: [TorrentFile]
    public var hashString: String
    public var addedDate: Date?

    public init(
        id: Int,
        name: String,
        status: TorrentStatus = .stopped,
        rateDownload: Int64 = 0,
        rateUpload: Int64 = 0,
        percentDone: Double = 0.0,
        totalSize: Int64 = 0,
        eta: Int64 = -1,
        errorString: String = "",
        peersConnected: Int = 0,
        peersSendingToUs: Int = 0,
        peersGettingFromUs: Int = 0,
        uploadedEver: Int64 = 0,
        downloadedEver: Int64 = 0,
        uploadRatio: Double = 0.0,
        files: [TorrentFile] = [],
        hashString: String = "",
        addedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.rateDownload = rateDownload
        self.rateUpload = rateUpload
        self.percentDone = percentDone
        self.totalSize = totalSize
        self.eta = eta
        self.errorString = errorString
        self.peersConnected = peersConnected
        self.peersSendingToUs = peersSendingToUs
        self.peersGettingFromUs = peersGettingFromUs
        self.uploadedEver = uploadedEver
        self.downloadedEver = downloadedEver
        self.uploadRatio = uploadRatio
        self.files = files
        self.hashString = hashString
        self.addedDate = addedDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case rateDownload
        case rateUpload
        case percentDone
        case totalSize
        case eta
        case errorString
        case peersConnected
        case peersSendingToUs
        case peersGettingFromUs
        case uploadedEver
        case downloadedEver
        case uploadRatio
        case files
        case hashString
        case addedDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.status = try container.decodeIfPresent(TorrentStatus.self, forKey: .status) ?? .stopped
        self.rateDownload = try container.decodeIfPresent(Int64.self, forKey: .rateDownload) ?? 0
        self.rateUpload = try container.decodeIfPresent(Int64.self, forKey: .rateUpload) ?? 0
        self.percentDone = try container.decodeIfPresent(Double.self, forKey: .percentDone) ?? 0.0
        self.totalSize = try container.decodeIfPresent(Int64.self, forKey: .totalSize) ?? 0
        self.eta = try container.decodeIfPresent(Int64.self, forKey: .eta) ?? -1
        self.errorString = try container.decodeIfPresent(String.self, forKey: .errorString) ?? ""
        self.peersConnected = try container.decodeIfPresent(Int.self, forKey: .peersConnected) ?? 0
        self.peersSendingToUs = try container.decodeIfPresent(Int.self, forKey: .peersSendingToUs) ?? 0
        self.peersGettingFromUs = try container.decodeIfPresent(Int.self, forKey: .peersGettingFromUs) ?? 0
        self.uploadedEver = try container.decodeIfPresent(Int64.self, forKey: .uploadedEver) ?? 0
        self.downloadedEver = try container.decodeIfPresent(Int64.self, forKey: .downloadedEver) ?? 0
        self.uploadRatio = try container.decodeIfPresent(Double.self, forKey: .uploadRatio) ?? 0.0
        self.hashString = try container.decodeIfPresent(String.self, forKey: .hashString) ?? ""
        if let rawAdded = try container.decodeIfPresent(TimeInterval.self, forKey: .addedDate) {
            self.addedDate = Date(timeIntervalSince1970: rawAdded)
        } else {
            self.addedDate = nil
        }

        if var rawFiles = try container.decodeIfPresent([TorrentFile].self, forKey: .files) {
            for index in rawFiles.indices {
                if rawFiles[index].id == 0 {
                    rawFiles[index].id = index
                }
            }
            self.files = rawFiles
        } else {
            self.files = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(status, forKey: .status)
        try container.encode(rateDownload, forKey: .rateDownload)
        try container.encode(rateUpload, forKey: .rateUpload)
        try container.encode(percentDone, forKey: .percentDone)
        try container.encode(totalSize, forKey: .totalSize)
        try container.encode(eta, forKey: .eta)
        try container.encode(errorString, forKey: .errorString)
        try container.encode(peersConnected, forKey: .peersConnected)
        try container.encode(peersSendingToUs, forKey: .peersSendingToUs)
        try container.encode(peersGettingFromUs, forKey: .peersGettingFromUs)
        try container.encode(uploadedEver, forKey: .uploadedEver)
        try container.encode(downloadedEver, forKey: .downloadedEver)
        try container.encode(uploadRatio, forKey: .uploadRatio)
        try container.encode(files, forKey: .files)
        try container.encode(hashString, forKey: .hashString)
        if let addedDate = addedDate {
            try container.encode(addedDate.timeIntervalSince1970, forKey: .addedDate)
        }
    }

    // MARK: - Computed Properties & Formatters

    /// Whether there is an active error message
    public var hasError: Bool {
        !errorString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether the download has completed (100%)
    public var isCompleted: Bool {
        percentDone >= 1.0
    }

    /// Formatted progress percent, e.g. "85.2%"
    public var percentDoneString: String {
        String(format: "%.1f%%", min(100.0, max(0.0, percentDone * 100.0)))
    }

    /// Formatted download speed, e.g. "1.5 MB/s" or "0 KB/s"
    public var formattedDownloadSpeed: String {
        Self.formatSpeed(rateDownload)
    }

    /// Formatted upload speed, e.g. "250 KB/s" or "0 KB/s"
    public var formattedUploadSpeed: String {
        Self.formatSpeed(rateUpload)
    }

    /// Formatted total size, e.g. "2.4 GB"
    public var formattedTotalSize: String {
        Self.formatBytes(totalSize)
    }

    /// Formatted downloaded ever, e.g. "1.8 GB"
    public var formattedDownloadedEver: String {
        Self.formatBytes(downloadedEver)
    }

    /// Formatted uploaded ever, e.g. "500 MB"
    public var formattedUploadedEver: String {
        Self.formatBytes(uploadedEver)
    }

    /// Formatted upload/download ratio, e.g. "1.25"
    public var formattedUploadRatio: String {
        String(format: "%.2f", uploadRatio)
    }

    /// Human-readable estimated time remaining, e.g. "2h 15m", "45s", or "—"
    public var formattedETA: String {
        Self.formatETA(eta)
    }

    /// Formatted added date, e.g. "Oct 29, 2026, 5:30 PM" or "—"
    public var formattedAddedDate: String {
        guard let addedDate = addedDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: addedDate)
    }

    // MARK: - Static Formatting Utilities

    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    public static func formatSpeed(_ bytesPerSecond: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: bytesPerSecond))/s"
    }

    public static func formatETA(_ etaSeconds: Int64) -> String {
        guard etaSeconds >= 0 else { return "—" }
        if etaSeconds == 0 { return "0s" }

        let days = etaSeconds / 86400
        let hours = (etaSeconds % 86400) / 3600
        let minutes = (etaSeconds % 3600) / 60
        let seconds = etaSeconds % 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
