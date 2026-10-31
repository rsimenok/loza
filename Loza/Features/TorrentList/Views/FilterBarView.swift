//
//  FilterBarView.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

/// Horizontal scrollable bar of filter chips with count badges.
public struct FilterBarView: View {
    @Binding public var selectedFilter: TorrentFilter
    public let countProvider: (TorrentFilter) -> Int

    public init(
        selectedFilter: Binding<TorrentFilter>,
        countProvider: @escaping (TorrentFilter) -> Int
    ) {
        self._selectedFilter = selectedFilter
        self.countProvider = countProvider
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TorrentFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    let count = countProvider(filter)

                    Button {
                        if selectedFilter != filter {
                            HapticManager.shared.filterSelected()
                            selectedFilter = filter
                        }
                    } label: {
                        chipLabel(for: filter, count: count, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "\(filter.title), \(count) torrents"))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func chipLabel(for filter: TorrentFilter, count: Int, isSelected: Bool) -> some View {
        let content = HStack(spacing: 6) {
            Image(systemName: filter.systemImage)
                .font(.subheadline)

            Text(filter.title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))

            Text("\(count)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    isSelected
                        ? Color.white.opacity(0.25)
                        : Color(.tertiarySystemFill)
                )
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(isSelected ? Color.white : Color.primary)

        if #available(iOS 26.0, *) {
            if isSelected {
                content
                    .background(Color.accentColor, in: Capsule())
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
            } else {
                content
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
        } else {
            content
                .background {
                    if isSelected {
                        Capsule().fill(Color.accentColor)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
        }
    }
}

#Preview {
    @Previewable @State var filter: TorrentFilter = .all
    FilterBarView(selectedFilter: $filter) { f in
        switch f {
        case .all: return 12
        case .downloading: return 3
        case .seeding: return 5
        case .paused: return 3
        case .error: return 1
        }
    }
}
