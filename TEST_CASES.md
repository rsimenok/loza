# Loza Quality Assurance Test Cases Catalog

Welcome to the **Loza** Quality Assurance Test Cases Catalog. This document outlines functional, regression, smoke, and edge-case testing procedures for the Loza iOS application (Transmission daemon remote management client).

---

## 1. Catalog Legend & Conventions

* **Identifiers:** `TC-<MODULE>-<NUMBER>`
  * `TC-SRV-*` — Server Management
  * `TC-LST-*` — Torrent List & Filter Bar
  * `TC-ACT-*` — Torrent Operations & Actions
  * `TC-DET-*` — Torrent Detail Screen
  * `TC-ADD-*` — Add Torrent Flows
  * `TC-PUR-*` — In-App Purchases (StoreKit 2 Tip Jar & Supporter)
  * `TC-LOC-*` — Localization & Tactile Haptics
  * `TC-PWR-*` — Lifecycle, Concurrency & Battery
* **Type / Priority:**
  * `Smoke`: Critical user paths and core functionality. Must pass before any release or major merge.
  * `Regression`: Edge cases, validation checks, network recovery, and secondary flows.

---

## 2. Server Management (`TC-SRV`)

### `[TC-SRV-001]` First Launch Empty State & Add First HTTP Server
- **Type / Priority:** `Smoke`
- **Preconditions:** Fresh application launch with no configured servers (or all existing servers deleted).
- **Steps:**
  1. Launch Loza.
  2. Observe empty state message indicating no server configured and tap "Configure Server" -> "Add First Server".
  3. Verify `ServerEditView` is pushed into the navigation stack (with leading `< Servers` back button and trailing blue checkmark button).
  4. Enter Name: `Home NAS`.
  5. Enter Host: valid local Transmission IP (e.g., `192.168.1.100`), Port: `9091`, Path: `/transmission/rpc`.
  6. Enter Username and Password if required by the daemon.
  7. Ensure "Use HTTPS" is toggled OFF.
  8. Tap "Test Connection".
  9. Upon success alert ("Connection Successful", version indicated), tap the blue checkmark button.
- **Expected Result:**
  - Connection test succeeds with green indicator/alert.
  - Server is saved into `UserDefaults` (metadata) and Keychain (credentials).
  - Pushed view dismisses back to `ServerListView` with the new server active, and tapping leading `xmark` returns to `TorrentListView` showing `Home NAS` in the navigation header.

---

### `[TC-SRV-002]` Add HTTPS Server with Self-Signed Certificate
- **Type / Priority:** `Regression`
- **Preconditions:** Transmission daemon running behind HTTPS reverse proxy with self-signed SSL certificate.
- **Steps:**
  1. Open Server Management from toolbar (`server.rack` menu -> "Manage Servers").
  2. Tap `+` (Add Server).
  3. Enter server Name, Host, Port (e.g. `443` or `9091`), and RPC path.
  4. Enable "Use HTTPS".
  5. Enable "Trust Self-Signed Certificates".
  6. Tap "Test Connection".
  7. Tap "Save".
- **Expected Result:**
  - Alamofire `DisabledTrustEvaluator` handles handshake without SSL pinning/validation error.
  - Test connection succeeds and torrent list loads successfully over HTTPS.

---

### `[TC-SRV-003]` Form Validation & Invalid Credentials (HTTP 401)
- **Type / Priority:** `Regression`
- **Preconditions:** Server list view or Add Server screen open.
- **Steps:**
  1. Attempt to tap "Save" or "Test Connection" with empty Host.
  2. Enter Host: `invalid host with spaces!!` or port `99999`.
  3. Enter valid Host but intentionally incorrect password.
  4. Tap "Test Connection".
- **Expected Result:**
  - Form field validation highlights errors (invalid port or required host field).
  - Invalid credentials test returns an alert detailing HTTP 401 Unauthorized or connection failure.
  - Server cannot be saved until validation requirements pass.

---

