Here are the requirements for an app I'm working on.

Please prepare the first sprint.  It should produce a MVP.

# Weightlifting Watch App — Developer Requirements (v1)

**Target**: Apple Watch Series 6 running the latest watchOS (watchOS 11 at time of writing).
**Primary goal**: Fast, reliable on-wrist logging for weight training using an **append‑only global CSV** (schema v0.3 provided below), with durable saves, minimal UI, and plan-driven navigation.
**Non‑goals (v1)**: In‑app timers, full text entry, analytics, phone UI beyond export, editing historical rows on watch.

---

## 0. Non‑Negotiable Invariants

* **CSV schema** is fixed (see §7.1). The app must conform exactly; **no new columns**.
* **Append‑only global CSV**: a single file containing all-time log; header written only if empty.
* **Durability**: Every SAVE is fsynced to a **session WAL** immediately. Global CSV append occurs after a **5s Undo Grace**. Undo never writes to global.
* **Negative weights allowed** (e.g., assisted bodyweight). Units are as authored in plan; no auto-conversion.
* **No timed sets**: any plan item with `time_sec` is hidden; surface a one-line banner once per session: *“Timed sets not supported (skipped).”*
* **Supersets** handled purely by **deck ordering** (ABAB); “zero rest” is a **visual tint/icon** only.
* **Exercise replacement palette** is restricted to the segment’s `alt_group`.
* **Default replacement scope** is **Apply to remaining sets** for the current exercise in the current workout; a secondary path allows "This set only".

---

## 1. Architecture Overview

* **App targets**: watchOS app (SwiftUI), optional minimal iOS companion for export/share only.
* **Storage**: Files in app container on watch. WAL per active session; a single global CSV. Optional read-only index files for fast “Prev 2” lookups.
* **Data sources**: Plan JSON v0.3 (subset supported), Global CSV, Session WAL.
* **Comms**: WatchConnectivity for one-tap “Send to Phone”. Optional Wi‑Fi export mode may be deferred.

### Files & Paths (suggested)

```
/Library/Application Support/WeightWatch/
  Global/all_time.csv                 # append-only, header once
  Global/index_last_by_ex.json        # compact index: ex_code -> [last2 rows]
  Sessions/<session_id>.wal.csv       # WAL (append-only; includes tombstones)
  Sessions/<session_id>.meta.json     # cursor, deck hash, last save time, etc.
```

---

## 2. Session Lifecycle & Rotation

* **Rotation source**: ring over `plan.schedule[]` (Day1→Day2→…→DayN→Day1).
* **On app open**:

  1. If a **today** WAL exists and isn’t done, **auto-resume** it.
  2. Else start **next day** in rotation.
  3. Old unfinished sessions remain in History (rows committed to global based on grace rules).
* **Cross-midnight grace**: if `now - lastSave < 4h`, still considered the same “today” for auto-resume.

---

## 3. Deck Materialization (from Plan JSON v0.3)

* **Supported segment types**: `straight`, `scheme`, `superset`.
  **Ignored**: `complex`, `circuit`, `percentage`, `amrap` (except tag derivation), `choose` (unless flattened upstream).
  If unsupported types are present, ignore them silently.
* **Algorithm**:

  * For each `day.segments` (1-based `segment_id`):

    * `straight`: push `sets` copies of the exercise with reps range; `set_num` increments as completed.
    * `scheme`: expand each entry in `sets[]`; if an entry has `sets: N`, push N copies.
    * `superset`: for `rounds: R`, push AB pairs sequentially: `A1,B1,A2,B2,…`.
  * Tag entries with metadata for UI: zero-rest (tint/icon), dropset badge if last set has `intensifier.kind=="dropset"`.
* **Timed sets (`time_sec`)**: do not push into deck; set a session flag to render the banner once.

---

## 4. Primary UI & Interactions

### 4.1 Set Card (single-screen)

```
┌──────────────────────────────────────────────┐
│ •  ○  •  •  •  •  •   (+N)                  │  ← remaining dots; hollow = current
│ <Exercise Name>        Set X/Y              │  ← tap → Spinner (alt_group only)
│ Weight   [ −  85 lb  + ]                    │  ← crown/taps; allow negatives
│ Reps     [ −   10     + ]                   │
│ Effort   [ EASY • EXPECTED • HARD ]         │  ← maps to 1 / 3 / 5 internally
│ [ WORKOUT ]                     [ SAVE ]    │
│ Prev: 90×8  (YYYY-MM-DD)                    │  ← two most recent from *global index*
│ Prev: 85×10 (YYYY-MM-DD)                    │
└──────────────────────────────────────────────┘
```

