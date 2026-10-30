//
//  HapticManager.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import UIKit

/// Centralized manager for handling haptic feedback across key user actions.
@MainActor
public final class HapticManager: Sendable {
    public static let shared = HapticManager()

    private init() {}

    // MARK: - Key Actions Feedback

    /// Triggered when toggling pause/start of a torrent.
    public func torrentStateToggled() {
        impact(.medium)
    }

    /// Triggered when a torrent is deleted.
    public func torrentDeleted() {
        impact(.heavy)
    }

    /// Triggered when a torrent is successfully added.
    public func torrentAdded() {
        notification(.success)
    }

    /// Triggered when switching list filters.
    public func filterSelected() {
        selection()
    }

    /// Triggered when testing server connection succeeds.
    public func connectionTestSucceeded() {
        notification(.success)
    }

    /// Triggered when testing server connection fails.
    public func connectionTestFailed() {
        notification(.error)
    }

    // MARK: - Core Generators

    /// Performs impact feedback with specified style.
    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Performs notification feedback (success, warning, error).
    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    /// Performs selection feedback.
    public func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
