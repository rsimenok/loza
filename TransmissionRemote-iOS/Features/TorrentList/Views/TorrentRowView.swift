//
//  TorrentRowView.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

/// Cell representing a single torrent download/upload with real-time metrics and quick control.
public struct TorrentRowView: View {
    public let torrent: Torrent
    public let onToggleState: () -> Void

    public init(
        torrent: Torrent,
        onToggleState: @escaping () -> Void
    ) {
        self.torrent = torrent
        self.onToggleState = onToggleState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Title, status badge, and quick play/pause button
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(torrent.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    statusBadge
                }

                Spacer(minLength: 8)

                Button {
                    HapticManager.shared.torrentStateToggled()
                    onToggleState()
                } label: {
                    Image(systemName: torrent.status.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(torrent.status.isRunning ? Color.orange : Color.accentColor)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(torrent.status.isRunning ? String(localized: "Pause") : String(localized: "Start"))
            }

            // Error description (if any)
            if torrent.hasError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(torrent.errorString)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .lineLimit(1)
            }

            // Progress Bar
            ProgressView(value: min(1.0, max(0.0, torrent.percentDone)))
                .progressViewStyle(.linear)
                .tint(progressTint)

            // Primary Metrics: Percent, total size, ETA
            HStack {
                Text("\(torrent.percentDoneString) • \(torrent.formattedTotalSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if torrent.status.isDownloading && torrent.eta >= 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("ETA: \(torrent.formattedETA)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if torrent.status.isSeeding {
                    Text("Ratio: \(torrent.formattedUploadRatio)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Secondary Metrics: Speeds and Peers info
            HStack(spacing: 12) {
                if torrent.rateDownload > 0 || torrent.status.isDownloading {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.caption2.bold())
                        Text(torrent.formattedDownloadSpeed)
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(.blue)
                }

                if torrent.rateUpload > 0 || torrent.status.isSeeding {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.caption2.bold())
                        Text(torrent.formattedUploadSpeed)
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(.green)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(torrent.peersConnected) (↓\(torrent.peersSendingToUs) • ↑\(torrent.peersGettingFromUs))")
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subviews & Styling

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            Text(statusTitle)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusTitle: String {
        if torrent.hasError {
            return String(localized: "Error")
        }
        return torrent.status.displayTitle
    }

    private var statusColor: Color {
        if torrent.hasError {
            return .red
        }
        switch torrent.status {
        case .download:
            return .blue
        case .seed:
            return .green
        case .stopped:
            return .secondary
        case .check, .checkWait:
            return .orange
        case .downloadWait, .seedWait:
            return .purple
        }
    }

    private var progressTint: Color {
        if torrent.hasError {
            return .red
        }
        switch torrent.status {
        case .seed, .seedWait:
            return .green
        case .stopped:
            return .gray
        case .check, .checkWait:
            return .orange
        case .download, .downloadWait:
            return .blue
        }
    }
}

#Preview {
    let samples = MockTransmissionClient.defaultSampleTorrents()
    List {
        ForEach(samples) { sample in
            TorrentRowView(torrent: sample) { }
        }
    }
}