* **Gestures**: Swipe L/R to move among **remaining** sets only.
* **Dots**: show first 12; if more, show `(+N)` counter. On SAVE, the current dot **puffs** and disappears (150 ms spring; reduce-motion → fade-only). Next dot becomes hollow.
* **Zero-rest**: subtle background tint or small footer icon; no timers.
* **Badges**: tiny “dropset” badge on the relevant card if authored.

### 4.2 SAVE & Undo

* **SAVE tap**:

  1. Append full CSV row to **WAL**; `fsync` immediately.
  2. Show “Saved — Undo (5s)” chip; puff dot; auto-advance cursor.
  3. After **5s** (fixed constant), append the same row to **global CSV**; `fsync`.
* **UNDO (only within 5s)**:

  * Append **tombstone** to WAL: set `tags="undo_for:<row_seq>"`, set `effort_1to5=0`.
  * Cancel the pending global append. Restore dot/card/cursor.
* **Crash/Backgrounding**: On launch, replay WAL; commit any row whose grace has elapsed; drop rows tombstoned in WAL; re-arm grace for pending rows.
* **1 Hz guard**: Ensure `(session_id,date,time)` is unique by delaying global append to the next second if needed (UI unaffected).

### 4.3 Exercise Spinner (replacement)

* Entry: tap exercise name on Set Card, or long-press for explicit dialog.
* **Palette**: members of the segment’s `alt_group` plus the current exercise.
* **Layout**:

```
┌──────── Switch Exercise ────────┐
│ [<] Current or Alt [>]          │  ← Crown cycles options
│                                  │
│                  [ APPLY ]       │  ← Primary (default)
│  More options                    │  ← text button
└──────────────────────────────────┘
```

* **APPLY**: replace **all remaining instances** of the current exercise in **this workout’s deck**; close sheet; success haptic + toast.
* **More options → This set only**: replace just the current card. Rare path; smaller affordance.
* **Fast path**: focus exercise title → Crown change → press **SAVE** = equivalent to **APPLY**.

### 4.4 WORKOUT Menu

```
┌──────────── WORKOUT ────────────┐
│  • Switch Workout               │  → Replace deck | Merge deck (Replace default)
│  • Add exercises to this workout│  → Quick add (inserts next; logs adlib=1)
│  ————————————————            │
│  Timed sets not supported today │  (if any were detected in plan)
└─────────────────────────────────┘
```

* **Switch Workout**: immediately loads chosen workout. All prior saves are already durable (WAL + eventual global commit).
* **Add exercises**: minimal picker (Recent/Favorites/Search later); default 1 set; units from plan; logs `adlib=1`.

### 4.5 Remaining Sets Drawer

* Edge-swipe or side button (if desired) opens vertical list of **remaining** sets grouped by exercise; tap to jump.

### 4.6 Complications (initial)

* **Graphic Rectangular**: Title `Next Up`; body `<name> <weight×reps>`; footer `••• +N`.
* **Graphic Corner**: `Next: <abbr name> <weight×reps>`.
* Tap → deep-link to active set (`session_id` + deck index). Always show details (no privacy mode).

---

## 5. Data: Sources & Indexing

* **Plan JSON v0.3**: subset required (`straight`, `scheme`, `superset`, `alt_group`, `intensifier`). Units (`lb|kg|bw`) come from plan; display & log as-is.
* **Global CSV index** (read-only): `ex_code -> [last two completions]` for quick “Prev” rendering. Update this index only after the row commits to global (post-grace). Do **not** consult WAL for “Prev”.
* **Tags**: auto-append `amrap` for AMRAP sets and `dropset` where `intensifier.kind=="dropset"`.

---

## 6. Durability & Export

* **WAL fsync on each SAVE/UNDO**; WAL replays on startup to finalize commits to global.
* **Global CSV**: header-once; atomic append (write temp, `fsync`, `rename`).
* **Export**: one-tap “Send to Phone” via WatchConnectivity (transferFile). Optional Wi‑Fi export can be deferred to v1.1.
* **Storage guard**: if free space < 10 MB, block new sessions; prompt to export.

---

## 7. CSV Contract (v0.3) — Population Rules

### 7.1 Header (fixed order)

```
session_id,date,time,plan_name,day_label,segment_id,superset_id,ex_code,adlib,set_num,reps,time_sec,weight,unit,is_warmup,rpe,rir,tempo,rest_sec,effort_1to5,tags,notes,pr_types
```

### 7.2 Field population

