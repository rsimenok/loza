//
//  SpeedIndicatorView.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

/// Compact inline indicator displaying total download and upload speeds with SF Symbols.
public struct SpeedIndicatorView: View {
    public let downloadSpeed: Int64
    public let uploadSpeed: Int64

    public init(downloadSpeed: Int64, uploadSpeed: Int64) {
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
    }

    public init(sessionStats: SessionStats?) {
        self.downloadSpeed = sessionStats?.downloadSpeed ?? 0
        self.uploadSpeed = sessionStats?.uploadSpeed ?? 0
    }

    public var body: some View {
        HStack(spacing: 5) {
            // Download Speed
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.blue)
                Text(Torrent.formatSpeed(downloadSpeed))
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }

            Text("•")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Upload Speed
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                Text(Torrent.formatSpeed(uploadSpeed))
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .animation(.snappy(duration: 0.25), value: downloadSpeed)
        .animation(.snappy(duration: 0.25), value: uploadSpeed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Speed: download \(Torrent.formatSpeed(downloadSpeed)), upload \(Torrent.formatSpeed(uploadSpeed))"))
    }
}

#Preview {
    VStack(spacing: 12) {
        SpeedIndicatorView(downloadSpeed: 4_520_000, uploadSpeed: 1_250_000)
        SpeedIndicatorView(downloadSpeed: 0, uploadSpeed: 0)
    }
    .padding()
}
