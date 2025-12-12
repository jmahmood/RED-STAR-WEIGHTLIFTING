# RED ✪ STAR Weightlifting
Strength is measured, not imagined.

---

## Purpose
RED ✪ STAR Weightlifting is a privacy‑respecting, non‑commercial training log for weightlifters.
It is built to be utilitarian, fast, and durable: no ads, no analytics, and no external data calls
other than user‑initiated links. Your data stays on your devices, and export is a first‑class feature.

The Apple Watch application is the primary instrument.
The iPhone companion functions as a dock: for review, analysis, backup, and export of what the watch records.
All essential training actions are possible from the watch alone.

---

## In‑Universe Briefing
In this world, computing is scarce and power is rationed.  
Machines are judged not by spectacle, but by how little they waste.

RED ✪ STAR Weightlifting is a small tool in that tradition:

- Minimal UI. No distractions. Avoid vanity that drains the battery.
- Data is append‑only and human‑readable, because history must be durable.
- Every action has a CLI equivalent. A Linux CLI implementation exists for all core operations.
- To carry an iPhone implies responsibility; to carry a watch implies readiness.

> **MINISTRY OF STRENGTH — STAMP OF APPROVAL**  
> *“Serve the set. Record the truth. Waste nothing.”*

*We’re leveraging vibes, not preaching. The story exists to explain our engineering goals: brutalist efficiency, respect for the lifter, and zero compromise on privacy. The framing is fictional and explanatory, not affiliated with any real political organization.*

---

## Execution Model

RED ✪ STAR Weightlifting is designed around a single constraint:

**The workout must be executable with only a watch.**

- The Apple Watch records all training data and maintains the authoritative log.
- The iPhone does not issue commands to the watch during a session.
- The phone exists to inspect, aggregate, export, and archive data already recorded.

If the phone is absent, powered down, or disconnected, training continues uninterrupted.

---

## Features
- **Record lifts on wrist**: fast Apple Watch logging with plan‑driven workouts.
- **Dock & review on phone** sessions, exercise history, and PR insights on iPhone.
- **Plan sessions**: import/maintain a PLANSPEC workout plan (JSON-based schema, v0.4); the watch rotates days automatically.
- **Export without friction**: one‑tap Logbook CSV export to phone, and file‑based backups.
- **Offline‑first**: no network dependencies for core functionality.
- **Widgets & complications**: “Next Up” watch complication and iOS widgets.

---

## Data & Privacy
- **No external telemetry**. No ads. No trackers.
- **Open, Documented PLANSPEC JSON-Based Workout Plan Format** PLANSPEC refers to the documented JSON workout-plan specification used by the application (currently v0.4).
- **Single append‑only Logbook CSV** is the source of truth.
- **Write‑ahead log (WAL)** ensures durability on every save.
- **Exports are yours**: the app is designed around easy extraction and reuse of your data.

---

## Getting Started (Developers)

You may avoid the *Apple Tax* and any compromise by building the application for yourself.

1. Open `WEIGHTLIFTING.xcodeproj` in Xcode.
2. Build and run:
   - `WEIGHTLIFTING Watch App` (watchOS target)
   - `WEIGHTLIFTING` (iOS companion target)
3. Optional: add complications/widgets.

You will need to modify the Bundle Identifier and related signing details to run the app locally (sorry).

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
RED ✪ STAR Weightlifting aims to be a sharp tool, not a social platform.
We intentionally avoid:
- Accounts, feeds, followers, or any cloud‑first features.
- Monetization, ads, or behavioral analytics.
- Heavy visualizations that trade battery for aesthetics.

---

## Credits
RED ✪ STAR Weightlifting is authored and maintained by Jawaad Mahmood with assistance from Codex and Claude.

---

![Package](./package.png)
*Issued for distribution on Apple Watch and iPhone systems. Packaging may differ by region.*

--

## Glossary

**Apple Watch (Primary Instrument)**
The authoritative execution environment for training. All workouts can be run, logged, and completed using the watch alone.  The Apple Watch is self-sufficient after the workout has been loaded.

**iPhone (Dock)**
A secondary environment used for inspection, aggregation, backup, export, and analysis of data recorded by the watch. Not required for executing workouts.

**Logbook CSV**
The single append-only CSV file that serves as the source of truth for all recorded training data.

**WAL (Write-Ahead Log)**
A durability mechanism that ensures each recorded action is safely persisted before being committed to the Logbook CSV.

**PLANSPEC**
The documented JSON-based workout plan specification used by the application (currently v0.4). Defines exercises, structure, progression, and execution rules.

**Plan Rotation**
The automatic advancement of training days on the watch based on completed sessions, without manual scheduling.

**CLI (Command-Line Interface)**
A Linux-based command-line implementation that mirrors all core application operations for plan management and log manipulation.
