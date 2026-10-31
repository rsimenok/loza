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
        } detail: {
            if let selectedTorrentId,
               let torrent = listViewModel.torrents.first(where: { $0.id == selectedTorrentId }) {
                TorrentDetailView(
                    torrent: torrent,
                    client: listViewModel.client,
                    onDeleted: {
                        self.selectedTorrentId = nil
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
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment())
}
