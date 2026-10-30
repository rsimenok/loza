//
//  TipJarView.swift
//  Loza
//
//  Created by Roman Simenok on 30.10.2026.
//

import StoreKit
import SwiftUI

/// Modal sheet presenting voluntary tip tiers and recurring supporter club subscription.
@MainActor
struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment: AppEnvironment?

    private var purchaseManager: PurchaseManager {
        environment?.purchaseManager ?? fallbackManager
    }

    @State private var fallbackManager = PurchaseManager()
    @State private var isShowingManageSubscriptions = false

    private let privacyPolicyURL = URL(string: "https://github.com/rsimenok/trans-remote-ios/blob/main/PRIVACY.md")!
    private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        ZStack {
            Form {
                headerSection
                subscriptionSection
                oneTimeTipsSection
                legalSection
            }
            .navigationTitle("Support Loza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await purchaseManager.loadProducts()
            }
            .manageSubscriptionsSheet(isPresented: $isShowingManageSubscriptions)

            if purchaseManager.purchaseInProgress {
                loadingOverlay
            }

            if purchaseManager.showCelebration {
                celebrationOverlay
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.15))
                        .frame(width: 72, height: 72)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Support Loza")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text("Loza is free, open source, and has no ads. Your voluntary support directly powers ongoing development, updates, and maintenance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

                if purchaseManager.isSupporter {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                        Text("You are an active Supporter!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private var subscriptionSection: some View {
        Section("Loza Supporter Club") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("🌟")
                            Text("Monthly Supporter")
                                .font(.headline)
                        }

                        Text("Continuous monthly support to help keep Loza maintained, updated, and ad-free.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let product = purchaseManager.subscriptionProduct {
                        Text("\(product.displayPrice)/mo")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }

                if purchaseManager.isSubscribed {
                    HStack {
                        Label("Active Subscription", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)

                        Spacer()

                        Button("Manage") {
                            isShowingManageSubscriptions = true
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                } else if let product = purchaseManager.subscriptionProduct {
                    Button {
                        purchaseProduct(product)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Join for \(product.displayPrice) / month")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var oneTimeTipsSection: some View {
        Section("One-Time Tips") {
            if purchaseManager.tipProducts.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(purchaseManager.tipProducts, id: \.id) { product in
                    tipRow(for: product)
                }
            }
        }
    }

    @ViewBuilder
    private func tipRow(for product: Product) -> some View {
        HStack(spacing: 12) {
            Text(icon(for: product.id))
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: product.id))
                    .font(.body.weight(.medium))
                Text(subtitle(for: product.id))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(product.displayPrice) {
                purchaseProduct(product)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 2)
    }

    private var legalSection: some View {
        Section {
            Button("Restore Purchases") {
                Task {
                    await purchaseManager.restorePurchases()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period. Payment is charged to your Apple ID account at confirmation of purchase. You can manage and cancel your subscriptions in your App Store Account Settings.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Link("Privacy Policy", destination: privacyPolicyURL)
                    Link("Terms of Use (EULA)", destination: termsOfUseURL)
                }
                .font(.caption2)
            }
            .padding(.vertical, 4)
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            ProgressView()
                .padding(20)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    purchaseManager.showCelebration = false
                }

            ConfettiView()

            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.pink)

                Text("Thank You!")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text("Your support means the world and keeps Loza free and independent.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Button("You're Welcome!") {
                    purchaseManager.showCelebration = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .padding(.top, 8)
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Actions & Helpers

    private func purchaseProduct(_ product: Product) {
        Task {
            _ = try? await purchaseManager.purchase(product)
        }
    }

    private func icon(for productID: String) -> String {
        switch productID {
        case PurchaseProductID.tipTiny: return "🍬"
        case PurchaseProductID.tipSmall: return "☕️"
        case PurchaseProductID.tipMedium: return "🍕"
        case PurchaseProductID.tipLarge: return "🚀"
        default: return "🎁"
        }
    }

    private func title(for productID: String) -> String {
        switch productID {
        case PurchaseProductID.tipTiny: return String(localized: "Tiny Tip")
        case PurchaseProductID.tipSmall: return String(localized: "Coffee")
        case PurchaseProductID.tipMedium: return String(localized: "Pizza")
        case PurchaseProductID.tipLarge: return String(localized: "Generous Tip")
        default: return String(localized: "Tip")
        }
    }

    private func subtitle(for productID: String) -> String {
        switch productID {
        case PurchaseProductID.tipTiny:
            return String(localized: "A sweet little token of appreciation.")
        case PurchaseProductID.tipSmall:
            return String(localized: "Buy a coffee for the developer.")
        case PurchaseProductID.tipMedium:
            return String(localized: "Treat the developer to a pizza slice.")
        case PurchaseProductID.tipLarge:
            return String(localized: "Fuel major improvements and server support.")
        default:
            return ""
        }
    }
}

#Preview {
    NavigationStack {
        TipJarView()
    }
}
