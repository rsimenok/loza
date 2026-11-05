//
//  ContentView.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var listViewModel = TorrentListViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedTorrentId: Int?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            TorrentListView(
                viewModel: listViewModel,
                selectedTorrentId: $selectedTorrentId
            )
            .navigationSplitViewColumnWidth(min: 340, ideal: 400, max: 500)
        } detail: {
            TorrentSplitDetailColumnView(
                viewModel: listViewModel,
                selectedTorrentId: $selectedTorrentId
            )
        }
        .navigationSplitViewStyle(.balanced)
    }
}

@MainActor
private struct TorrentSplitDetailColumnView: View {
    let viewModel: TorrentListViewModel
    @Binding var selectedTorrentId: Int?

    var body: some View {
        if let selectedTorrentId,
           let torrent = viewModel.torrents.first(where: { $0.id == selectedTorrentId }) {
            TorrentDetailView(
                torrent: torrent,
                client: viewModel.client,
                availableServerTags: viewModel.availableTags,
                onDeleted: {
                    self.selectedTorrentId = nil
                },
                onTagsChanged: { id, newLabels in
                    viewModel.updateTorrentLabels(id: id, labels: newLabels)
                }
            )
            .id(selectedTorrentId)
        } else {
            ContentUnavailableView(
                String(localized: "No Torrent Selected"),
                systemImage: "arrow.down.circle",
                description: Text("Select a torrent from the sidebar to view details, files, and connected peers.")
            )
        }
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment())
}