* `session_id`: generated at session start (local timestamp format like `YYYY-MM-DDTHH-mm-ss-###`).
* `date`/`time`: local at SAVE; 1‑Hz guarded (delay commit if needed).
* `plan_name`/`day_label`: from active plan day; empty if freestyling.
* `segment_id`: 1-based position in `day.segments`.
* `superset_id`: empty unless authored under `superset` (mirror plan label/code).
* `ex_code`: resolved code after replacement.
* `adlib`: `1` for items added via *Add exercises to this workout*; `0` otherwise.
* `set_num`: 1-based within the **segment/exercise** as executed.
* `reps`: user-entered; integer ≥ 0.
* `time_sec`: **empty** (no timed sets in v1).
* `weight`: float; may be **negative** for assistance; empty if pure `bw` and you choose not to encode added/assisted load.
* `unit`: `lb|kg|bw` per plan/runtime.
* `is_warmup`: `1` for plan-generated warmups else `0`.
* `rpe`/`rir`: optional; if both present, RPE takes precedence (UI may omit entry).
* `tempo`, `rest_sec`: optional/empty; rest ignored in v1.
* `effort_1to5`: **1=EASY, 3=EXPECTED, 5=HARD**; UI never shows numbers.
* `tags`: `;`-separated; auto-append `amrap` / `dropset` if authored.
* `notes`, `pr_types`: optional; typically empty from watch.

### 7.3 Examples

```
2025-10-28T18-05-00-001,2025-10-28,18:12:09,Essentials: Block 1 (Weeks 1-4),Upper A,3,,PULLUP.BW.2GRIP,0,1,8,,-20,lb,0,,,"",,3,,,
...,ROW.CBL.SEAT,0,2,10,,70,lb,0,,,"",,3,dropset,,
```

---

## 8. Visual & Motion Specs

* **Dots**: 12 visible + `(+N)` overflow; current is hollow `○`; completed puff animation ~150 ms (spring response 0.2, damping ~0.75). Reduce Motion → fade-only.
* **Haptics**: light tick on Crown focus change; success tick on SAVE at ~80 ms; double tick on UNDO.
* **Typography**: Large controls, Dynamic Type compliant, ensure 44×44 pt touch targets.
* **Color cues**: zero-rest tint on card background; dropset badge; AMRAP badge (if applicable).

---

## 9. Accessibility & Resilience

* High contrast; VoiceOver labels for buttons, spinner, and dot row (“12 sets remaining; current set 3 of 14”).
* All critical actions reachable by thumb + Crown; no reliance on tiny targets.
* Recover gracefully from process death: WAL replay finalizes commits.

---

## 10. Constants & Config

* `UndoGraceSeconds = 5` (fixed)
* `CrossMidnightGrace = 4 * 3600`
* `DotsMaxInline = 12`
* `DotPuffDuration = 0.15`
* `SaveWriteMinInterval = 1s` (global commit)

---

## 11. Open Integration Points (handled upstream or later)

* **Parsing/grammar** for voice/search is upstream; this app consumes resolved `ex_code`, `reps`, `weight`, `unit`.
* **Favorites/Recents** for *Add exercises* can be populated from the global CSV index.
* **Wi‑Fi export mode** (Bonjour + ephemeral PIN) can be added in v1.1.

---

## 12. QA Checklist

* [ ] SAVE → WAL fsync always; airplane mode, 1% battery, and crash scenarios retain rows.
* [ ] UNDO within 5s removes pending global commit; dot restored; WAL has tombstone.
* [ ] After 5s, row appears in **global CSV** and **Prev** history (index refresh).
* [ ] Spinner APPLY replaces **all remaining** instances; “This set only” works and is visually deprioritized.
* [ ] Switch Workout preserves prior saves; loads new deck; dots/prev/targets update.
* [ ] Timed sets skipped; banner shown once; no CSV rows emitted.
* [ ] Negative weights accepted and displayed.
* [ ] Complication updates on SAVE and deck changes; deep-link lands on the active set.
* [ ] Dedupe: `(session_id,date,time)` unique (≥1 Hz guard) to avoid duplicate lines.

---

## 13. Minimal Reducer Pseudocode

```pseudo
onSave(row):
  wal.append(row); wal.fsync()
  scheduleGlobalCommit(row, t+5s)
  ui.puffDot(); ui.advanceCursor()

onUndo():
  wal.append(tombstone for last wal row)
  cancelScheduledGlobalCommit(lastRow)
  ui.restoreDotAndCursor()

onAppLaunch():
  for each wal in Sessions:
    for each entry in wal in order:
      if entry is tombstone: mark target as canceled
      else if entry not canceled and entry.graceExpired():
        global.append(entry)
    fsync(global)

global.append(entry):
  if firstWrite && global.empty(): writeHeader()
  ensureUniqueSecond(entry.date, entry.time)
  writeLine(entry); fsync()
```

---

### End of v1 Requirements