### `[TC-SRV-004]` Edit Server Settings & Keychain Password Update
- **Type / Priority:** `Regression`
- **Preconditions:** At least one server saved in Loza.
- **Steps:**
  1. Go to Server Management list.
  2. Swipe left on an existing server row and tap "Edit" (or long press and select "Edit").
  3. Verify `ServerEditView` is pushed into the navigation stack (with leading `< Servers` and trailing blue checkmark button).
  4. Change the server Name and update the password field.
  5. Tap the blue checkmark button.
  6. Return to Torrent List and trigger refresh.
- **Expected Result:**
  - Pushed view dismisses cleanly back to `ServerListView`.
  - Updated server title is reflected in the navigation header.
  - Updated password in `KeychainService` is used for subsequent RPC requests without authentication failure.

---

### `[TC-SRV-005]` Multi-Server Switching via Toolbar Menu
- **Type / Priority:** `Smoke`
- **Preconditions:** At least two distinct servers saved (e.g., `Home NAS` and `Seedbox VPS`).
- **Steps:**
  1. From `TorrentListView`, tap the `server.rack` icon in the leading toolbar.
  2. Review the list of configured servers in the menu (checkmark next to currently active server).
  3. Select `Seedbox VPS`.
- **Expected Result:**
  - Navigation bar title immediately changes to `Seedbox VPS`.
  - Active server state in `AppEnvironment` switches.
  - Torrent list immediately refreshes with torrents belonging to `Seedbox VPS`.
  - Bottom bar aggregate speeds update to reflect `Seedbox VPS`.

---

### `[TC-SRV-006]` Delete Active vs Inactive Server
- **Type / Priority:** `Regression`
- **Preconditions:** Two servers configured (`Server A` active, `Server B` inactive).
- **Steps:**
  1. Open Server Management.
  2. Swipe left on `Server B` and tap "Delete". Verify `Server A` remains active.
  3. Swipe left on `Server A` (active) and tap "Delete".
- **Expected Result:**
  - Deleting `Server B` leaves `Server A` untouched.
  - Deleting active `Server A` removes its credentials from Keychain, and the app gracefully falls back to empty state or remaining configured server without crashing.

---

## 3. Torrent List & Filter Bar (`TC-LST`)

### `[TC-LST-001]` Initial List Fetch & Default Sorting
- **Type / Priority:** `Smoke`
- **Preconditions:** Connected server with at least 3 torrents in various states.
- **Steps:**
  1. Open Loza on `TorrentListView`.
  2. Wait for RPC `torrent-get` response.
- **Expected Result:**
  - All torrents display in clean card rows showing name, progress bar, formatted size, and status badge.
  - Torrents are sorted alphabetically (or according to default active sort).
  - No UI jumping or flicker during periodic polling updates.

---

### `[TC-LST-002]` Status Filter Chips
- **Type / Priority:** `Smoke`
- **Preconditions:** Connected server with downloading, seeding, paused, and finished torrents.
- **Steps:**
  1. Observe the horizontal filter bar below the navigation bar (`All`, `Downloading`, `Seeding`, `Paused`, `Active`, `Error`).
  2. Tap `Downloading`: verify only torrents with status `.downloading` appear.
  3. Tap `Seeding`: verify only seeding torrents appear.
  4. Tap `Paused`: verify only stopped torrents appear.
  5. Tap `All`: all torrents return.
- **Expected Result:**
  - Selected filter chip has prominent visual selection styling.
  - List filters instantaneously using local state without blocking network requests.

---

### `[TC-LST-003]` Pull-to-Search (`.searchable`)
- **Type / Priority:** `Smoke`
- **Preconditions:** Connected server with multiple torrents.
- **Steps:**
  1. Pull down list or tap search bar in drawer.
  2. Type partial name of an existing torrent (e.g. `Ubuntu`).
  3. Observe list filtering in real time.
  4. Tap the `(X)` clear button in search field.
- **Expected Result:**
  - Only torrents matching query (case-insensitive) remain visible.
  - Clearing search field restores the complete list.
  - Navigating into detail view and back preserves search field accessibility.

---

### `[TC-LST-004]` Manual Pull-to-Refresh
- **Type / Priority:** `Smoke`
- **Preconditions:** Connected server on `TorrentListView`.
- **Steps:**
  1. Drag torrent list down until refresh spinner appears.
  2. Release to trigger refresh.
