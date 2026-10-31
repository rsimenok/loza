//
//  TorrentDetailView.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

/// Detailed view showing all metrics, files, peer statistics, and controls for a single torrent.
struct TorrentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppEnvironment.self) private var environment: AppEnvironment?

    @State private var viewModel: TorrentDetailViewModel
    @State private var showDeleteConfirmation: Bool = false
    @State private var hasCopiedHash: Bool = false
    private var onDeleted: (() -> Void)?

    init(torrent: Torrent, client: TransmissionClientProtocol? = nil, onDeleted: (() -> Void)? = nil) {
        self._viewModel = State(wrappedValue: TorrentDetailViewModel(torrent: torrent, client: client))
        self.onDeleted = onDeleted
    }

    init(viewModel: TorrentDetailViewModel, onDeleted: (() -> Void)? = nil) {
        self._viewModel = State(wrappedValue: viewModel)
        self.onDeleted = onDeleted
    }

    var body: some View {
        List {
            // Error banner if any
            if let error = viewModel.errorMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Section «Статус»
            statusSection

            // MARK: - Section «Швидкість та трафік»
            speedAndTrafficSection

            // MARK: - Section «Піри»
            peersSection

            // MARK: - Section «Файли»
            filesSection

            // MARK: - Section «Інформація»
            informationSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.torrent.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Play / Pause Button
                Button {
                    HapticManager.shared.torrentStateToggled()
                    Task {
                        await viewModel.toggleState()
                    }
                } label: {
                    Image(systemName: viewModel.torrent.status.isRunning ? "pause.fill" : "play.fill")
                }
                .tint(viewModel.torrent.status.isRunning ? .orange : .green)
                .accessibilityLabel(viewModel.torrent.status.isRunning ? String(localized: "Pause") : String(localized: "Start"))

                // Delete Button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .accessibilityLabel("Delete Torrent")
                .confirmationDialog(
                    "Delete Torrent?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Torrent Only", role: .destructive) {
                        HapticManager.shared.torrentDeleted()
                        Task {
                            do {
                                try await viewModel.delete(deleteLocalData: false)
                                onDeleted?()
                                dismiss()
                            } catch {
                                // Error handled by viewModel.errorMessage
                            }
                        }
                    }
                    Button("Delete Torrent and Data", role: .destructive) {
                        HapticManager.shared.torrentDeleted()
                        Task {
                            do {
                                try await viewModel.delete(deleteLocalData: true)
                                onDeleted?()
                                dismiss()
                            } catch {
                                // Error handled by viewModel.errorMessage
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete \"\(viewModel.torrent.name)\"?")
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            if let environment {
                viewModel.environment = environment
            }
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhaseChange(to: newPhase)
        }
    }

    // MARK: - Section Views

    private var statusSection: some View {
        Section("Status") {
            // Status badge and percentage
            HStack {
                Label(viewModel.torrent.status.localizedName, systemImage: viewModel.torrent.status.systemImageName)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(viewModel.torrent.status.badgeColor.opacity(0.15))
                    .foregroundStyle(viewModel.torrent.status.badgeColor)
                    .clipShape(Capsule())

                Spacer()

                Text(viewModel.torrent.percentDoneString)
                    .font(.title3.bold().monospacedDigit())
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: min(1.0, max(0.0, viewModel.torrent.percentDone)))
                    .progressViewStyle(.linear)
                    .tint(viewModel.torrent.status.badgeColor)
            }
            .padding(.vertical, 2)

            // ETA
            LabeledContent {
                Text(viewModel.torrent.formattedETA)
                    .foregroundStyle(.primary)
            } label: {
                Label("Remaining Time (ETA)", systemImage: "clock")
            }

            // Ratio
            LabeledContent {
                Text(viewModel.torrent.formattedUploadRatio)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            } label: {
                Label("Ratio", systemImage: "arrow.triangle.swap")
            }

            // Error notice if present
            if viewModel.torrent.hasError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracker Message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.torrent.errorString)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var speedAndTrafficSection: some View {
        Section("Speed and Traffic") {
            LabeledContent {
                Text(viewModel.torrent.formattedDownloadSpeed)
                    .monospacedDigit()
                    .foregroundStyle(.blue)
            } label: {
                Label("Download", systemImage: "arrow.down")
            }

            LabeledContent {
                Text(viewModel.torrent.formattedUploadSpeed)
                    .monospacedDigit()
                    .foregroundStyle(.green)
            } label: {
                Label("Upload", systemImage: "arrow.up")
            }

            LabeledContent {
                Text(viewModel.torrent.formattedTotalSize)
            } label: {
                Label("Total Size", systemImage: "internaldrive")
            }

            LabeledContent {
                Text(viewModel.torrent.formattedDownloadedEver)
            } label: {
                Label("Downloaded", systemImage: "arrow.down.circle")
            }

            LabeledContent {
                Text(viewModel.torrent.formattedUploadedEver)
            } label: {
                Label("Uploaded", systemImage: "arrow.up.circle")
            }
        }
    }

    private var peersSection: some View {
        Section("Peers") {
            LabeledContent {
                Text("\(viewModel.torrent.peersConnected)")
                    .monospacedDigit()
            } label: {
                Label("Connected Peers", systemImage: "person.2")
            }

            LabeledContent {
                Text("\(viewModel.torrent.peersSendingToUs)")
                    .monospacedDigit()
            } label: {
                Label("Downloading From", systemImage: "arrow.down.right")
            }

            LabeledContent {
                Text("\(viewModel.torrent.peersGettingFromUs)")
                    .monospacedDigit()
            } label: {
                Label("Seeding To", systemImage: "arrow.up.right")
            }
        }
    }

    private var filesSection: some View {
        Section("Files (\(viewModel.torrent.files.count))") {
            if viewModel.torrent.files.isEmpty {
                Text("File list is empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.torrent.files) { file in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: fileIconName(for: file.name))
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text(file.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)

                            Spacer(minLength: 4)

                            Text(file.percentDoneString)
                                .font(.caption.monospacedDigit().bold())
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: file.progress)
                            .progressViewStyle(.linear)
                            .tint(.accentColor)

                        HStack {
                            Text("\(file.formattedBytesCompleted) of \(file.formattedLength)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Spacer()
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var informationSection: some View {
        Section("Information") {
            // Hash with copy button
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Torrent Hash")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if hasCopiedHash {
                        Text("Copied!")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }

                HStack {
                    Text(viewModel.torrent.hashString.isEmpty ? "—" : viewModel.torrent.hashString)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    if !viewModel.torrent.hashString.isEmpty {
                        Button {
                            UIPasteboard.general.string = viewModel.torrent.hashString
                            hasCopiedHash = true
                            HapticManager.shared.impact(.light)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                hasCopiedHash = false
                            }
                        } label: {
                            Image(systemName: hasCopiedHash ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundStyle(hasCopiedHash ? .green : .accentColor)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Copy Hash")
                    }
                }
            }
            .padding(.vertical, 2)

            LabeledContent {
                Text(viewModel.torrent.formattedAddedDate)
            } label: {
                Label("Date Added", systemImage: "calendar")
            }

            LabeledContent {
                Text("\(viewModel.torrent.id)")
                    .monospacedDigit()
            } label: {
                Label("ID", systemImage: "number")
            }
        }
    }

    private func fileIconName(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v":
            return "film"
        case "mp3", "flac", "wav", "aac", "ogg", "m4a", "alac":
            return "music.note"
        case "iso", "img", "dmg", "cue", "bin":
            return "opticaldisc"
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz":
            return "archivebox"
        case "pdf", "epub", "mobi", "djvu":
            return "book"
        case "jpg", "jpeg", "png", "gif", "webp", "tiff", "svg":
            return "photo"
        case "txt", "nfo", "md", "log":
            return "doc.text"
        case "exe", "apk", "app", "deb", "rpm":
            return "shippingbox"
        default:
            return "doc"
        }
    }
}

#Preview {
    NavigationStack {
        TorrentDetailView(torrent: MockTransmissionClient.defaultSampleTorrents()[0])
            .environment(AppEnvironment())
    }
}
