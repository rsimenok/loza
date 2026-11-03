# AGENTS.md — Instructions and Architectural Guidelines for AI Agents

This file contains rules, conventions, stack details, and context for autonomous AI agents (Claude Code, Cursor, Copilot, Antigravity) working on the **Loza** codebase.

---

## 1. Project Overview

* **Purpose:** Lightweight, private, and native iOS client for remote management of Transmission daemons (Home NAS, Synology, TrueNAS, Unraid, VPS).
* **Tech Stack:** Swift 6 (Strict Concurrency), SwiftUI, Alamofire 5.x (SPM), Security Framework (Keychain).
* **Target Platform:** iOS 17.0+ (`@Observable`, NavigationStack, String Catalogs).
* **License:** GNU General Public License v3.0 (GPLv3).
* **Privacy:** Zero third-party analytics, telemetry tracking, or advertisements.

---

## 2. Build & Test Commands

Due to Xcode sandboxing and caching, always provide `-derivedDataPath /tmp/DerivedData`:

```bash
# Build project for iOS Simulator
xcodebuild -project Loza.xcodeproj -scheme Loza -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/DerivedData build

# Run Unit Tests
xcodebuild test -project Loza.xcodeproj -scheme Loza -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/DerivedData
```

---

## 3. Core Principles & Codebase Rules

### 3.1. Access Control — NO Unnecessary `public`
* All entities within the main application target must use Swift's standard default access level — **`internal`**, or **`private` / `fileprivate`**.
* **DO NOT use `public`** in application files! `public` is only required when code is extracted into a standalone SPM package or framework.
* Unit tests use `@testable import Loza`, which grants full access to all `internal` entities.

### 3.2. Swift 6 Concurrency & State Management
* The project strictly enforces Swift 6 Strict Concurrency checking.
* UI components and ViewModels must be annotated with `@MainActor` and utilize the modern `@Observable` macro (never use deprecated `ObservableObject` / `@Published`).
* Network clients and services must conform to `Sendable`. Mutable state in clients/interceptors (such as `sessionId`) must be protected by thread-safe primitives (`OSAllocatedUnfairLock` or `os_unfair_lock`).

### 3.3. Localization (String Catalogs)
* All user-facing strings must be managed via String Catalogs:
  * `Loza/Resources/Localization/Localizable.xcstrings`
  * `Loza/Resources/Localization/InfoPlist.xcstrings`
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

### 3.6. Quality Assurance & Test Case Maintenance (`TEST_CASES.md`)
* **Continuous Synchronization:** When adding a new feature, modifying UI/user flows, or fixing a bug, agents MUST inspect and update `/TEST_CASES.md`:
  * Add new test cases following the `[TC-XXX-NNN]` convention for newly introduced behavior or edge cases.
  * Update existing test cases if steps, preconditions, or expected results changed.
  * Prune or mark deprecated test cases if functionality was removed.
* **Commit Discipline (No Gratuitous Doc Commits):**
  * **DO NOT** create standalone git commits solely for modifying documentation (`TEST_CASES.md`, specs, plans) during task execution.
  * Keep documentation modifications in the local working directory and bundle them atomically with the final feature/fix commit (or leave them in the working tree unless explicitly instructed to commit).
* **Pre-Completion QA Check:** Review the relevant `TC-*` test cases in `/TEST_CASES.md` as an indispensable verification checklist before completing any task.

---

## 4. Architecture & Project Layout

The codebase follows a modular, layered architecture:

```text
Loza/
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
  * Shared **App Group** (`group.com.smnk.loza.shared`) and shared Keychain access.
  * **WidgetKit** (Home Screen widgets) and **Live Activities** (Dynamic Island).
  * **BackgroundTasks** (`BGAppRefresh`).

<!-- trail:start -->
## Trail — repo context graph

This repo is indexed in `.trail/cache/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `trail map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `trail ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `trail grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `trail skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `trail callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `.trail/cache/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `trail ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `trail build` (deterministic,
no API key, $0).
<!-- trail:end -->