- **Expected Result:**
  - Native iOS refresh control spins.
  - App sends immediate `torrent-get` & `session-stats` RPC.
  - Spinner dismisses cleanly once response arrives.

---

### `[TC-LST-005]` Aggregate Speed Indicator in Bottom Bar
- **Type / Priority:** `Regression`
- **Preconditions:** Active server with active download and/or upload activity.
- **Steps:**
  1. Look at the bottom toolbar (`ToolbarItem(placement: .bottomBar)`).
  2. Verify download speed (`↓ <rate>`) and upload speed (`↑ <rate>`).
- **Expected Result:**
  - Speed indicator displays units formatted dynamically (`KB/s` or `MB/s`).
  - Text is not truncated or squished on both compact iPhone and large iPad screens.

---

### `[TC-LST-006]` Vertical Scroll Indicator Inset & Alignment
- **Type / Priority:** `Regression`
- **Preconditions:** Torrent list populated with more torrents than fit on screen.
- **Steps:**
  1. On `TorrentListView`, scroll the list vertically.
  2. Observe the right-edge vertical scroll indicator.
- **Expected Result:**
  - The vertical scroll indicator starts directly below the horizontal filter bar without extra artificial vertical offsets.
  - The scroll indicator moves smoothly from top to bottom across the visible list viewport.

---

## 4. Torrent Operations & Actions (`TC-ACT`)

### `[TC-ACT-001]` Resume Paused Torrent
- **Type / Priority:** `Smoke`
- **Preconditions:** At least one torrent in paused/stopped state.
- **Steps:**
  1. Swipe leading-to-trailing on a paused torrent row (or tap resume in context menu/detail).
  2. Observe action button and trigger "Resume".
- **Expected Result:**
  - Haptic feedback fires.
  - RPC method `torrent-start` is dispatched.
  - Torrent status badge transitions from Paused to Downloading/Seeding.

---

### `[TC-ACT-002]` Pause Active Torrent
- **Type / Priority:** `Smoke`
- **Preconditions:** At least one active downloading/seeding torrent.
- **Steps:**
  1. Swipe on the torrent or tap "Pause" in context menu/detail.
- **Expected Result:**
  - RPC method `torrent-stop` is sent.
  - Torrent status transitions to Paused.
  - Speed drops to zero and aggregate speed updates.

---

### `[TC-ACT-003]` Swipe-to-Delete Confirmation Action Sheet
- **Type / Priority:** `Smoke`
- **Preconditions:** At least one torrent in the list.
- **Steps:**
  1. Swipe left on a torrent row to reveal red "Delete" action.
  2. Tap "Delete".
  3. Observe the `.confirmationDialog` Action Sheet with title and message specifying the torrent name.
  4. Tap "Delete Torrent Only".
- **Expected Result:**
  - The row remains anchored in the list while the confirmation dialog is open.
  - RPC `torrent-remove` is dispatched with `delete-local-data: false`.
  - Torrent is removed from list.

---

### `[TC-ACT-004]` Dismiss Delete Confirmation Dialog (Cancel)
- **Type / Priority:** `Regression`
- **Preconditions:** Any torrent displayed in the list.
- **Steps:**
  1. Swipe left and tap "Delete" to present confirmation dialog.
  2. Tap "Cancel" (or tap outside sheet).
- **Expected Result:**
  - Dialog dismisses.
  - Torrent remains in the list intact.
  - No swipe visual glitch or disappearing cell.

---

### `[TC-ACT-005]` Delete Torrent and Local Data
- **Type / Priority:** `Regression`
- **Preconditions:** Any torrent displayed in the list.
- **Steps:**
  1. Swipe left and tap "Delete".
  2. Tap "Delete Torrent and Data" (destructive action).
- **Expected Result:**
  - RPC `torrent-remove` is dispatched with `delete-local-data: true`.
  - Torrent and its downloaded files are deleted from the Transmission server.

---

## 5. Torrent Details (`TC-DET`)

