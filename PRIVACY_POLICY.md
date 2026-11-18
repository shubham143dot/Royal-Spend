# Privacy Policy – Royal Spend: Expense Tracker & Travel Planner

**Last Updated:** November 18, 2026  
**Effective Date:** November 18, 2026  
**Application Name:** Royal Spend – Expense Tracker & Travel Planner  
**Package Name:** `com.royalshubham.royalspend.royal_spend`  
**Developer / Organization:** Royal Shubham Pixel Labs (“we”, “our”, or “us”)  
**Data Protection & Privacy Contact:** [royalshubhampixellabs@gmail.com](mailto:royalshubhampixellabs@gmail.com)  
**Administrative Contact:** [subhamsoudeep@gmail.com](mailto:subhamsoudeep@gmail.com)  
**Official Online Privacy Policy:** [https://sites.google.com/view/royalspend/home](https://sites.google.com/view/royalspend/home)  

---

## 1. Introduction & Overview

Welcome to **Royal Spend – Expense Tracker & Travel Planner** (the “App”). We are deeply committed to respecting your privacy, protecting your personal confidentiality, and giving you uncompromising sovereignty over your financial and travel data.

This Privacy Policy constitutes an official legal agreement between you and **Royal Shubham Pixel Labs**. It outlines in precise detail how Royal Spend accesses, collects, handles, stores, processes, synchronizes, protects, and permanently deletes user data on Android and iOS platforms.

This policy is authored in strict compliance with:
* **Google Play Developer Program Policies** (specifically including the *User Data Policy*, *Financial Services Policy*, *Sensitive Permissions Guidelines*, and *Account Deletion Requirements*).
* **Apple App Store Review Guidelines** (specifically *Section 5.1: Privacy and Data Use*).
* **General Data Protection Regulation (GDPR / UK GDPR)**.
* **California Consumer Privacy Act (CCPA / CPRA)**.
* **India Digital Personal Data Protection Act (DPDP Act 2023)**.

Royal Spend is engineered with an **offline-first, privacy-by-design architecture**. We strictly do not sell, rent, monetize, or trade your personal or financial data; we do not bundle third-party advertising SDKs; and we do not participate in cross-app behavioral tracking.

By downloading, installing, accessing, or using Royal Spend, you acknowledge that you have read, understood, and consented to the data practices described herein. If you do not agree, please do not use the application.

---

## 2. Nature of the Application (Financial Services Clarification)

To comply with **Google Play’s Financial Services Policy**:
* **Personal Budgeting Utility Only:** Royal Spend is an independent personal expense tracker, budgeting tool, and travel planning utility.
* **No Banking / Lending / Credit Services:** The App **does NOT** provide personal loans, payday loans, peer-to-peer lending, banking facilities, investment brokerage, cryptocurrency trading, or credit scoring.
* **No Direct Bank Account Access:** The App **does NOT** connect directly to your bank accounts, credit card portals, or financial institutions via open-banking APIs (such as Plaid or Yodlee). All financial figures, category selections, and notes are entered and managed directly by you.
* **No Payment Processing:** Royal Spend does not process financial payments, monetary transfers, or real-money transactions. Group bill split calculations are purely mathematical tracking ledgers for personal convenience.

---

## 3. Information We Access, Collect, and Process

We collect only the minimum data strictly required to deliver budgeting, analytics, travel itinerary coordination, and optional multi-device cloud synchronization.

### A. Personal & Account Identifiers
* **Authentication Credentials:** When you register or log in using **Email & Password** or **Google Sign-In**, we access and store your email address, display name, and unique Firebase User ID (`uid`) managed securely through **Google Firebase Authentication**.
* **Profile Customization:** You may voluntarily set a preferred display name, select a primary display currency (e.g., INR ₹, USD $, EUR €), and upload a custom profile avatar picture.
* **Offline / Guest Mode:** If you choose to use the application offline without signing in, **no account or personal identity data is ever transmitted to our servers**. All data remains 100% confined to your device's local database.

### B. Financial & Expense Tracking Records
* **Transaction Details:** Expense amounts, timestamps, payment methods (Cash, Credit Card, Debit Card, UPI, Net Banking), expenditure categories (such as Food & Dining, Shopping, Travel, Entertainment, Bills & Utilities, Healthcare, etc.), merchant/payee names, tags, and custom transaction notes.
* **Budgets & Targets:** Monthly spending targets, overall budget limits, category-level spending allocations, and quick-log shortcuts.
* **Local Processing:** All daily summaries, monthly projections, category breakdowns, and analytics charts are computed directly on your device.

### C. Travel Planner & Itinerary Data
* **Trip Overviews:** Trip titles, destinations, origin/departure cities, trip start and end dates, and overall travel budget allocations.
* **Daily Itineraries:** Day-by-day activity schedules, departure hubs, scheduled times, estimated activity costs, booking statuses (confirmed, unconfirmed), and activity categories (sightseeing, dining, transport, experience).
* **Saved Places & Waypoints:** Landmark names, physical addresses, and geographic coordinates (latitude and longitude) that you explicitly search, save, or pin to an itinerary.
* **Transit & Lodging Records:** Flight, train, bus, or taxi itineraries; hotel/stay check-in and check-out dates, room types, and booking reference numbers.
* **Group Expense Splits:** Co-traveler names/identifiers, amounts contributed, and mathematically simplified debt settlement balances.

### D. Biometric & Device App Lock Data
* **Native Device Security:** To safeguard your sensitive financial records from unauthorized physical access, Royal Spend includes an optional **App Lock** security feature supporting device biometrics (Fingerprint, Face ID, Android BiometricPrompt) and device credentials (PIN, pattern, passcode).
* **Absolute Biometric Privacy Guarantee:**
  - The App communicates solely with the native operating system's security APIs (`androidx.biometric.BiometricPrompt` on Android and `LocalAuthentication` / `LAContext` on iOS).
  - **Royal Spend NEVER accesses, collects, records, processes, transmits, or stores your fingerprint patterns, facial recognition scans, device PIN, pattern, or passcode.**
  - Biometric matching occurs entirely inside your device's hardware-isolated Secure Enclave or Trusted Execution Environment (TEE). The App only receives a binary cryptographic confirmation (`authenticated: true/false`) from the operating system.

### E. Device & Technical Telemetry
* **Device Characteristics:** Device manufacturer, hardware model, operating system version, and application build number (e.g., `1.0.0`).
* **Network Connectivity State:** We monitor network reachability (online, offline, cellular, Wi-Fi) purely on-device via local OS callbacks to intelligently pause or resume synchronization with Cloud Firestore.
* **Crash & Diagnostic Logs:** Standard diagnostic reports generated by Google Firebase Crashlytics / Google Play Console to detect fatal crashes, memory leaks, and performance regressions.

---

## 4. Google Play Data Safety Summary

In accordance with Google Play's Data Safety declaration requirements:

| Data Type | Collected? | Shared? | Purpose | Handling & Protection |
| :--- | :--- | :--- | :--- | :--- |
| **Name & Email Address** | Yes (Optional via login) | No | Account management, authentication | Encrypted in transit (TLS 1.3), user deletable |
| **Financial Info (Expenses, Budgets)** | Yes (User-entered) | No | App functionality, analytics, budgeting | Encrypted in transit & at rest, user deletable |
| **Travel & Itinerary Data** | Yes (User-entered) | No | App functionality, itinerary management | Encrypted in transit & at rest, user deletable |
| **Approximate / Precise Location** | Only user-pinned place coordinates | No | Interactive map route display | Encrypted in transit & at rest, user deletable |
| **Photos / Profile Images** | Yes (Optional avatar only) | No | Account profile personalization | Encrypted in transit & at rest, user deletable |
| **Biometric Information** | **NO** | **NO** | Not collected. Handled 100% by OS TEE | Never accessed, collected, or stored |
| **Device Identifiers / Ad IDs** | **NO** | **NO** | No advertising or tracking IDs used | Not collected |

---

## 5. Third-Party Services & Integrations

Royal Spend integrates strictly with enterprise infrastructure providers necessary for core application functionality:

| Third-Party Provider | Service Purpose | Privacy Documentation |
| :--- | :--- | :--- |
| **Google Firebase Authentication** | Secure token-based user authentication and identity management. | [Firebase Privacy & Security](https://firebase.google.com/support/privacy) |
| **Google Cloud Firestore** | Encrypted multi-device cloud database synchronization. | [Google Cloud Privacy](https://cloud.google.com/terms/cloud-privacy-notice) |
| **Google Firebase Storage** | Secure cloud storage for user-uploaded profile avatars. | [Firebase Storage Terms](https://firebase.google.com/terms/storage) |
| **Google Maps Platform** | Interactive map tile rendering and route coordinate display. | [Google Maps Privacy Policy](https://policies.google.com/privacy) |
| **Google Play Services** | Core Android runtime libraries, security patches, and distribution. | [Google Play Services Privacy](https://policies.google.com/privacy) |

> **IMPORTANT:** Royal Spend contains **NO Google AdMob, NO third-party advertising SDKs, NO tracking cookies, and NO marketing data aggregators**. We do not sell or monetize your personal or financial data.

---

## 6. Device Permissions & Purpose Justification

Royal Spend requests only permissions that are directly necessary to deliver specific features:

* **Photos / Media (`READ_MEDIA_IMAGES` / `NSPhotoLibraryUsageDescription`):** Required only if you voluntarily choose to select a custom profile avatar from your device photo library.
* **Biometrics (`USE_BIOMETRIC`, `USE_FINGERPRINT`, `NSFaceIDUsageDescription`):** Required only to authenticate you locally before unlocking the app when App Lock is turned ON.
* **Internet & Network (`INTERNET`, `ACCESS_NETWORK_STATE`):** Required to authenticate, sync encrypted data with Cloud Firestore, check network reachability, and stream Google Maps tiles.

You can modify or revoke any permission at any time through your device operating system settings (**Settings > Apps > Royal Spend > Permissions**).

---

## 7. Data Storage, Security & Encryption

We apply multi-layered technical and organizational security controls:

1. **Local SQLite Sandbox:** Your data is stored locally in a private SQLite database (`royal_spend.db`) residing in your operating system's protected application sandbox, inaccessible to other installed applications.
2. **Encryption in Transit:** All communications between Royal Spend and Google Firebase servers use Transport Layer Security (**HTTPS / TLS 1.3**).
3. **Encryption at Rest:** Data stored in Google Cloud Firestore is automatically encrypted at rest using 256-bit AES encryption.
4. **Per-User Access Isolation:** Cloud Firestore enforces strict security rules verifying that each authenticated user can only read, write, or delete documents inside their own isolated user collection (`/users/{uid}/*`).
5. **Zero Data Selling:** We strictly commit to **never selling, renting, licensing, or commercializing** your personal data, transaction records, or travel details to third parties or data brokers.

---

## 8. Data Retention & Account Deletion Policy

In compliance with **Google Play’s Account Deletion Policy**:

### A. Retention Period
We retain your account data and synchronized records only for as long as your account remains active or as needed to provide you with the App's services.

### B. In-App Data Clearing
You can reset or clear your local transaction ledgers and travel plans directly within the app settings (**Settings > Clear All Expenses**).

### C. Complete Account & Cloud Data Deletion (Web & Email Mechanism)
You have the absolute right to have your account, authentication record, profile avatar, and all associated cloud Firestore records permanently and irrevocably deleted:
* **How to Request:** Send an email to **[royalshubhampixellabs@gmail.com](mailto:royalshubhampixellabs@gmail.com)** with the subject line *"Delete My Royal Spend Account"*. Include your registered account email address.
* **Data Permanently Purged:** Upon verification, we will permanently purge:
  1. Your Firebase Authentication user account and credentials.
  2. All expense records, budgets, categories, and presets stored under `/users/{uid}/expenses` and `/users/{uid}/budgets`.
  3. All travel itineraries, waypoints, stays, transports, and splits stored under `/users/{uid}/trips`.
  4. Your profile avatar stored in Firebase Storage.
* **Turnaround Window:** All associated records will be permanently erased from our servers within **thirty (30) days** of receipt of your request.

---

## 9. Global Legal Compliance

### A. European Economic Area & UK (GDPR / UK GDPR)
If you reside in the EEA or the United Kingdom, you possess the following statutory rights under the General Data Protection Regulation:
* **Right of Access (Article 15):** Request confirmation and a copy of the personal data we hold about you.
* **Right to Rectification (Article 16):** Request correction of inaccurate or incomplete data.
* **Right to Erasure (Article 17):** Request permanent erasure of your personal data ("Right to be Forgotten").
* **Right to Data Portability (Article 20):** Export your financial statements and travel plans in standard formats (PDF, JSON/CSV).
* **Right to Restrict Processing (Article 18) & Right to Object (Article 21).**

### B. California Privacy Rights (CCPA / CPRA)
If you are a California resident, under the California Consumer Privacy Act:
* We do **not** sell or share your personal information for cross-context behavioral advertising.
* You have the right to request disclosure of categories and specific pieces of personal information collected.
* You have the right to request deletion of your personal data without receiving discriminatory treatment.

### C. India Digital Personal Data Protection Act (DPDP Act 2023)
For users in India:
* We process personal data based on explicit consent for the stated purpose of personal budgeting and travel planning.
* You possess the right to access, correction, erasure, and grievance redressal through our designated contact email.

---

## 10. Children’s Privacy

Royal Spend is designed for general audiences and is **not directed to children under the age of 13** (or under 16 in the EEA). We do not knowingly collect, solicit, or maintain personal information from children under these age thresholds. If we discover that a child has provided us with personal data, we will immediately delete that information from our servers. Parents or guardians who believe their child has submitted personal information may contact us at [royalshubhampixellabs@gmail.com](mailto:royalshubhampixellabs@gmail.com).

---

## 11. Changes to This Privacy Policy

We may update this Privacy Policy periodically to reflect enhancements in Royal Spend’s features, changes in legal obligations, or updates from platform providers. When updates are published:
* The **"Last Updated"** date at the top of this policy will be revised.
* Material changes will be communicated via an in-app notice or release note.
* Your continued use of Royal Spend following the posting of an updated policy signifies your acceptance of the revisions.

---

## 12. Contact & Grievance Redressal

If you have questions, feedback, security inquiries, or wish to exercise your data protection or deletion rights, please contact our Data Privacy Team:

* **Entity:** Royal Shubham Pixel Labs
* **Primary Privacy & Support Email:** [royalshubhampixellabs@gmail.com](mailto:royalshubhampixellabs@gmail.com)
* **Administrative Contact:** [subhamsoudeep@gmail.com](mailto:subhamsoudeep@gmail.com)

---

*Copyright © 2026 Royal Shubham Pixel Labs. All rights reserved.*
