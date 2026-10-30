//
//  LocalizationAndHapticsTests.swift
//  LozaTests
//
//  Created by Roman Simenok on 29.10.2026.
//

import Testing
import Foundation
import UIKit
@testable import Loza

struct LocalizationAndHapticsTests {

    private let expectedLanguages: Set<String> = ["en", "uk", "de", "fr", "es", "pl"]

    // MARK: - String Catalog Integrity Tests

    @Test func testLocalizableCatalogIntegrity() throws {
        // Locate Localizable.xcstrings file in workspace
        let bundle = Bundle(for: KeychainService.self)
        let possibleUrls = [
            Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
            bundle.url(forResource: "Localizable", withExtension: "xcstrings"),
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Loza/Resources/Localization/Localizable.xcstrings")
        ].compactMap { $0 }

        guard let catalogUrl = possibleUrls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            Issue.record("Localizable.xcstrings file not found")
            return
        }

        let data = try Data(contentsOf: catalogUrl)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(jsonObject != nil)

        let version = jsonObject?["version"] as? String
        #expect(version == "1.0" || version == "1.1")

        let sourceLanguage = jsonObject?["sourceLanguage"] as? String
        #expect(sourceLanguage == "en")

        guard let strings = jsonObject?["strings"] as? [String: [String: Any]] else {
            Issue.record("No 'strings' dictionary found in Localizable.xcstrings")
            return
        }

        #expect(!strings.isEmpty)

        // Essential keys that must be present
        let requiredKeys = [
            "Torrents", "Details", "Servers", "Add Torrent", "Settings",
            "All", "Downloading", "Seeding", "Paused", "Errors",
            "Stopped", "Queued for Check", "Checking", "Queued for Download", "Queued for Seeding", "Queued", "Error",
            "Start", "Pause", "Delete", "Save", "Cancel", "Test Connection", "Paste from Clipboard", "Choose .torrent File",
            "Delete Torrent?", "Delete Torrent Only", "Delete Torrent and Data",
            "Server", "Security", "Authentication", "Diagnostics", "Trust Self-Signed Certificates",
            "No Servers", "No Server Selected", "No Torrents", "Search Torrents...",
            "No Torrent Selected", "Select a torrent from the sidebar to view details, files, and connected peers.",
            "Invalid server URL.", "Authentication failed (401 Unauthorized).", "Cannot reach server: %@",
            "%@/s",
            "About", "Free and open-source utility for remote management of your Transmission daemon.",
            "Project", "Source Code on GitHub", "Third-Party Software", "Version %@ (%@)",
            "Support Loza", "Tip Jar", "Supporter", "Restore Purchases", "Loza Supporter Club", "Monthly Supporter", "One-Time Tips", "Thank You!"
        ]

