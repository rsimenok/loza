# AGENTS.md — Instructions and Architectural Guidelines for AI Agents

This file contains rules, conventions, stack details, and context for autonomous AI agents (Claude Code, Cursor, Copilot, Antigravity) working on the **Transmission Remote iOS** codebase.

---

## 1. Project Overview

* **Purpose:** Lightweight, private, and native iOS client for remote management of Transmission daemons (Home NAS, Synology, TrueNAS, Unraid, VPS).
* **Tech Stack:** Swift 6 (Strict Concurrency), SwiftUI, Alamofire 5.x (SPM), Security Framework (Keychain).
* **Target Platform:** iOS 17.0+ (`@Observable`, NavigationStack, String Catalogs).
* **License:** MIT Open Source.
* **Privacy:** Zero third-party analytics, telemetry tracking, or advertisements.

---

## 2. Build & Test Commands

Due to Xcode sandboxing and caching, always provide `-derivedDataPath /tmp/DerivedData`:

```bash
# Build project for iOS Simulator
xcodebuild -project TransmissionRemote-iOS.xcodeproj -scheme TransmissionRemote-iOS -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/DerivedData build

# Run Unit Tests
xcodebuild test -project TransmissionRemote-iOS.xcodeproj -scheme TransmissionRemote-iOS -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/DerivedData
```

---

## 3. Core Principles & Codebase Rules

### 3.1. Access Control — NO Unnecessary `public`
* All entities within the main application target must use Swift's standard default access level — **`internal`**, or **`private` / `fileprivate`**.
* **DO NOT use `public`** in application files! `public` is only required when code is extracted into a standalone SPM package or framework.
* Unit tests use `@testable import TransmissionRemote_iOS`, which grants full access to all `internal` entities.

### 3.2. Swift 6 Concurrency & State Management
* The project strictly enforces Swift 6 Strict Concurrency checking.
* UI components and ViewModels must be annotated with `@MainActor` and utilize the modern `@Observable` macro (never use deprecated `ObservableObject` / `@Published`).
* Network clients and services must conform to `Sendable`. Mutable state in clients/interceptors (such as `sessionId`) must be protected by thread-safe primitives (`OSAllocatedUnfairLock` or `os_unfair_lock`).

### 3.3. Localization (String Catalogs)
* All user-facing strings must be managed via String Catalogs:
  * `TransmissionRemote-iOS/Resources/Localization/Localizable.xcstrings`
  * `TransmissionRemote-iOS/Resources/Localization/InfoPlist.xcstrings`
* **Mandatory support for 6 languages:**
  1. `en` (English) — development base language
  2. `uk` (Ukrainian) — native project language
  3. `de` (German)
  4. `fr` (French)
  5. `es` (Spanish)
  6. `pl` (Polish)
* 🚫 **Russian language is strictly prohibited and excluded from the project.**
* In UI code, use standard `Text("Key")`, `String(localized: "Key")`, or `LocalizedStringKey`.

### 3.4. Energy Efficiency & Background State (Battery-Friendly)
* Server polling (2–3s) must be tied to the app lifecycle via `ScenePhase`.
* When the app transitions to `.background` or `.inactive`, polling **must be cancelled immediately**. Zero background activity and zero battery drain while suspended.

### 3.5. Data Security
* Server passwords **must never be stored** in `UserDefaults` or plaintext.
* Passwords must be stored exclusively in `KeychainService` via the Security Framework (`kSecClassGenericPassword`).

---

## 4. Architecture & Project Layout

The codebase follows a modular, layered architecture:

