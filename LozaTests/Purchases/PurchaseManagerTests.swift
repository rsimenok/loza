//
//  PurchaseManagerTests.swift
//  LozaTests
//
//  Created by Roman Simenok on 30.10.2026.
//

import Testing
import Foundation
@testable import Loza

struct PurchaseManagerTests {

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "com.smnk.loza.test.purchases.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    @Test @MainActor func testInitialState() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = PurchaseManager(userDefaults: defaults)

        #expect(manager.isSubscribed == false)
        #expect(manager.hasEverTipped == false)
        #expect(manager.isSupporter == false)
        #expect(manager.purchaseInProgress == false)
        #expect(manager.showCelebration == false)
        #expect(manager.errorMessage == nil)
    }

    @Test @MainActor func testProductIDsIntegrity() {
        #expect(PurchaseProductID.allIDs.count == 5)
        #expect(PurchaseProductID.tipIDs.count == 4)
        #expect(PurchaseProductID.allIDs.contains(PurchaseProductID.supporterMonthly))
        #expect(PurchaseProductID.tipIDs.contains(PurchaseProductID.tipTiny))
        #expect(PurchaseProductID.tipIDs.contains(PurchaseProductID.tipSmall))
        #expect(PurchaseProductID.tipIDs.contains(PurchaseProductID.tipMedium))
        #expect(PurchaseProductID.tipIDs.contains(PurchaseProductID.tipLarge))
    }

    @Test @MainActor func testSupporterStatusFromTip() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = PurchaseManager(userDefaults: defaults)
        #expect(manager.isSupporter == false)

        manager.setMockState(hasEverTipped: true)
        #expect(manager.hasEverTipped == true)
        #expect(manager.isSupporter == true)

        // Verify persistence in defaults
        let restoredManager = PurchaseManager(userDefaults: defaults)
        #expect(restoredManager.hasEverTipped == true)
        #expect(restoredManager.isSupporter == true)
    }

    @Test @MainActor func testSupporterStatusFromSubscription() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = PurchaseManager(userDefaults: defaults)
        #expect(manager.isSupporter == false)

        manager.setMockState(isSubscribed: true)
        #expect(manager.isSubscribed == true)
        #expect(manager.isSupporter == true)

        manager.setMockState(isSubscribed: false)
        #expect(manager.isSubscribed == false)
        #expect(manager.isSupporter == false)
    }

    @Test @MainActor func testCombinedSupporterLogic() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = PurchaseManager(userDefaults: defaults)

        // Case 1: Neither
        manager.setMockState(hasEverTipped: false, isSubscribed: false)
        #expect(manager.isSupporter == false)

        // Case 2: Only tip
        manager.setMockState(hasEverTipped: true, isSubscribed: false)
        #expect(manager.isSupporter == true)

        // Case 3: Only subscription
        manager.setMockState(hasEverTipped: false, isSubscribed: true)
        #expect(manager.isSupporter == true)

        // Case 4: Both
        manager.setMockState(hasEverTipped: true, isSubscribed: true)
        #expect(manager.isSupporter == true)
    }
}
