//
//  TorrentListView.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

/// Main screen showing the list of torrents, filter bar, aggregate speeds, and server switcher.
@MainActor
struct TorrentListView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppEnvironment.self) private var environment: AppEnvironment?

    @Bindable var viewModel: TorrentListViewModel
    @Binding var selectedTorrentId: Int?
    @State private var isPresentingServerList: Bool = false
    @State private var isPresentingAbout: Bool = false
    @State private var isPresentingTipJar: Bool = false
    @State private var isPresentingAddTorrent: Bool = false
    @State private var isShowingFilters: Bool = false

    init(
        viewModel: TorrentListViewModel,
        selectedTorrentId: Binding<Int?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        self._selectedTorrentId = selectedTorrentId
    }

    init(selectedTorrentId: Binding<Int?> = .constant(nil)) {
        self.viewModel = TorrentListViewModel()
        self._selectedTorrentId = selectedTorrentId
    }

    var body: some View {
        let activeServerName = environment?.activeServer?.name ?? ""

        mainContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ServerSelectionMenuView(
                        servers: environment?.serverRepository.servers ?? [],
                        activeServerId: environment?.activeServer?.id,
                        onSelectServer: { server in
                            environment?.switchServer(to: server)
                        },
                        onManageServers: {
                            isPresentingServerList = true
                        },
                        onSupportLoza: {
                            isPresentingTipJar = true
                        },
                        onAbout: {
                            isPresentingAbout = true
                        }
                    )
                    .equatable()
                }

                ToolbarItem(placement: .principal) {
                    TorrentListPrincipalHeaderView(
                        serverName: activeServerName,
                        hasActiveServer: hasActiveServer,
                        viewModel: viewModel
                    )
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        TorrentListFilterButton(
                            viewModel: viewModel,
                            isShowingFilters: $isShowingFilters
                        )

                        Button {
                            isPresentingAddTorrent = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Torrent")
                    }
                }
            }
            .sheet(isPresented: $isPresentingServerList) {
                ServerListView()
            }
            .sheet(isPresented: $isPresentingAbout) {
                NavigationStack {
                    AboutView()
                }
            }
            .sheet(isPresented: $isPresentingTipJar) {
                NavigationStack {
                    TipJarView()
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
                AddTorrentView(
                    initialMagnetOrUrl: environment?.pendingMagnetURL,
                    availableServerTags: viewModel.availableTags
                ) {
                    isPresentingAddTorrent = false
                    environment?.showAddTorrentSheet = false
                    environment?.pendingMagnetURL = nil
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationDestination(for: Int.self) { torrentId in
                if let torrent = viewModel.torrents.first(where: { $0.id == torrentId }) {
                    TorrentDetailView(
                        torrent: torrent,
                        client: viewModel.client,
                        availableServerTags: viewModel.availableTags,
                        onTagsChanged: { id, newLabels in
                            viewModel.updateTorrentLabels(id: id, labels: newLabels)
                        }
                    )
                }
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
            .onChange(of: environment?.clientUpdateToken) { _, _ in
                selectedTorrentId = nil
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
            TorrentListContentView(
                viewModel: viewModel,
                selectedTorrentId: $selectedTorrentId,
                isPresentingAddTorrent: $isPresentingAddTorrent
            )
        }
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
}

// MARK: - Isolated Toolbar & Content Subviews

@MainActor
private struct TorrentListPrincipalHeaderView: View {
    let serverName: String
    let hasActiveServer: Bool
    let viewModel: TorrentListViewModel

    var body: some View {
        if hasActiveServer {
            VStack(spacing: 1) {
                if !serverName.isEmpty {
                    Text(serverName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                SpeedIndicatorView(
                    downloadSpeed: viewModel.sessionStats?.downloadSpeed ?? 0,
                    uploadSpeed: viewModel.sessionStats?.uploadSpeed ?? 0
                )
                .accessibilityIdentifier("speedIndicator")
            }
        } else if !serverName.isEmpty {
            Text(serverName)
                .font(.headline)
                .lineLimit(1)
        }
    }
}

@MainActor
private struct TorrentListFilterButton: View {
    @Bindable var viewModel: TorrentListViewModel
    @Binding var isShowingFilters: Bool

    var body: some View {
        Button {
            isShowingFilters.toggle()
        } label: {
            Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                .foregroundStyle(viewModel.hasActiveFilters ? Color.accentColor : Color.primary)
        }
        .accessibilityLabel("Filters")
        .popover(isPresented: $isShowingFilters) {
            FilterPopoverView(viewModel: viewModel)
                .presentationCompactAdaptation(.popover)
        }
    }
}

@MainActor
private struct TorrentListContentView: View {
    @Bindable var viewModel: TorrentListViewModel
    @Binding var selectedTorrentId: Int?
    @Binding var isPresentingAddTorrent: Bool

    var body: some View {
        List {
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
                    torrentRowItem(for: torrent)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .transaction { transaction in
            transaction.animation = nil
        }
        .confirmationDialog(
            "Delete Torrent?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let torrent = viewModel.torrentToDelete {
                Button("Delete Torrent Only", role: .destructive) {
                    HapticManager.shared.torrentDeleted()
                    if selectedTorrentId == torrent.id {
                        selectedTorrentId = nil
                    }
                    Task {
                        await viewModel.deleteTorrent(id: torrent.id, deleteLocalData: false)
                    }
                }
                Button("Delete Torrent and Data", role: .destructive) {
                    HapticManager.shared.torrentDeleted()
                    if selectedTorrentId == torrent.id {
                        selectedTorrentId = nil
                    }
                    Task {
                        await viewModel.deleteTorrent(id: torrent.id, deleteLocalData: true)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.torrentToDelete = nil
                }
            }
        } message: {
            if let torrent = viewModel.torrentToDelete {
                Text("Are you sure you want to delete \"\(torrent.name)\"?")
            }
        }
        .searchable(
            text: $viewModel.searchQuery,
            prompt: "Search Torrents..."
        )
    }

    private var isPadOrMac: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac
    }

    @ViewBuilder
    private func torrentRowItem(for torrent: Torrent) -> some View {
        if isPadOrMac {
            TorrentRowView(
                torrent: torrent,
                isSelected: selectedTorrentId == torrent.id
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                selectedTorrentId = torrent.id
            }
        } else {
            ZStack {
                NavigationLink(value: torrent.id) {
                    EmptyView()
                }
                .opacity(0)

                TorrentRowView(
                    torrent: torrent,
                    isSelected: false
                )
            }
        }
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

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Try Again")
                }
            }
            .font(.caption.bold())
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var emptyFilterView: some View {
        if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: viewModel.searchQuery)
        } else if viewModel.hasActiveFilters {
            ContentUnavailableView {
                Label("No Torrents Found", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("No torrents match the selected filters.")
            } actions: {
                Button("Reset Filters") {
                    HapticManager.shared.filterSelected()
                    viewModel.resetFilters()
                }
                .buttonStyle(.bordered)
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