```text
TransmissionRemote-iOS/
├── App/                  # App entry point, AppEnvironment (DI container & active server state)
├── Core/
│   ├── Models/           # Domain models: Torrent, ServerConfig, SessionStats, TorrentFile, Peer
│   ├── Network/          # TransmissionClient, TransmissionInterceptor (409 CSRF & auth)
│   ├── Storage/          # KeychainService (passwords), ServerRepository (UserDefaults)
│   └── Haptics/          # HapticFeedbackManager (impact, notification, selection)
├── Features/
│   ├── TorrentList/      # TorrentListView, TorrentRowView, SpeedIndicatorView, FilterChipView
│   ├── TorrentDetail/    # TorrentDetailView (summary, files progress, connected peers)
│   ├── AddTorrent/       # AddTorrentView (magnet paste, .torrent file importer)
│   └── ServerManagement/ # ServerListView, ServerEditView, connection testing
└── Resources/
    ├── Localization/     # Localizable.xcstrings, InfoPlist.xcstrings (6 languages)
    └── Assets.xcassets   # AppIcon, AccentColor
```

---

## 5. UI & UX Design Patterns

* **Navigation & Toolbar (`TorrentListView`):**
  * **Leading:** Minimalist `server.rack` icon with a `Menu` to switch the active server or jump to Server Management.
  * **Principal:** Plain headline text with the active server's name (`Text(environment?.activeServer?.name ?? "")`).
  * **Trailing:** Add Torrent button (`+`) only. Redundant settings gear (`gearshape`) is omitted.
* **Aggregate Speeds:** Docked in the system bottom bar (`ToolbarItem(placement: .bottomBar)`) using `SpeedIndicatorView` (`↓ DL • ↑ UL`) to prevent title truncation.
* **Search:** Native iOS pull-to-search list via `.searchable(text: ..., placement: .navigationBarDrawer(displayMode: .automatic))`.
* **Deletion Confirmation:** Native iOS bottom action sheet presented via `.confirmationDialog` with `.titleAndMessage` specifying the torrent's title ("Delete Torrent Only" vs "Delete Torrent and Data").
* **Haptics:** Contextual tactile feedback on actions: toggle play/pause, swipe actions, add torrent success.

---

## 6. Transmission RPC Protocol Specification

* **CSRF 409 Handshake:** Transmission enforces CSRF protection using the `X-Transmission-Session-Id` header. The first request returns HTTP `409 Conflict`. `TransmissionInterceptor` captures the new ID from response headers and transparently triggers `completion(.retry)`.
* **Self-Signed Certificates:** For servers with `trustSelfSignedCertificates: true`, configure Alamofire's `ServerTrustManager` with `DisabledTrustEvaluator()`.
* **RPC Methods:** `torrent-get`, `torrent-start`, `torrent-stop`, `torrent-remove`, `torrent-add`, `session-stats`.
* **App Transport Security (ATS):** Configured for local network access (`NSAllowsLocalNetworking: true`, `NSAllowsArbitraryLoads: true`) to support self-hosted servers on LAN custom ports.

---

## 7. App Store Review & Moderation Guidelines

1. **Guideline 2.5.2 (Downloading BitTorrent):** The application is strictly positioned as a *«Remote Management Utility for personal home NAS and Transmission servers»*. The app **is not a torrent client** and does not download files onto the iPhone.
2. **Content Legality:** All preview and demo torrents must be 100% legal open-source distributions (`Ubuntu Desktop`, `Fedora Workstation`, `Arch Linux`, `LibreOffice`).
3. **Local Network (Guideline 5.1.1):** Localized description required for `NSLocalNetworkUsageDescription` in `InfoPlist.xcstrings`.

---

## 8. Release Roadmap

* **v1.0 (Current State):**
  * Complete core app: multi-server support, torrent list, filters, swipe actions, torrent details (peers, files), in-app torrent adding (magnet/file), `magnet://` deep linking, 6 localizations, Haptic feedback.
* **v1.1 (Next Step):**
  * Extract core modules (`Core/`) into a local SPM package `TransmissionKit`.
  * **Share Extension** (add torrents from Safari/Files in one tap).
  * Shared **App Group** (`group.com.smnk.transmission-remote-ios.shared`) and shared Keychain access.
  * **WidgetKit** (Home Screen widgets) and **Live Activities** (Dynamic Island).
  * **BackgroundTasks** (`BGAppRefresh`).