### `[TC-DET-001]` Detail Navigation (iPhone & iPad)
- **Type / Priority:** `Smoke`
- **Preconditions:** Connected server with torrents.
- **Steps:**
  1. Tap any torrent card in `TorrentListView`.
- **Expected Result:**
  - On iPhone: pushes `TorrentDetailView` into `NavigationStack`.
  - On iPad: updates detail view column in `NavigationSplitView`.
  - Title shows torrent name.

---

### `[TC-DET-002]` Summary Section Metrics
- **Type / Priority:** `Smoke`
- **Preconditions:** `TorrentDetailView` open for active torrent.
- **Steps:**
  1. Inspect Summary section.
- **Expected Result:**
  - Progress bar shows exact completion percentage.
  - Downloaded / Uploaded amounts and total size formatted properly (`MB`, `GB`).
  - Transfer speeds (DL / UL), Ratio, and ETA formatted into human-readable strings.

---

### `[TC-DET-003]` Files Tab Display
- **Type / Priority:** `Regression`
- **Preconditions:** Detail view open for multi-file torrent (e.g. Linux distribution ISO or album).
- **Steps:**
  1. Select "Files" tab/picker.
  2. Scroll through files list.
- **Expected Result:**
  - File names, sizes, and individual completion progress are accurately displayed.
  - Fast rendering without UI lag on torrents with 50+ files.

---

### `[TC-DET-004]` Peers Tab Display
- **Type / Priority:** `Regression`
- **Preconditions:** Detail view open for active torrent connected to peers.
- **Steps:**
  1. Select "Peers" tab/picker.
- **Expected Result:**
  - Displays list of connected peers.
  - Each peer row shows IP address, client name, flags (e.g., `D`, `U`), and transfer rates.

---

### `[TC-DET-005]` Detail Toolbar Delete Action
- **Type / Priority:** `Smoke`
- **Preconditions:** `TorrentDetailView` open.
- **Steps:**
  1. Tap the trash can button (`trash`) in the detail navigation bar.
  2. Confirm deletion in the action sheet.
- **Expected Result:**
  - Action sheet appears anchored to toolbar.
  - Confirming deletion removes torrent and pops detail view back to `TorrentListView`.

---

### `[TC-DET-006]` Unified Status Header & Progress Bar
- **Type / Priority:** `Smoke`
- **Preconditions:** `TorrentDetailView` open for a torrent in any state (downloading, seeding, paused).
- **Steps:**
  1. Observe the "Status" ("Статус") section at the top of the detail screen.
- **Expected Result:**
  - The status badge (e.g. `🟢 Seeding` / `Роздача`), completion percentage (`100.0%`), and horizontal progress bar are unified inside the top cell of the section without a table divider separating them.
  - No awkward empty row or excessive vertical dead space exists between the status badge and the progress bar.
  - The progress bar tint matches the torrent state (e.g. `Color.seedingProgress` during seeding, `.accentColor` during download, `.tertiaryLabel` when stopped, `.red` on error).

---

## 6. Add Torrent Flows (`TC-ADD`)

### `[TC-ADD-001]` Present Add Torrent Sheet
- **Type / Priority:** `Smoke`
- **Preconditions:** `TorrentListView` loaded with active server.
- **Steps:**
  1. Tap `+` button in trailing navigation bar.
- **Expected Result:**
  - `AddTorrentView` presents modally as a sheet with leading `xmark` (Cancel) and trailing blue `checkmark` (Add).
  - Focus is readily available, showing options for Magnet Link and .torrent file import.

---

### `[TC-ADD-002]` Add Torrent via Magnet Link
- **Type / Priority:** `Smoke`
- **Preconditions:** `AddTorrentView` open, valid magnet URI copied to clipboard.
- **Steps:**
  1. Paste valid magnet URI (e.g. `magnet:?xt=urn:btih:...`).
  2. Toggle "Start when added" switch ON.
  3. Tap the blue checkmark button.
- **Expected Result:**
  - Success haptic feedback fires.
  - RPC method `torrent-add` sent with `filename: <magnetUri>` and `paused: false`.
  - Sheet dismisses and new torrent appears in `TorrentListView`.

---

