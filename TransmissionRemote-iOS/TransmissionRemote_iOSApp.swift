//
//  TransmissionRemote_iOSApp.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

@main
struct TransmissionRemote_iOSApp: App {
    @State private var environment: AppEnvironment

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting-mock") {
            let suiteName = "com.smnk.TransmissionRemote.uitesting"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            let repo = ServerRepository(
                userDefaults: defaults,
                serversKey: "uitest_servers",
                activeServerIdKey: "uitest_active_server"
            )
            let demoServer = ServerConfig(name: "Home NAS", host: "192.168.1.100")
            try? repo.addServer(demoServer, password: nil)

            var torrents = MockTransmissionClient.defaultSampleTorrents()
            let extraLegalDistros = [
                "Debian-12.7.0-amd64-netinst.iso",
                "LinuxMint-22-cinnamon-64bit.iso",
                "openSUSE-Tumbleweed-DVD-x86_64.iso",
                "FreeBSD-14.1-RELEASE-amd64-disc1.iso",
                "Alpine-standard-3.20.3-x86_64.iso",
                "Blender-4.2.2-macos-arm64.dmg"
            ]
            for (offset, distro) in extraLegalDistros.enumerated() {
                torrents.append(
                    Torrent(
                        id: 100 + offset,
                        name: distro,
                        status: .seed,
                        rateDownload: 0,
                        rateUpload: 0,
                        percentDone: 1.0,
                        totalSize: 2_500_000_000,
                        uploadRatio: 3.4
                    )
                )
            }

            let mockClient = MockTransmissionClient(
                initialTorrents: torrents,
                simulatedDelayNanoseconds: 20_000_000
            )
            self._environment = State(wrappedValue: AppEnvironment(
                serverRepository: repo,
                clientFactory: { _ in mockClient }
            ))
            return
        }
        #endif
        self._environment = State(wrappedValue: AppEnvironment())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
                .onOpenURL { url in
                    environment.handleOpenURL(url)
                }
        }
    }
}
