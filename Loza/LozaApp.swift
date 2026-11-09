//
//  LozaApp.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

@main
struct LozaApp: App {
    @State private var environment: AppEnvironment

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting-mock") {
            let suiteName = "com.smnk.loza.uitesting"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            let repo = ServerRepository(
                userDefaults: defaults,
                serversKey: "uitest_servers",
                activeServerIdKey: "uitest_active_server"
            )
            let demoServer = ServerConfig(name: "Home NAS", host: "192.168.1.100")
            try? repo.addServer(demoServer, password: nil)
            let secondaryServer = ServerConfig(name: "Seedbox VPS", host: "10.0.0.5")
            try? repo.addServer(secondaryServer, password: nil)

            let mockClient = MockTransmissionClient(
                initialTorrents: MockTransmissionClient.appStoreDemoTorrents(),
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