### `[TC-ADD-003]` Invalid Magnet URI Validation
- **Type / Priority:** `Regression`
- **Preconditions:** `AddTorrentView` open.
- **Steps:**
  1. Enter invalid string (e.g., `https://example.com` or `plain text`) in magnet input.
  2. Tap "Add Torrent".
- **Expected Result:**
  - Inline error or alert indicates invalid magnet URI format.
  - No invalid RPC is dispatched to daemon.

---

### `[TC-ADD-004]` Import `.torrent` File via Document Picker
- **Type / Priority:** `Regression`
- **Preconditions:** Valid `.torrent` file saved in iOS Files / iCloud Drive.
- **Steps:**
  1. In `AddTorrentView`, tap "Choose .torrent File".
  2. System Document Picker presents.
  3. Select valid `.torrent` file.
  4. Tap "Add Torrent".
- **Expected Result:**
  - File data is securely accessed via security-scoped URL, read and converted to Base64 `metainfo`.
  - RPC `torrent-add` dispatched with `metainfo`.
  - Torrent added successfully.

---

### `[TC-ADD-005]` Deep Linking via `magnet://` URL Scheme
- **Type / Priority:** `Smoke`
- **Preconditions:** Loza installed; Safari or Notes open with clickable `magnet:?...` link.
- **Steps:**
  1. Tap the magnet link in Safari/Notes.
  2. System prompts "Open in Loza?". Tap Open.
- **Expected Result:**
  - Loza opens.
  - `AddTorrentView` is presented automatically with the magnet URL pre-filled.

---

## 7. In-App Purchases / Tip Jar & Subscriptions (`TC-PUR`)

### `[TC-PUR-001]` StoreKit 2 Products Loading & Push Navigation from About
- **Type / Priority:** `Smoke`
- **Preconditions:** About screen opened (`server.rack` menu -> About).
- **Steps:**
  1. In `AboutView`, observe disclosure chevron on "Tip Jar" row and tap it.
  2. Verify `TipJarView` is pushed into the navigation stack with standard leading `< About` back button (no secondary sheet presented).
- **Expected Result:**
  - View pushes smoothly without sheet-over-sheet hierarchy.
  - StoreKit 2 queries 4 tip tiers (`$0.99`, `$1.99`, `$4.99`, `$9.99`) and monthly subscription (`$0.99/mo`).
  - Products display with localized prices and currency symbols matching user's Storefront.
  - Tapping `< About` pops back to `AboutView`.

---

### `[TC-PUR-002]` One-time Tip Purchase Flow
- **Type / Priority:** `Regression`
- **Preconditions:** `TipJarView` open in sandbox or StoreKit test environment.
- **Steps:**
  1. Tap one of the tip tiers (e.g. `☕️ Coffee`).
  2. Complete transaction in system payment sheet.
- **Expected Result:**
  - Success haptic fires and celebration overlay (confetti/sparkles) animates.
  - `PurchaseManager.hasEverTipped` updates to true.
  - `🌟 Supporter` badge displays on About screen.

---

### `[TC-PUR-003]` Supporter Monthly Subscription
- **Type / Priority:** `Regression`
- **Preconditions:** `TipJarView` open with non-subscribed user.
- **Steps:**
  1. Tap "Join Supporter Club" ($0.99/mo).
  2. Approve subscription in payment sheet.
- **Expected Result:**
  - Subscription entitlement verified via StoreKit 2 JWS.
  - Card updates to "Active Supporter ✅" with button to manage subscriptions.

---

### `[TC-PUR-004]` Restore Purchases & Error Handling
- **Type / Priority:** `Regression`
- **Preconditions:** `TipJarView` open.
- **Steps:**
  1. Tap "Restore Purchases".
  2. Alternatively, initiate a purchase and tap "Cancel" in the payment sheet.
- **Expected Result:**
  - Restore invokes `AppStore.sync()` and re-evaluates entitlements without crash.
  - User cancellation dismisses sheet cleanly without error banners.

---

