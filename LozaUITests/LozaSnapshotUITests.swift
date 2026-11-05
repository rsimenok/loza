//
//  LozaSnapshotUITests.swift
//  LozaUITests
//
//  Created by Roman Simenok on 05.11.2026.
//

import XCTest

final class LozaSnapshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        if !app.launchArguments.contains("--uitesting-mock") {
            app.launchArguments.append("--uitesting-mock")
        }
        app.launch()

        // 1. Torrent List
        let alpineRow = app.staticTexts["Alpine-standard-3.20.3-x86_64.iso"]
        XCTAssertTrue(alpineRow.waitForExistence(timeout: 10), "Main torrent list should load mock torrents")
        snapshot("01_TorrentList")

        // 2. Server Selection Dropdown Menu
        let serverMenuButton = app.buttons["serverMenuButton"]
        XCTAssertTrue(serverMenuButton.waitForExistence(timeout: 5), "Server selection menu button should exist")
        serverMenuButton.tap()

        let manageServersButton = app.buttons["manageServersButton"]
        XCTAssertTrue(manageServersButton.waitForExistence(timeout: 5), "Manage servers option should appear in menu")
        snapshot("02_ServerList")

        // Dismiss server selection menu
        let outsideMenuCoordinate = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8))
        outsideMenuCoordinate.tap()
        if manageServersButton.exists {
            serverMenuButton.tap()
        }
        XCTAssertTrue(manageServersButton.waitForNonExistence(timeout: 5), "Server menu should dismiss")

        // 3. Filter Popover
        let filterButton = app.buttons["filterButton"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5), "Filter button should exist")
        filterButton.tap()

        let filterPopover = app.descendants(matching: .any)["filterPopover"]
        XCTAssertTrue(filterPopover.waitForExistence(timeout: 5), "Filter popover should appear")
        snapshot("03_TorrentFilter")

        // Dismiss filter popover
        let popoverDismissRegion = app.otherElements["PopoverDismissRegion"]
        if popoverDismissRegion.waitForExistence(timeout: 2) {
            popoverDismissRegion.tap()
        } else {
            let outsideCoordinate = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.85))
            outsideCoordinate.tap()
            if filterPopover.exists {
                if filterButton.isHittable {
                    filterButton.tap()
                } else {
                    app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8)).tap()
                }
            }
        }
        XCTAssertTrue(filterPopover.waitForNonExistence(timeout: 5), "Filter popover should dismiss")

        // 4. Torrent Detail
        XCTAssertTrue(alpineRow.waitForExistence(timeout: 5), "Alpine torrent row should be available")
        alpineRow.tap()

        let detailView = app.descendants(matching: .any)["torrentDetailView"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Torrent detail view should appear")
        snapshot("04_TorrentDetail")
    }
}
