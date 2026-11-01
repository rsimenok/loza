//
//  LozaUITests.swift
//  LozaUITests
//
//  Created by Roman Simenok on 29.10.2026.
//

import XCTest

final class LozaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigationSearchRefreshAndDeleteUX() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-mock", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // 1. Wait for main list to load (sorted alphabetically: Alpine is at the top)
        let alpineRow = app.staticTexts["Alpine-standard-3.20.3-x86_64.iso"]
        let archRow = app.staticTexts["archlinux-2024.10.01-x86_64.iso"]
        XCTAssertTrue(alpineRow.waitForExistence(timeout: 5), "Torrent list should load mock torrents sorted by name")
        XCTAssertTrue(archRow.exists)
        XCTAssertLessThan(alpineRow.frame.minY, archRow.frame.minY, "Alpine should appear above Arch Linux alphabetically")

        // 2. Verify header speed indicator exists, is not truncated, and shows initial speed
        let speedIndicator = app.descendants(matching: .any)["speedIndicator"]
        XCTAssertTrue(speedIndicator.waitForExistence(timeout: 3), "Header speed indicator must exist")
        let initialSpeedLabel = speedIndicator.label
        XCTAssertTrue(initialSpeedLabel.contains("MB/s"), "Initial speed should display MB/s, got: \(initialSpeedLabel)")
        XCTAssertGreaterThan(speedIndicator.frame.width, 100, "Speed indicator must not be squished")

        // 3. Open TorrentDetailView & test Delete ConfirmationDialog anchored to Trash toolbar button
        alpineRow.tap()
        let deleteNavButton = app.buttons["Delete Torrent"]
        XCTAssertTrue(deleteNavButton.waitForExistence(timeout: 3), "Delete button in detail toolbar should exist")
        deleteNavButton.tap()

        let deleteOnlyButton = app.buttons["Delete Torrent Only"]
        let deleteWithDataButton = app.buttons["Delete Torrent and Data"]
        XCTAssertTrue(deleteOnlyButton.waitForExistence(timeout: 3), "Delete Torrent Only button must appear in dialog")
        XCTAssertTrue(deleteWithDataButton.exists, "Delete Torrent and Data button must appear in dialog")

        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists && cancelButton.isHittable {
            cancelButton.tap()
        } else {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.85)).tap()
        }
        XCTAssertTrue(deleteOnlyButton.waitForNonExistence(timeout: 3))

        // 4. Navigate back to TorrentListView and verify native Search remains accessible
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.exists)
        backButton.tap()
        XCTAssertTrue(alpineRow.waitForExistence(timeout: 3))

        let searchField = app.searchFields.firstMatch
        if !searchField.exists {
            alpineRow.swipeDown()
        }
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Native search field must remain available post-navigation")

        // 5. Test swipe-to-delete: row MUST NOT disappear before user confirms in popover!
        archRow.swipeLeft()
        let swipeDeleteButton = app.buttons["Delete"]
        XCTAssertTrue(swipeDeleteButton.waitForExistence(timeout: 2))
        swipeDeleteButton.tap()

        XCTAssertTrue(deleteOnlyButton.waitForExistence(timeout: 3), "Delete dialog must appear from list swipe")
        XCTAssertTrue(archRow.exists, "Row must remain in the list while confirmation popover is open")

        if cancelButton.exists && cancelButton.isHittable {
            cancelButton.tap()
        } else {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.15)).tap()
        }
        XCTAssertTrue(deleteOnlyButton.waitForNonExistence(timeout: 3))
        XCTAssertTrue(archRow.exists, "Row must still remain in the list after dismissing delete popover")
    }
}
