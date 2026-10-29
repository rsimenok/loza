//
//  TorrentListView.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

/// Main screen showing the list of torrents, filter bar, aggregate speeds, and server switcher.
public struct TorrentListView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppEnvironment.self) private var environment: AppEnvironment?

    @State private var viewModel: TorrentListViewModel
    @State private var isPresentingServerList: Bool = false
    @State private var isPresentingAddTorrent: Bool = false
    @State private var filterBarHeight: CGFloat = 46

    public init(viewModel: TorrentListViewModel? = nil) {
        self._viewModel = State(wrappedValue: viewModel ?? TorrentListViewModel())
    }

    public var body: some View {
        let activeServerName = environment?.activeServer?.name ?? ""
        let downloadSpeed = viewModel.sessionStats?.downloadSpeed ?? 0
        let uploadSpeed = viewModel.sessionStats?.uploadSpeed ?? 0

        mainContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    serverSelectionMenu
                }

                ToolbarItem(placement: .principal) {
                    principalHeaderView(
                        serverName: activeServerName,
                        downloadSpeed: downloadSpeed,
                        uploadSpeed: uploadSpeed
                    )
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddTorrent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Torrent")
                }
            }
            .sheet(isPresented: $isPresentingServerList) {
                NavigationStack {
                    ServerListView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    isPresentingServerList = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: Binding(
                get: { isPresentingAddTorrent || (environment?.showAddTorrentSheet ?? false) },
                set: { newValue in
                    isPresentingAddTorrent = newValue
                    if !newValue {
                        environment?.showAddTorrentSheet = false
                        environment?.pendingMagnetURL = nil
                    }
                }
            )) {
                AddTorrentView(initialMagnetOrUrl: environment?.pendingMagnetURL) {
                    isPresentingAddTorrent = false
                    environment?.showAddTorrentSheet = false
                    environment?.pendingMagnetURL = nil
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationDestination(for: Torrent.self) { torrent in
                TorrentDetailView(torrent: torrent, client: viewModel.client)
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
            .onChange(of: environment?.activeServer?.id) { _, _ in
                viewModel.resetForNewServer()
            }
    }

    // MARK: - Subviews

    private var hasConfiguredServers: Bool {
        if viewModel.client != nil {
            return true
        }
        return environment?.hasConfiguredServer ?? false
    }

    private var hasActiveServer: Bool {
        if viewModel.client != nil {
            return true
        }
        return environment?.activeServer != nil
    }

    @ViewBuilder
    private var mainContent: some View {
        if !hasConfiguredServers {
            noServersConfiguredView
        } else if !hasActiveServer {
            noActiveServerSelectedView
        } else {
            torrentList
        }
    }

    private var torrentList: some View {
        let baseList = List {
            if let error = viewModel.errorMessage {
                errorBanner(message: error)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if viewModel.torrents.isEmpty && viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading Torrents...")
                        .padding(.vertical, 80)
                    Spacer()
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else if viewModel.filteredTorrents.isEmpty {
                emptyFilterView
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.filteredTorrents) { torrent in
                    NavigationLink(value: torrent) {
                        TorrentRowView(torrent: torrent) {
                            Task {
                                await viewModel.toggleTorrentState(torrent: torrent)
                            }
                        }
                        .confirmationDialog(
                            "Delete Torrent?",
                            isPresented: deleteConfirmationBinding(for: torrent),
                            titleVisibility: .visible
                        ) {
                            Button("Delete Torrent Only", role: .destructive) {
                                HapticManager.shared.torrentDeleted()
                                Task {
                                    await viewModel.deleteTorrent(id: torrent.id, deleteLocalData: false)
                                }
                            }
                            Button("Delete Torrent and Data", role: .destructive) {
                                HapticManager.shared.torrentDeleted()
                                Task {
                                    await viewModel.deleteTorrent(id: torrent.id, deleteLocalData: true)
                                }
                            }
                            Button("Cancel", role: .cancel) {
                                viewModel.torrentToDelete = nil
                            }
                        } message: {
                            Text("Are you sure you want to delete \"\(torrent.name)\"?")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            HapticManager.shared.torrentStateToggled()
                            Task {
                                await viewModel.toggleTorrentState(torrent: torrent)
                            }
                        } label: {
                            Label(
                                torrent.status.isRunning ? "Pause" : "Start",
                                systemImage: torrent.status.isRunning ? "pause.fill" : "play.fill"
                            )
                        }
                        .tint(torrent.status.isRunning ? .orange : .green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            viewModel.confirmDelete(for: torrent)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
        .listStyle(.plain)

        return Group {
            if #available(iOS 26.0, *) {
                baseList
                    .contentMargins(.top, filterBarHeight + 6, for: .scrollIndicators)
                    .safeAreaBar(edge: .top, spacing: 0) {
                        filterBar
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { newHeight in
                                if newHeight > 0, abs(newHeight - filterBarHeight) > 0.5 {
                                    filterBarHeight = newHeight
                                }
                            }
                    }
            } else {
                baseList
                    .safeAreaInset(edge: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            filterBar
                            Divider()
                        }
                        .background(.bar)
                    }
            }
        }
        .searchable(
            text: $viewModel.searchQuery,
            prompt: "Search Torrents..."
        )
    }

    @ViewBuilder
    private func principalHeaderView(
        serverName: String,
        downloadSpeed: Int64,
        uploadSpeed: Int64
    ) -> some View {
        if hasActiveServer {
            VStack(spacing: 1) {
                if !serverName.isEmpty {
                    Text(serverName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                SpeedIndicatorView(
                    downloadSpeed: downloadSpeed,
                    uploadSpeed: uploadSpeed
                )
                .accessibilityIdentifier("speedIndicator")
            }
        } else if !serverName.isEmpty {
            Text(serverName)
                .font(.headline)
                .lineLimit(1)
        }
    }

    private var filterBar: some View {
        FilterBarView(selectedFilter: $viewModel.selectedFilter) { filter in
            viewModel.count(for: filter)
        }
    }

    private func deleteConfirmationBinding(for torrent: Torrent) -> Binding<Bool> {
        Binding(
            get: {
                viewModel.showDeleteConfirmation && viewModel.torrentToDelete?.id == torrent.id
            },
            set: { isPresented in
                if !isPresented {
                    viewModel.showDeleteConfirmation = false
                    if viewModel.torrentToDelete?.id == torrent.id {
                        viewModel.torrentToDelete = nil
                    }
                }
            }
        )
    }

    private var serverSelectionMenu: some View {
        Menu {
            if let servers = environment?.serverRepository.servers, !servers.isEmpty {
                Section("Servers") {
                    ForEach(servers) { server in
                        Button {
                            environment?.switchServer(to: server)
                        } label: {
                            HStack {
                                Text(server.name)
                                if server.id == environment?.activeServer?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            Button {
                isPresentingServerList = true
            } label: {
                Label("Server Management", systemImage: "server.rack")
            }
        } label: {
            Image(systemName: "server.rack")
                .foregroundStyle(.primary)
        }
        .accessibilityLabel("Servers")
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            Button("Try Again") {
                Task {
                    await viewModel.refresh()
                }
            }
            .font(.caption.bold())
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var noServersConfiguredView: some View {
        ContentUnavailableView {
            Label("No Servers", systemImage: "server.rack")
        } description: {
            Text("Configure a Transmission server to remotely manage downloads.")
        } actions: {
            Button("Configure Server") {
                isPresentingServerList = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var noActiveServerSelectedView: some View {
        ContentUnavailableView {
            Label("No Server Selected", systemImage: "network.slash")
        } description: {
            Text("Select a server from the list to view torrents.")
        } actions: {
            Button("Select Server") {
                isPresentingServerList = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var emptyFilterView: some View {
        if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: viewModel.searchQuery)
        } else if viewModel.selectedFilter != .all {
            ContentUnavailableView {
                Label("No Items", systemImage: viewModel.selectedFilter.systemImage)
            } description: {
                Text("There are currently no torrents in \"\(viewModel.selectedFilter.title)\" category.")
            }
        } else {
            ContentUnavailableView {
                Label("No Torrents", systemImage: "tray")
            } description: {
                Text("Download list on this server is empty.")
            } actions: {
                Button("Add Torrent") {
                    isPresentingAddTorrent = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    let mock = MockTransmissionClient()
    let vm = TorrentListViewModel(client: mock)
    NavigationStack {
        TorrentListView(viewModel: vm)
    }
}