### `[TC-PUR-005]` Direct Modal Presentation & Xmark Dismissal
- **Type / Priority:** `Smoke`
- **Preconditions:** `TorrentListView` visible.
- **Steps:**
  1. Tap `server.rack` menu in toolbar -> select "Support Loza".
  2. Verify `TipJarView` opens as a modal sheet with an `xmark` dismiss icon in the top bar trailing.
  3. Tap the `xmark` button.
- **Expected Result:**
  - Sheet dismisses cleanly returning to `TorrentListView`.

---

## 8. Localization & Tactile Haptics (`TC-LOC`)

### `[TC-LOC-001]` Ukrainian Language Verification (`uk`)
- **Type / Priority:** `Smoke`
- **Preconditions:** Device or simulator set to Ukrainian (`uk_UA`).
- **Steps:**
  1. Launch Loza and traverse `TorrentListView`, `TorrentDetailView`, `AddTorrentView`, and `AboutView`.
- **Expected Result:**
  - All labels, buttons, navigation titles, and status chips are rendered in natural Ukrainian.
  - Zero raw keys (e.g., `torrent_list_title`) visible.

---

### `[TC-LOC-002]` Multilingual Coverage (`en`, `de`, `fr`, `es`, `pl`)
- **Type / Priority:** `Regression`
- **Preconditions:** Simulator launched with `-AppleLanguages (<lang>)`.
- **Steps:**
  1. Test each supported language: German (`de`), French (`fr`), Spanish (`es`), Polish (`pl`).
  2. Verify all UI strings.
- **Expected Result:**
  - All 6 supported languages display correct translations from `Localizable.xcstrings` and `InfoPlist.xcstrings`.
  - Russian language is strictly excluded.

---

### `[TC-LOC-003]` Haptic Feedback Contextual Triggering
- **Type / Priority:** `Regression`
- **Preconditions:** Physical iPhone device (Haptics enabled in Settings).
- **Steps:**
  1. Tap play/pause on a torrent.
  2. Swipe and tap delete.
  3. Successfully add a new torrent.
- **Expected Result:**
  - Distinct tactile responses fire via `HapticManager`:
    - Selection/impact on play/pause and swipe.
    - Success notification haptic on adding torrent or completing tip purchase.

---

### `[TC-LOC-004]` Dynamic Type Accessibility Scaling
- **Type / Priority:** `Regression`
- **Preconditions:** iOS Settings -> Accessibility -> Larger Text enabled.
- **Steps:**
  1. Increase Dynamic Type to maximum standard or accessibility size.
  2. View `TorrentRowView` and `SpeedIndicatorView`.
- **Expected Result:**
  - Text scales legibly.
  - Torrent name wraps gracefully; speed indicators do not clip or overlap navigation elements.

---

## 9. Lifecycle, Concurrency & Battery (`TC-PWR`)

### `[TC-PWR-001]` Background Polling Suspension (Zero Battery Drain)
- **Type / Priority:** `Smoke`
- **Preconditions:** Active server polling every 2–3s in `TorrentListView`.
- **Steps:**
  1. Send app to background (swipe up to Home or lock screen).
  2. Monitor network traffic / console logs.
- **Expected Result:**
  - `ScenePhase.background` immediately cancels polling `Task`.
  - Zero HTTP/RPC requests sent to Transmission daemon while suspended.

---

### `[TC-PWR-002]` Foreground Polling Resume
- **Type / Priority:** `Smoke`
- **Preconditions:** App suspended in background.
- **Steps:**
  1. Bring Loza back to foreground (`ScenePhase.active`).
- **Expected Result:**
  - Polling task restarts immediately.
  - Fresh server stats and torrent list are displayed without requiring manual pull-to-refresh.

---

### `[TC-PWR-003]` Transparent CSRF 409 Session Handshake
- **Type / Priority:** `Regression`
- **Preconditions:** Transmission daemon restarted or session expired.
- **Steps:**
  1. Trigger any RPC request (e.g. pull to refresh).
  2. Transmission returns HTTP 409 Conflict with `X-Transmission-Session-Id` header.
- **Expected Result:**
  - `TransmissionInterceptor` intercepts 409 status code.
  - Thread-safe storage captures new session ID.
  - Interceptor retries request transparently.
  - User sees no error or disconnection alert.
