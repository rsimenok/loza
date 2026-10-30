//
//  PurchaseManager.swift
//  Loza
//
//  Created by Roman Simenok on 30.10.2026.
//

import Foundation
import Observation
import StoreKit

/// Identifiers for in-app purchases and subscriptions.
enum PurchaseProductID {
    static let tipTiny = "com.smnk.loza.tip.tiny"
    static let tipSmall = "com.smnk.loza.tip.small"
    static let tipMedium = "com.smnk.loza.tip.medium"
    static let tipLarge = "com.smnk.loza.tip.large"
    static let supporterMonthly = "com.smnk.loza.supporter.monthly"

    static let tipIDs: [String] = [tipTiny, tipSmall, tipMedium, tipLarge]
    static let allIDs: [String] = [tipTiny, tipSmall, tipMedium, tipLarge, supporterMonthly]
}

/// Centralized manager for in-app tips and voluntary subscriptions using StoreKit 2.
@Observable
@MainActor
final class PurchaseManager: Sendable {
    private static let hasEverTippedKey = "loza.hasEverTipped"

    var availableProducts: [Product] = []
    var isSubscribed: Bool = false
    var hasEverTipped: Bool = false
    var purchaseInProgress: Bool = false
    var errorMessage: String?
    var showCelebration: Bool = false

    var isSupporter: Bool {
        isSubscribed || hasEverTipped
    }

    var tipProducts: [Product] {
        availableProducts
            .filter { PurchaseProductID.tipIDs.contains($0.id) }
            .sorted { $0.price < $1.price }
    }

    var subscriptionProduct: Product? {
        availableProducts.first { $0.id == PurchaseProductID.supporterMonthly }
    }

    private var updatesTask: Task<Void, Never>?
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hasEverTipped = userDefaults.bool(forKey: Self.hasEverTippedKey)
        startTransactionListener()
    }

    isolated deinit {
        updatesTask?.cancel()
    }

    // MARK: - Transaction Listener

    func startTransactionListener() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if case .verified(let transaction) = result {
                    await self.handle(verifiedTransaction: transaction)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - StoreKit Operations

    /// Loads available products from StoreKit.
    func loadProducts() async {
        do {
            let products = try await Product.products(for: PurchaseProductID.allIDs)
            self.availableProducts = products
            await updateCustomerStatus()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// Checks active entitlements for ongoing subscriptions.
    func updateCustomerStatus() async {
        var activeSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == PurchaseProductID.supporterMonthly,
               transaction.revocationDate == nil {
                activeSubscription = true
            }
        }

        self.isSubscribed = activeSubscription
    }

    /// Purchases the given product.
    func purchase(_ product: Product) async throws -> Bool {
        purchaseInProgress = true
        errorMessage = nil
        defer { purchaseInProgress = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await handle(verifiedTransaction: transaction)
                    await transaction.finish()
                    showCelebration = true
                    HapticManager.shared.purchaseSuccess()
                    return true
                case .unverified(_, let error):
                    errorMessage = error.localizedDescription
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Restores previous purchases by syncing with the App Store.
    func restorePurchases() async {
        purchaseInProgress = true
        errorMessage = nil
        defer { purchaseInProgress = false }

        do {
            try await AppStore.sync()
            await updateCustomerStatus()
            if isSupporter {
                HapticManager.shared.purchaseSuccess()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Internal Handlers

    private func handle(verifiedTransaction transaction: Transaction) {
        if PurchaseProductID.tipIDs.contains(transaction.productID) {
            hasEverTipped = true
            userDefaults.set(true, forKey: Self.hasEverTippedKey)
        } else if transaction.productID == PurchaseProductID.supporterMonthly {
            isSubscribed = (transaction.revocationDate == nil)
        }
    }

    #if DEBUG
    /// Helper method for unit testing state transitions.
    func setMockState(hasEverTipped: Bool? = nil, isSubscribed: Bool? = nil) {
        if let hasEverTipped {
            self.hasEverTipped = hasEverTipped
            userDefaults.set(hasEverTipped, forKey: Self.hasEverTippedKey)
        }
        if let isSubscribed {
            self.isSubscribed = isSubscribed
        }
    }
    #endif
}
