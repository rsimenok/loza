//
//  FilterPopoverView.swift
//  Loza
//
//  Created by Roman Simenok on 02.11.2026.
//

import SwiftUI

/// Popover presenting multi-select filter criteria across Status, Tags, and Trackers.
struct FilterPopoverView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TorrentListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            resetButton

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statusSection

                    if !viewModel.availableTags.isEmpty {
                        Divider()
                        tagsSection
                    }

                    if !viewModel.availableTrackers.isEmpty {
                        Divider()
                        trackersSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 240, maxWidth: 300, maxHeight: 380)
    }

    // MARK: - Subviews

    private var resetButton: some View {
        Button {
            HapticManager.shared.filterSelected()
            viewModel.resetFilters()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.subheadline)
                    .frame(width: 18, alignment: .center)

                Text("Reset Filters")
                    .font(.subheadline)

                Spacer()
            }
            .foregroundStyle(viewModel.hasActiveFilters ? .red : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .disabled(!viewModel.hasActiveFilters)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Status")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(TorrentStatusCategory.allCases) { category in
                filterRow(
                    title: category.title,
                    count: viewModel.count(forStatus: category),
                    isSelected: viewModel.selectedStatuses.contains(category)
                ) {
                    viewModel.toggleStatus(category)
                }
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tags")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(viewModel.availableTags, id: \.self) { tag in
                filterRow(
                    title: tag,
                    count: viewModel.count(forTag: tag),
                    isSelected: viewModel.selectedTags.contains(tag)
                ) {
                    viewModel.toggleTag(tag)
                }
            }
        }
    }

    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trackers")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(viewModel.availableTrackers, id: \.self) { tracker in
                filterRow(
                    title: tracker,
                    count: viewModel.count(forTracker: tracker),
                    isSelected: viewModel.selectedTrackers.contains(tracker)
                ) {
                    viewModel.toggleTracker(tracker)
                }
            }
        }
    }

    @ViewBuilder
    private func filterRow(
        title: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.filterSelected()
            action()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 18, alignment: .center)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    let vm = TorrentListViewModel()
    FilterPopoverView(viewModel: vm)
}
