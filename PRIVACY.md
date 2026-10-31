# Privacy Policy for Loza

*Last updated: October 31, 2026*

**Loza** ("the Application") is an open-source remote management client for Transmission daemons, developed by Roman Simenok ("the Developer"). 

Your privacy is a core principle of this project. Loza is built from the ground up to respect your privacy and give you full control over your data.

---

## 1. Information We Do Not Collect

* **Zero Analytics & Telemetry:** Loza contains no third-party analytics libraries, advertising SDKs, tracking frameworks, or behavioral profiling tools.
* **No Account Creation:** Using Loza does not require creating an account with us.
* **No Data Transmission to the Developer:** None of your personal data, device information, IP addresses, or usage statistics are transmitted to the Developer or any third-party analytics servers.

---

## 2. Server Configuration & Local Storage

* **Transmission Server Credentials:** When you configure a server connection (host, port, username, password), this data is stored locally on your device.
* **Keychain Security:** All passwords and sensitive authentication tokens are stored exclusively in the secure iOS Keychain using Apple's Security Framework.
* **Direct Communication:** Communication occurs directly between your iOS device and your designated Transmission server over HTTP or HTTPS. No data ever passes through an intermediary server or proxy managed by the Developer.

---

## 3. In-App Purchases and Subscriptions

* Loza offers voluntary tips and supporter subscriptions through Apple's **StoreKit 2** framework.
* All financial transactions, payments, and subscription renewals are processed directly and securely by Apple. 
* The Developer does not collect, receive, or store your credit card information, billing address, or payment details. For more information on how Apple handles transaction data, please review [Apple's Privacy Policy](https://www.apple.com/legal/privacy/).

---

## 4. Local Network & System Permissions

* **Local Network Access:** Loza may request permission to access your local network (`NSLocalNetworkUsageDescription`). This permission is used solely to discover and communicate with Transmission daemons running on your local area network (LAN, NAS, Raspberry Pi).
* No data accessed through this permission is collected, stored remotely, or shared.

---

## 5. Open Source Transparency

Loza is 100% open-source software under the MIT License. The complete source code is publicly accessible and auditable at:  
[https://github.com/rsimenok/loza](https://github.com/rsimenok/loza)

---

## 6. Contact & Inquiries

If you have any questions or concerns regarding this Privacy Policy, please open an issue on the official GitHub repository:  
[https://github.com/rsimenok/loza/issues](https://github.com/rsimenok/loza/issues)
