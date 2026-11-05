//
//  ServerSelectionMenuView.swift
//  Loza
//
//  Created by Roman Simenok on 04.11.2026.
//

import SwiftUI
import UIKit

@MainActor
private let emptyMenuIcon: UIImage = {
    let size = UIImage(systemName: "checkmark")?.size ?? CGSize(width: 18, height: 18)
    return UIGraphicsImageRenderer(size: size).image { _ in }
}()

/// Toolbar menu for switching the active Transmission server and accessing app settings.
/// Conforms to `Equatable` to prevent menu reconstruction and open-menu reload animations during background polling.
struct ServerSelectionMenuView: View, Equatable {
    let servers: [ServerConfig]
    let activeServerId: UUID?
    let onSelectServer: (ServerConfig) -> Void
    let onManageServers: () -> Void
    let onSupportLoza: () -> Void
    let onAbout: () -> Void

    nonisolated static func == (lhs: ServerSelectionMenuView, rhs: ServerSelectionMenuView) -> Bool {
        lhs.servers == rhs.servers && lhs.activeServerId == rhs.activeServerId
    }

    var body: some View {
        Menu {
            if !servers.isEmpty {
                Section("Servers") {
                    ForEach(servers) { server in
                        Button {
                            onSelectServer(server)
                        } label: {
                            if server.id == activeServerId {
                                Label(server.name, systemImage: "checkmark")
                            } else {
                                Label {
                                    Text(server.name)
                                } icon: {
                                    Image(uiImage: emptyMenuIcon)
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            Button {
                onManageServers()
            } label: {
                Label("Server Management", systemImage: "server.rack")
            }
            .accessibilityIdentifier("manageServersButton")

            Button {
                onSupportLoza()
            } label: {
                Label("Support Loza", systemImage: "heart.fill")
            }

            Button {
                onAbout()
            } label: {
                Label("About", systemImage: "info.circle")
            }
        } label: {
            Image(systemName: "server.rack")
                .foregroundStyle(.primary)
        }
        .accessibilityLabel("Servers")
        .accessibilityIdentifier("serverMenuButton")
    }
}
