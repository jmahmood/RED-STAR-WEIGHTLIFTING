# Red Star Weightlifting
Strength is measured, not imagined.

---

![Package](./package.png)
*Issued for distribution on Apple Watch and iPhone systems. Packaging may differ by region.*

---

## Purpose
Red Star Weightlifting is a privacy‑respecting, non‑commercial training log for weightlifters.
It is built to be utilitarian, fast, and durable: no ads, no analytics, and no external data calls
other than user‑initiated links. Your data stays on your devices, and export is a first‑class feature.

The iPhone companion exists to view, analyze, and export what the watch records. There is no lock‑in.

---

## In‑Universe Briefing
In this world, computing is scarce and power is rationed.  
Machines are judged not by spectacle, but by how little they waste.

Red Star Weightlifting is a small tool in that tradition:

- Minimal UI. No distractions. Avoid vanity that drains the battery.
- Data is append‑only and human‑readable, because history must be durable.
- Every action has a CLI equivalent in spirit, for those without access to a handset.
- To carry an iPhone implies responsibility; to carry a watch implies readiness.

> **MINISTRY OF STRENGTH — STAMP OF APPROVAL**  
> *“Serve the set. Record the truth. Waste nothing.”*

---

## Features
- **Record lifts on wrist**: fast Apple Watch logging with plan‑driven workouts.
- **Review progress**: sessions, exercise history, and PR insights on iPhone.
- **Plan sessions**: import/maintain a workout plan (JSON-based schema v0.4); the watch rotates days automatically.
- **Export without friction**: one‑tap CSV export to phone, and file‑based backups.
- **Offline‑first**: no network dependencies for core functionality.
- **Widgets & complications**: “Next Up” watch complication and iOS widgets.

---

## Data & Privacy
- **No external telemetry**. No ads. No trackers.
- **Open, Documented JSON-Based Workout Plan Format**
- **Single append‑only CSV** is the source of truth.
- **Write‑ahead log (WAL)** ensures durability on every save.
- **Exports are yours**: the app is designed around easy extraction and reuse of your data.

---

## Getting Started (Developers)

You may avoid the *Apple Tax* and compromise by building the application for yourself.

1. Open `WEIGHTLIFTING.xcodeproj` in Xcode.
2. Build and run:
   - `WEIGHTLIFTING Watch App` (watchOS target)
   - `WEIGHTLIFTING` (iOS companion target)
3. Optional: add complications/widgets.

We cannot offer any support for connecting to the Apple Watch, nor for targeting older versions of the iPhone and Apple Watch due to challenges with Xcode.  We are currently targeting iOS 16 and watchOS 11.6.

---

## Licensing
This project is **dual‑licensed**:

1. **Commercial license** for distribution through the Apple App Store.  
2. **GNU General Public License v3.0 (GPL‑3.0)** for open‑source use.

We do not intend on distributing this under Commercial license other than through the Apple App Store.  If well-supported application stores are available without the need for this compromise, we reserve to drop our commercial license in the future.

If you require different licensing for societally beneficial usage, please reach out to Jawaad Mahmood by email.

---

## Contributing
Contributions are welcome and subject to the rules laid out in the `CONTRIBUTING.md` file.  

To keep the dual‑license model viable, **all contributions must assign copyright**
to the project author (Jawaad Mahmood). This allows future licensing changes if needed; please keep this in mind before making any PRs.

By submitting a pull request you agree that:

- You wrote the contribution yourself (or have the right to contribute it).
- You assign its copyright to Jawaad Mahmood.
- Your contribution may be redistributed under either license above.

If you prefer not to assign copyright, please open an issue instead.  Profanity and impoliteness will be thoroughly ignored and deleted with no attention being placed.

---

## Non‑Goals
Red Star Weightlifting aims to be a sharp tool, not a social platform.
We intentionally avoid:
- Accounts, feeds, followers, or any cloud‑first features.
- Monetization, ads, or behavioral analytics.
- Heavy visualizations that trade battery for aesthetics.

---

## Credits
Red Star Weightlifting is authored and maintained by Jawaad Mahmood with a lot of help from Codex and Claude.

---

We’re leveraging vibes, not preaching. The story exists to explain our engineering goals:
brutalist efficiency, respect for the lifter, and zero compromise on privacy. The fictional framing is aesthetic and explanatory; it is not associated with any real political organization or ideology.
