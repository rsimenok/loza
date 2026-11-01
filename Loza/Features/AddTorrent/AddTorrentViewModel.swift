//
//  AddTorrentViewModel.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import Observation
import UIKit

@Observable
@MainActor
public final class AddTorrentViewModel {
    // MARK: - Properties

    public var magnetOrUrl: String
    public var selectedFileData: Data?
    public var selectedFileName: String?
    public var startImmediately: Bool
    public var downloadDir: String
    public var recentPaths: [String]
    public var isSubmitting: Bool
    public var errorMessage: String?
    public var isSuccess: Bool

    private let historyStore: DownloadDirectoryHistoryStore

    // MARK: - Validation

    /// Returns true if either a non-empty magnet/URL is provided or a file is selected.
    public var isValid: Bool {
        let hasLink = !magnetOrUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasFile = selectedFileData != nil
        return hasLink || hasFile
    }

    // MARK: - Initialization

    public init(
        initialMagnetOrUrl: String? = nil,
        selectedFileData: Data? = nil,
        selectedFileName: String? = nil,
        startImmediately: Bool = true,
        downloadDir: String = "",
        historyStore: DownloadDirectoryHistoryStore = DownloadDirectoryHistoryStore()
    ) {
        self.magnetOrUrl = initialMagnetOrUrl ?? ""
        self.selectedFileData = selectedFileData
        self.selectedFileName = selectedFileName
        self.startImmediately = startImmediately
        self.downloadDir = downloadDir
        self.recentPaths = []
        self.historyStore = historyStore
        self.isSubmitting = false
        self.errorMessage = nil
        self.isSuccess = false
    }

    /// Loads recently used download directories for the specified server.
    public func loadRecentPaths(serverId: UUID?) {
        guard let serverId else {
            recentPaths = []
            return
        }
        recentPaths = historyStore.getRecentPaths(forServerId: serverId)
    }

    // MARK: - Clipboard & File Handling

    /// Pastes link from the system clipboard.
    public func pasteFromClipboard() {
        if let string = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !string.isEmpty {
            self.magnetOrUrl = string
            self.errorMessage = nil
        }
    }

    /// Reads a .torrent file from a security-scoped URL, saving its data and file name.
    public func handleFileSelected(url: URL) {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            self.selectedFileData = data
            self.selectedFileName = url.lastPathComponent
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Помилка читання файлу: \(error.localizedDescription)"
        }
    }

    /// Clears selected .torrent file.
    public func clearSelectedFile() {
        self.selectedFileData = nil
        self.selectedFileName = nil
    }

    // MARK: - Submission

    /// Submits the torrent to the specified Transmission client.
    public func submit(client: TransmissionClientProtocol, serverId: UUID? = nil) async -> Bool {
        guard isValid else {
            self.errorMessage = "Введіть посилання або виберіть файл торрента"
            return false
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let trimmedLink = magnetOrUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkParam = trimmedLink.isEmpty ? nil : trimmedLink
        let base64Param = selectedFileData?.base64EncodedString()
        let paused = !startImmediately

        let trimmedDir = downloadDir.trimmingCharacters(in: .whitespacesAndNewlines)
        let dirParam = trimmedDir.isEmpty ? nil : trimmedDir

        do {
            try await client.addTorrent(
                magnetOrUrl: linkParam,
                base64Metainfo: base64Param,
                downloadDir: dirParam,
                paused: paused
            )
            if let dirParam, let serverId {
                historyStore.recordPath(dirParam, forServerId: serverId)
            }
            self.isSuccess = true
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