        for key in requiredKeys {
            let entry = strings[key]
            #expect(entry != nil, "Missing required key: \(key)")

            if let localizations = entry?["localizations"] as? [String: [String: Any]] {
                for lang in expectedLanguages {
                    let langEntry = localizations[lang]
                    #expect(langEntry != nil, "Missing translation for '\(lang)' in key: \(key)")
                    let stringUnit = langEntry?["stringUnit"] as? [String: Any]
                    let value = stringUnit?["value"] as? String
                    #expect(value != nil && !value!.isEmpty, "Empty translation for '\(lang)' in key: \(key)")
                }

                // Explicitly verify Russian is NOT present
                #expect(localizations["ru"] == nil, "Russian language must be strictly excluded! Found in key: \(key)")
            }
        }
    }

    @Test func testSpeedFormattingUkrainianLocalization() throws {
        let bundle = Bundle(for: KeychainService.self)
        let possibleUrls = [
            Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
            bundle.url(forResource: "Localizable", withExtension: "xcstrings"),
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Loza/Resources/Localization/Localizable.xcstrings")
        ].compactMap { $0 }

        guard let catalogUrl = possibleUrls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            Issue.record("Localizable.xcstrings file not found")
            return
        }

        let data = try Data(contentsOf: catalogUrl)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let strings = jsonObject?["strings"] as? [String: [String: Any]] else {
            Issue.record("No 'strings' dictionary found")
            return
        }

        guard let speedEntry = strings["%@/s"],
              let localizations = speedEntry["localizations"] as? [String: [String: Any]],
              let ukEntry = localizations["uk"],
              let stringUnit = ukEntry["stringUnit"] as? [String: Any],
              let ukValue = stringUnit["value"] as? String else {
            Issue.record("Missing '%@/s' Ukrainian localization")
            return
        }

        // In Ukrainian, second is abbreviated as 'с' (Cyrillic \u{0441}), NOT Latin 's' (\u{0073})
        #expect(ukValue == "%@/с")
        #expect(ukValue.contains("\u{0441}"))
        #expect(!ukValue.contains("s"))
    }

    @Test func testInfoPlistCatalogIntegrity() throws {
        let bundle = Bundle(for: KeychainService.self)
        let possibleUrls = [
            Bundle.main.url(forResource: "InfoPlist", withExtension: "xcstrings"),
            bundle.url(forResource: "InfoPlist", withExtension: "xcstrings"),
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Loza/Resources/Localization/InfoPlist.xcstrings")
        ].compactMap { $0 }

        guard let catalogUrl = possibleUrls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            Issue.record("InfoPlist.xcstrings file not found")
            return
        }

        let data = try Data(contentsOf: catalogUrl)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(jsonObject != nil)

        let version = jsonObject?["version"] as? String
        #expect(version == "1.0" || version == "1.1")

        let sourceLanguage = jsonObject?["sourceLanguage"] as? String
        #expect(sourceLanguage == "en")

        guard let strings = jsonObject?["strings"] as? [String: [String: Any]] else {
            Issue.record("No 'strings' dictionary in InfoPlist.xcstrings")
            return
        }

        let localNetworkEntry = strings["NSLocalNetworkUsageDescription"]
        #expect(localNetworkEntry != nil)

        if let localizations = localNetworkEntry?["localizations"] as? [String: [String: Any]] {
            for lang in expectedLanguages {
                let langEntry = localizations[lang]
                #expect(langEntry != nil, "Missing '\(lang)' in NSLocalNetworkUsageDescription")
                let stringUnit = langEntry?["stringUnit"] as? [String: Any]
                let value = stringUnit?["value"] as? String
                #expect(value != nil && !value!.isEmpty, "Empty '\(lang)' in NSLocalNetworkUsageDescription")
            }

            #expect(localizations["ru"] == nil, "Russian language must be strictly excluded from InfoPlist!")
        }
    }

    // MARK: - Models & Error Localization Tests

    @Test func testTorrentStatusLocalization() {
        for status in TorrentStatus.allCases {
            #expect(!status.displayTitle.isEmpty)
            #expect(!status.localizedName.isEmpty)
        }
    }

    @Test func testTorrentFilterLocalization() {
        for filter in TorrentFilter.allCases {
            #expect(!filter.title.isEmpty)
        }
    }

    @Test func testTransmissionErrorDescriptions() {
        let dummyError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network timeout"])
        let errors: [TransmissionError] = [
            .invalidURL,
            .unauthorized,
            .serverUnreachable(underlying: dummyError),
            .sslCertificateUntrusted,
            .rpcError(message: "Torrent duplicate"),
            .noActiveServer,
            .decodingFailed(underlying: dummyError)
        ]

        for error in errors {
            let desc = error.errorDescription
            let suggestion = error.recoverySuggestion

            #expect(desc != nil && !desc!.isEmpty)
            #expect(suggestion != nil && !suggestion!.isEmpty)
        }
    }

    // MARK: - HapticManager Tests

    @Test @MainActor func testHapticManagerExecution() {
        let haptics = HapticManager.shared

        // Verify key action feedback methods execute without throwing/crashing
        haptics.torrentStateToggled()
        haptics.torrentDeleted()
        haptics.torrentAdded()
        haptics.filterSelected()
        haptics.connectionTestSucceeded()
        haptics.connectionTestFailed()
        haptics.purchaseSuccess()

        // Verify core generator wrappers
        haptics.impact(.medium)
        haptics.impact(.light)
        haptics.impact(.heavy)
        haptics.notification(.success)
        haptics.notification(.warning)
        haptics.notification(.error)
        haptics.selection()
    }
}
