//
//  ServerSelectionMenuViewTests.swift
//  LozaTests
//
//  Created by Roman Simenok on 05.11.2026.
//

import Testing
import Foundation
@testable import Loza

@Suite("ServerSelectionMenuView Tests")
struct ServerSelectionMenuViewTests {
    private let serverA = ServerConfig(name: "Home NAS", host: "192.168.1.10")
    private let serverB = ServerConfig(name: "Seedbox VPS", host: "seedbox.example.com")

    @Test("Equatable returns true for identical servers and activeServerId")
    func testEqualityWithIdenticalProperties() {
        let menu1 = ServerSelectionMenuView(
            servers: [serverA, serverB],
            activeServerId: serverA.id,
            onSelectServer: { _ in },
            onManageServers: { },
            onSupportLoza: { },
            onAbout: { }
        )

        let menu2 = ServerSelectionMenuView(
            servers: [serverA, serverB],
            activeServerId: serverA.id,
            onSelectServer: { _ in },
            onManageServers: { },
            onSupportLoza: { },
            onAbout: { }
        )

        #expect(menu1 == menu2)
    }

    @Test("Equatable returns false when activeServerId differs")
    func testInequalityWithDifferentActiveServer() {
        let menu1 = ServerSelectionMenuView(
            servers: [serverA, serverB],
            activeServerId: serverA.id,
            onSelectServer: { _ in },
            onManageServers: { },
            onSupportLoza: { },
            onAbout: { }
        )

        let menu2 = ServerSelectionMenuView(
            servers: [serverA, serverB],
            activeServerId: serverB.id,
            onSelectServer: { _ in },
            onManageServers: { },
            onSupportLoza: { },
            onAbout: { }
        )

        #expect(menu1 != menu2)
    }

    @Test("Equatable returns false when servers list differs")
    func testInequalityWithDifferentServers() {
        let menu1 = ServerSelectionMenuView(
            servers: [serverA],
            activeServerId: serverA.id,
            onSelectServer: { _ in },
            onManageServers: { },
            onSupportLoza: { },
            onAbout: { }
        )

        let menu2 = ServerSelectionMenuView(
            servers: [serverA, serverB],
            activeServerId: serverA.id,
            onSelectServer: { _ in },
            onManageServers: { },
            onSupportLoza: { },
            onAbout: { }
        )

        #expect(menu1 != menu2)
    }
}
