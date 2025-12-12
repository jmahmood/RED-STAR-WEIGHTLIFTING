# Contributing to Red Star Weightlifting

**"Serve the set. Record the truth. Waste nothing."**

Thank you for your interest in contributing. This project is built on specific principles: data durability, privacy, and zero compromise on performance.

To maintain the project's dual-license structure (App Store distribution + GPLv3 Open Source), we require strict adherence to the protocols below.

---

## 1. Legal & Copyright Assignment

**This is the most important section. Please read carefully.**

Red Star Weightlifting is **dual-licensed**:
1.  **Commercial License:** For distribution via the Apple App Store.
2.  **GNU GPLv3:** For open-source usage and auditing.

To keep this model legal and viable, **Jawaad Mahmood** must hold the copyright to the entire codebase. This allows the project owner to change licenses or distribute the binary commercially without needing to ask every contributor for permission retroactively.

### The Agreement
By submitting a Pull Request (PR) to this repository, you agree to the following terms:

1.  **Originality:** You represent that the code you are submitting is your own original work and that you have the right to contribute it.
2.  **Assignment:** You assign all copyright and related rights of your contribution to **Jawaad Mahmood**.
3.  **Relicensing:** You acknowledge that your contribution may be distributed under the commercial license (App Store), the GPLv3, or any future license selected by the project owner.

**If you cannot or do not wish to assign copyright:**
Do not submit a Pull Request. Instead, please open an **Issue** describing your proposed changes or logic. We can discuss the idea, and the maintainer may implement a similar solution independently.

---

## 2. Engineering Standards

The aesthetic of this app is "brutalist efficiency." Features that compromise battery life or privacy for the sake of vanity will be rejected.

### General Guidelines
* **Swift Only:** We target modern Swift.
* **No External Dependencies:** We avoid CocoaPods/SPM packages unless absolutely necessary. The goal is to reduce the "supply chain" risk.
* **No Telemetry:** Do not add analytics, crash reporting SDKs, or "phone home" logic.
* **Offline First:** All features must function without an internet connection.

### UI/UX Philosophy
* **Watch First:** The Apple Watch app is the primary input device. It must be fast and legible under physical stress.
* **High Contrast:** Use system fonts and high-contrast colors (Red/Black/White).
* **No Animations:** Avoid gratuitous animations that delay interaction or drain battery.

---

## 3. Data Integrity

The `v0.31` CSV schema and the Write-Ahead Log (WAL) are the spine of this application.
* **Do not modify the CSV schema** without extensive discussion in an Issue first.
* **Backward Compatibility:** Users must always be able to import their old history.

---

## 4. Development Setup

1.  Ensure you have the latest stable version of **Xcode**.
2.  Open `WEIGHTLIFTING.xcodeproj`.
3.  Select the `WEIGHTLIFTING Watch App` target for watchOS development.
4.  Select the `WEIGHTLIFTING` target for iOS companion development.

*Note: We strictly target iOS 16+ and watchOS 11.6+.*

---

## 5. Submitting a Pull Request

1.  **Scope:** Keep PRs small and focused on a single issue.
2.  **Description:** Clearly explain *why* this change is needed.
3.  **Certification:** In your PR description, please include the following line to confirm your agreement to Section 1:
    > "I certify that I own this code and assign its copyright to Jawaad Mahmood."

---

*End of Briefing.*