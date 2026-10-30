//
//  AddTorrentViewModelTests.swift
//  TransmissionRemote-iOSTests
//
//  Created by Roman Simenok on 29.10.2026.
//

import XCTest
import UIKit
@testable import TransmissionRemote_iOS

@MainActor
final class AddTorrentViewModelTests: XCTestCase {
    private var mockClient: MockTransmissionClient!

    override func setUp() {
        super.setUp()
        mockClient = MockTransmissionClient(simulatedDelayNanoseconds: 0)
    }

    override func tearDown() {
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Validation Tests

    func testValidation() async {
        let vm = AddTorrentViewModel()

        // Initially invalid (both empty)
        XCTAssertFalse(vm.isValid)

        // Only whitespace link is invalid
        vm.magnetOrUrl = "   \n\t  "
        XCTAssertFalse(vm.isValid)

        // Valid magnet/URL link
        vm.magnetOrUrl = "magnet:?xt=urn:btih:1234567890abcdef"
        XCTAssertTrue(vm.isValid)

        // Reset link, add file data
        vm.magnetOrUrl = ""
        XCTAssertFalse(vm.isValid)

        vm.selectedFileData = Data([0x01, 0x02, 0x03])
        vm.selectedFileName = "test.torrent"
        XCTAssertTrue(vm.isValid)

        // Both link and file present is valid
        vm.magnetOrUrl = "https://example.com/sample.torrent"
        XCTAssertTrue(vm.isValid)
    }

    // MARK: - Clipboard Paste Tests

    func testPasteFromClipboard() async {
        let vm = AddTorrentViewModel()
        let testMagnet = "magnet:?xt=urn:btih:1234567890abcdef&dn=Test+Ubuntu"

        UIPasteboard.general.string = "   \(testMagnet)   "
        vm.pasteFromClipboard()

        XCTAssertEqual(vm.magnetOrUrl, testMagnet)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - File Import Tests

    func testHandleFileSelected() async throws {
        let vm = AddTorrentViewModel()

        // Create a temporary .torrent file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("sample_test_torrent_\(UUID().uuidString).torrent")
        let sampleContent = "d8:announce37:http://torrent.ubuntu.com:6969/announcee".data(using: .utf8)!
        try sampleContent.write(to: fileURL)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        vm.handleFileSelected(url: fileURL)

        XCTAssertEqual(vm.selectedFileData, sampleContent)
        XCTAssertEqual(vm.selectedFileName, fileURL.lastPathComponent)
        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.isValid)
    }

    func testClearSelectedFile() async {
        let vm = AddTorrentViewModel(
            selectedFileData: Data([0xaa, 0xbb]),
            selectedFileName: "sample.torrent"
        )

        XCTAssertTrue(vm.isValid)
        vm.clearSelectedFile()

        XCTAssertNil(vm.selectedFileData)
        XCTAssertNil(vm.selectedFileName)
        XCTAssertFalse(vm.isValid)
    }

    // MARK: - Submit Tests

    func testSubmitWithMagnetLinkSuccess() async throws {
        let vm = AddTorrentViewModel(
            initialMagnetOrUrl: "magnet:?xt=urn:btih:abcdef1234567890&dn=Arch-Linux-Live.iso"
        )

        let success = await vm.submit(client: mockClient)

        XCTAssertTrue(success)
        XCTAssertTrue(vm.isSuccess)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isSubmitting)

        let torrents = try await mockClient.fetchTorrents()
        let added = try XCTUnwrap(torrents.first(where: { $0.name == "Arch-Linux-Live.iso" }))
        XCTAssertEqual(added.status, .download)
    }

    func testSubmitWithFileDataSuccess() async throws {
        let fileBytes = "d8:announce37:http://tracker.example.com/announcee".data(using: .utf8)!
        let vm = AddTorrentViewModel(
            selectedFileData: fileBytes,
            selectedFileName: "example.torrent"
        )

        let success = await vm.submit(client: mockClient)

        XCTAssertTrue(success)
        XCTAssertTrue(vm.isSuccess)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isSubmitting)

        let torrents = try await mockClient.fetchTorrents()
        XCTAssertEqual(torrents.count, 5) // 4 default + 1 added
    }

    func testSubmitWithStartImmediatelyFalse() async throws {
        let vm = AddTorrentViewModel(
            initialMagnetOrUrl: "magnet:?xt=urn:btih:998877665544&dn=PausedDownload.iso",
            startImmediately: false
        )

        let success = await vm.submit(client: mockClient)

        XCTAssertTrue(success)
        let torrents = try await mockClient.fetchTorrents()
        let added = try XCTUnwrap(torrents.first(where: { $0.name == "PausedDownload.iso" }))
        XCTAssertEqual(added.status, .stopped)
        XCTAssertEqual(added.rateDownload, 0)
    }

    func testSubmitWhenInvalidFailsImmediately() async {
        let vm = AddTorrentViewModel()
        XCTAssertFalse(vm.isValid)

        let success = await vm.submit(client: mockClient)

        XCTAssertFalse(success)
        XCTAssertFalse(vm.isSuccess)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isSubmitting)
    }

    func testSubmitClientFailure() async {
        mockClient.shouldFailWithError = .unauthorized
        let vm = AddTorrentViewModel(
            initialMagnetOrUrl: "magnet:?xt=urn:btih:abcdef"
        )

        let success = await vm.submit(client: mockClient)

        XCTAssertFalse(success)
        XCTAssertFalse(vm.isSuccess)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isSubmitting)
    }
}
