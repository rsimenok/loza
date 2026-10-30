//
//  TorrentRowView.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

/// Card representing a single torrent download/upload with real-time metrics and quick control.
struct TorrentRowView: View {
    let torrent: Torrent
    let isSelected: Bool
    let onToggleState: () -> Void

    init(
        torrent: Torrent,
        isSelected: Bool = false,
        onToggleState: @escaping () -> Void
    ) {
        self.torrent = torrent
        self.isSelected = isSelected
        self.onToggleState = onToggleState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Status badge & tactile Play/Pause button
            HStack(alignment: .center) {
                statusBadge

                Spacer()

                Button {
                    HapticManager.shared.torrentStateToggled()
                    onToggleState()
                } label: {
                    Image(systemName: torrent.status.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(torrent.status.isRunning ? Color(uiColor: .secondaryLabel) : Color.accentColor)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(torrent.status.isRunning ? String(localized: "Pause") : String(localized: "Start"))
            }

            // Title
            Text(torrent.name)
                .font(.body.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(Color(uiColor: .label))

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

            // Progress Bar (Sleek 4pt rounded capsule)
            customProgressBar

            // Primary Metrics: Percent, total size, ETA / Ratio
            HStack {
                Text("\(torrent.percentDoneString) • \(torrent.formattedTotalSize)")
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))

                Spacer()

                if torrent.status.isDownloading && torrent.eta >= 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("ETA: \(torrent.formattedETA)")
                    }
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                } else if torrent.status.isSeeding {
                    Text("Ratio: \(torrent.formattedUploadRatio)")
                        .font(.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
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
                    .foregroundStyle(Color.accentColor)
                }

                if torrent.rateUpload > 0 || torrent.status.isSeeding {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.caption2.bold())
                        Text(torrent.formattedUploadSpeed)
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(torrent.peersConnected) (↓\(torrent.peersSendingToUs) • ↑\(torrent.peersGettingFromUs))")
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }

    // MARK: - Subviews & Styling

    @ViewBuilder
    private var customProgressBar: some View {
        GeometryReader { proxy in
            let progress = min(1.0, max(0.0, torrent.percentDone))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 4)

                if progress > 0 {
                    Capsule()
                        .fill(progressTint)
                        .frame(width: max(4, proxy.size.width * CGFloat(progress)), height: 4)
                }
            }
        }
        .frame(height: 4)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusTitle)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
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
            return .accentColor
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
            return Color.seedingProgress
        case .stopped:
            return Color(.tertiaryLabel)
        case .check, .checkWait:
            return .orange
        case .download, .downloadWait:
            return Color.accentColor
        }
    }
}

#Preview {
    let samples = MockTransmissionClient.defaultSampleTorrents()
    List {
        ForEach(samples) { sample in
            TorrentRowView(torrent: sample) { }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
    }
    .listStyle(.plain)
}
