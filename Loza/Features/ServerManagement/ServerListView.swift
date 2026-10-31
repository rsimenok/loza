//
//  ServerListView.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

public struct ServerListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment: AppEnvironment?

    private let customRepository: ServerRepositoryProtocol?

    @State private var isPresentingAddSheet: Bool = false
    @State private var serverToEdit: ServerConfig?
    @State private var serverToDelete: ServerConfig?
    @State private var isShowingDeleteConfirmation: Bool = false

    public init(repository: ServerRepositoryProtocol? = nil) {
        self.customRepository = repository
    }

    private var activeRepository: ServerRepositoryProtocol {
        if let customRepository {
            return customRepository
        }
        if let environment {
            return environment.serverRepository
        }
        return ServerRepository()
    }

    private var servers: [ServerConfig] {
        activeRepository.servers
    }

    private var activeServerId: UUID? {
        environment?.activeServer?.id ?? activeRepository.activeServerId
    }

    public var body: some View {
        Group {
            if servers.isEmpty {
                emptyStateView
            } else {
                serverList
            }
        }
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Server")
            }
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            ServerEditView(repository: activeRepository) { newServer in
                if let environment {
                    environment.switchServer(to: newServer)
                } else {
                    activeRepository.setActiveServer(id: newServer.id)
                }
            }
        }
        .sheet(item: $serverToEdit) { server in
            ServerEditView(server: server, repository: activeRepository) { updatedServer in
                if activeServerId == updatedServer.id {
                    environment?.switchServer(to: updatedServer)
                }
            }
        }
        .confirmationDialog(
            "Delete Server?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: serverToDelete
        ) { server in
            Button("Delete \"\(server.name)\"", role: .destructive) {
                deleteServer(server)
            }
            Button("Cancel", role: .cancel) { }
        } message: { server in
            Text("Are you sure you want to delete server configuration \"\(server.name)\"?")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Servers", systemImage: "server.rack")
        } description: {
            Text("Add a Transmission server to remotely manage your downloads.")
        } actions: {
            Button {
                isPresentingAddSheet = true
            } label: {
                Text("Add First Server")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    @ViewBuilder
    private var serverList: some View {
        List {
            ForEach(servers) { server in
                serverRow(for: server)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectServer(server)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            serverToDelete = server
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)

                        Button {
                            serverToEdit = server
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            selectServer(server)
                        } label: {
                            Label("Make Active", systemImage: "checkmark.circle")
                        }

                        Button {
                            serverToEdit = server
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            serverToDelete = server
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func serverRow(for server: ServerConfig) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(server.displayAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if server.id == activeServerId {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func selectServer(_ server: ServerConfig) {
        HapticManager.shared.selection()
        if let environment {
            environment.switchServer(to: server)
        } else {
            activeRepository.setActiveServer(id: server.id)
        }
    }

    private func deleteServer(_ server: ServerConfig) {
        HapticManager.shared.torrentDeleted()
        do {
            try activeRepository.deleteServer(id: server.id)
            environment?.syncActiveServer()
        } catch {
            // Log or handle delete failure
        }
    }
}

#Preview("With Servers") {
    NavigationStack {
        ServerListView(
            repository: ServerRepository()
        )
    }
}

#Preview("Empty State") {
    NavigationStack {
        ServerListView()
    }
}
