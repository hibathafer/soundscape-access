---
doc: checklist
status: approved
---
<!-- `status` is the progress state every skill reads. Write `draft` when you first save this file,
     and change it to `approved` when the learner clearly approves the displayed plan ("looks good" counts).
     Do not request a second sign-off. Never skip the draft save —
     an unsaved draft dies with the conversation. -->

# Build Checklist

Build mode: **fast with learn explanations** — learner chose a hybrid: fast execution, short plain-language explanation after each slice, hands-on exploration at the checkpoints (after slices 3 and 6).

## Slices

- [x] **1. The app runs on your phone — permission, Start/Stop, live session**
  Becomes usable: Installed on the Android phone: one ~~dark~~ light screen with a large Start/Stop button and a vibration toggle; first start shows the gentle mic line then the system dialog (denied → friendly message + settings route); Start shows the "Working now" toast and the mic genuinely captures (session active); vibration toggle buzzes on captured sound events; Stop ends everything. Bootstrap (project scaffold, dependencies, config) happens inside this slice. *(Canvas revised to light 2026-10-22 — see Revisions.)*
  Why now: It is the whole journey's spine (PRD steps 1–4) plus the foundation every later slice lands on; nothing else can be verified without a running app.
  PRD ref: `prd.md > The Core Journey` (steps 1–4), `prd.md > Starting and stopping`, `prd.md > Vibration (manual, simple)`, `prd.md > States and Boundaries` (First use, Permission denied)
  Spec ref: `spec.md > File Structure`, `spec.md > Where It Runs and How Someone Tries It`, `spec.md > Components` (App Shell, Audio Capture Service, Session Controller, Vibration Service)
  Build: Create the Flutter project per the spec's file structure; ~~dark~~ light Material 3 theme; the single screen with Start/Stop + vibration toggle; permission flow (gentle explanation → system dialog → denied message); session controller with start/stop/toast; mic capture stream with a simple level threshold emitting events; vibration on events while the toggle is on; `VIBRATE`/`RECORD_AUDIO` permissions in the manifest.
  Verify (mechanical): `flutter analyze` → no issues; `flutter build apk --debug` → success; `adb install` + launch on the connected Xiaomi 12T Pro; logcat shows the mic session starting after permission grant.
  Learner check: Open the app on your phone, grant the mic permission, press Start, see the "Working now" toast, turn the vibration toggle on and make a sound — feel a buzz; press Stop and confirm it all goes quiet.
  Commit: `Add app shell, permission flow, and live capture session`

- [x] **2. Direction probe on the real device (critical risk)**
  Becomes usable: A debug readout while the session runs shows live input levels per microphone source, so we can see on screen what the phone actually hears. Runnable evidence for or against the direction approach. **Result: answered — four rounds proved no directional signal is obtainable on this device; the kernel was revised by learner decision (see Revisions). The probe stayed in the app as research tooling.**
  Why now: This is the spec's recorded "one useful unknown" — two-mic direction on the Xiaomi 12T Pro. Risk-first: if it fails, we revise the plan while almost nothing is built. The spec explicitly makes this build step 1 of the direction work.
  PRD ref: `prd.md > Open Questions` (direction — resolved)
  Spec ref: `spec.md > Decisions and Open Issues` (One useful unknown + OUTCOME), `spec.md > Important Failure Modes` (Direction unusable)
  Build: Kotlin bridge exposing Android `AudioRecord` source levels to Dart; a temporary debug panel printing/plotting per-source levels while the session runs; test protocol: play a sound from a known side, observe the difference. Record the outcome in `spec.md > Decisions and Open Issues`. Rounds 2–4 widened the search (more sources, stereo, device selection, source × device matrix, phase-marker protocol) after the learner asked for honest retries.
  Verify (mechanical): `flutter analyze` → no issues; run on device; logcat/debug panel prints numeric levels for the available mic sources while a test sound plays — numbers must visibly differ between sides, or the failure is honestly captured and escalated as a plan revision. **Done: failure captured with 4 rounds of timestamped evidence (`probe_log*.txt`).**
  Learner check: With the debug panel open, play the horn sample from above/below (and left/right if available) and read the numbers with me — do they move apart when the side changes? **Done across 4 learner-run protocols.**
  Commit: `Add two-mic direction probe with on-device readout`, `Add device-selection direction probe round 3 (slice 2, decisive)`

- [x] **3. The kernel ignites — the sound pulse (visual vocabulary)**
  Becomes usable: With the session running, every real sound ignites the pulse: brightness/size follow the sound's strength, color follows loudness (red very loud / orange moderate), a sudden sound produces a sharp fast flash while a gradual one fades in softly, a repeating sound (knocking, beeps) re-strikes the pulse with each wave while a continuous sound holds one sustained pulse, and everything fades back to calm when the sound stops. The distinctive thing about this product now exists on screen — honestly, with no direction claim.
  Why now: The unique kernel comes early, not last (`scope.md > The Unique Kernel`); slices 1–2 feed it everything it needs (level stream + the documented decision to describe *behavior*, not direction), and seeing it live is what early learner feedback should shape.
  PRD ref: `prd.md > Sound pulse (the visual vocabulary)`, `prd.md > Look and Feel` (color semantics)
  Spec ref: `spec.md > Components` (Visual Feedback — Pulse + Bubbles, Sound Behavior Analyzer), `spec.md > Look and Feel`
  Build: `lib/analyze/behavior.dart` — pure-Dart analyzer over the level stream: onset classification (rise rate), repetition detection (peak intervals), sustain/decay envelope; unit tests with synthetic streams. `lib/ui/flash.dart` — pulse renderer (strength→brightness/size, loudness→color, onset→sharpness, rhythm→wave, fade-out). Wire session events to it.
  Verify (mechanical): `flutter analyze` → no issues; `flutter test` → analyzer tests pass (sudden vs gradual streams, repeated peaks vs sustained, decay); build + install on device. **Done: analyze clean, 10/10 tests pass, installed + running on the device.**
  Learner check: **Done (2026-10-20, partial by learner's call): "consider it successful" — the flash works.** Her review note applied: the pulse was redrawn from defined circles to **soft blurred mist** (a cloud of lobes + outward wave — "خفيف مثل ضباب... مو شكل معين وواضح"); reinstalled. Pending her answer next visit: loud-sound tests (she could not make loud sounds on the day) — rhythm-under-knocks, red/orange color feel.
  Commit: `Add sound pulse kernel with behavior analyzer`

- [x] **4. Sounds get names — YAMNet classification and bubbles**
  Becomes usable: Recognized sounds show their swipeable icon ~~bubble~~ artwork (cars, speech, door, alarm, birds); unclassifiable sounds show the neutral "?" bubble; two sounds at once show two bubbles; the classifier's five categories are the only ones shown. Bundled labeled samples make every demo repeatable on demand. **Shipped 2026-10-22 in `eddfa6a` + `9f6d4ac`: model + labels bundled, index-set mapping, threshold → unknown, swipe-to-dismiss artwork, 5 labeled `.wav` samples.**
  Why now: It completes the kernel's second half ("what is it" beside "where is it") and turns slices 1–3 from noise-reactive into sound-identifying — the PRD's core value.
  PRD ref: `prd.md > Sound capture and classification (session-based)`, `prd.md > Unknown sounds`, `prd.md > Simultaneous sounds`, `prd.md > Sound-type bubbles`
  Spec ref: `spec.md > Components` (Sound Classifier), `spec.md > External Services and Dependencies` (YAMNet asset), `spec.md > Data Model`
  Build: Bundle `yamnet.tflite` + labels (resolve availability per the spec's failure mode); classifier wrapper (slice → scores → five categories + threshold → unknown); bubble widget (artwork per category, neutral "?" for unknown, swipe-down dismiss); event merging for simultaneous sounds; add labeled demo samples under `assets/samples/`.
  Verify (mechanical): `flutter analyze` → no issues; `flutter test` → category mapping + threshold → unknown tests pass; model file present in built assets; play the horn sample on device → logcat shows category "cars" + confidence; an unclassifiable sound → "unknown". **Done (2026-10-22): analyze clean, category tests pass, model bundled, 31/31 tests green. On-device sample playback still to be walked with the learner.**
  Learner check: Run the session, play each bundled sample — the right icon appears; swipe one away; try two sounds at once; play something odd and confirm the neutral "?" appears without breaking anything. **Pending — to be walked together.**
  Commit: `Move to a light, simpler UI; ship the classifier; document honestly`, `Replace the button-like bubble with plain sound artwork`

- [ ] **5. Leaving the app keeps it listening (with the approved fallback)**
  Becomes usable: After Start, the user goes to the home screen / other apps and capture genuinely continues (Android foreground service, type microphone); if the phone refuses or kills it, the documented fallback (session with the app in front) applies — either way the PRD's "must not obstruct phone use" intent is honestly served.
  Why now: It is the last risky platform behavior; everything visual already works, so a fallback here still leaves a demonstrable product.
  PRD ref: `prd.md > Product Decisions > Session must not obstruct phone use`, `prd.md > States and Boundaries` (Leaving the app), `prd.md > Open Questions`
  Spec ref: `spec.md > Components` (Session Controller), `spec.md > Where It Runs and How Someone Tries It` (Xiaomi setup notes), `spec.md > Important Failure Modes` (Background killed)
  Build: Kotlin foreground service with `FOREGROUND_SERVICE_MICROPHONE` + service type declared; start it while the app is foregrounded on Start; stop on Stop; graceful detection of service death → fall back to foreground session with a brief friendly note; document Autostart/battery-exemption steps for MIUI/HyperOS.
  Verify (mechanical): `flutter analyze` → no issues; build + install; start session → press Home → `adb logcat` shows the service running and mic frames still arriving while backgrounded; force-stop the service → app detects it and keeps a foreground session without crashing.
  Learner check: Start the session, press Home, play a sound — flash still works when you return / vibration still buzzes; if the phone killed it, confirm the app told you plainly and still works in front.
  Commit: `Add background session service with foreground fallback`

- [ ] **6. Demo-ready integration — full journey, README, repo hygiene**
  Becomes usable: The complete PRD core journey runs top to bottom on the phone (open → permission → start → leave/return → flash+icons+unknown+two sounds → stop), with factual README run/setup instructions and placeholder env docs (none needed — no keys) so a stranger could install the APK and try it.
  Why now: The demo video and the public repository are the submission; this slice makes the whole thing recordable and openable by others, and it is the last chance to catch integration gaps before the final review.
  PRD ref: `prd.md > What We're Building`, `prd.md > The Core Journey` (end to end)
  Spec ref: `spec.md > Where It Runs and How Someone Tries It`, `spec.md > File Structure`
  Build: Walk the full journey fixing integration gaps; confirm Look and Feel matches the spec (~~dark~~ light, warm, large type, color semantics); write `README.md` (what it is, how to build/run, Xiaomi setup notes, sample sounds, no secrets); confirm `.gitignore` covers plan docs' private file and credentials; tidy debug affordances (keep the probe available but out of the demo path).
  Verify (mechanical): `flutter analyze` → no issues; `flutter test` → full suite passes; `flutter build apk --debug` → success; `adb install` + launch; README exists and commands in it match reality (run them).
  Learner check: Do the full run exactly as the README says, from install to Stop, and tell me anything that felt off — this is the version we record.
  Commit: `Make the demo journey ready with README and repo hygiene`

## Hands-on Checkpoints

- [ ] Early usable behavior explored — after slice 3 (the mist pulse is live; **partially done 2026-10-20**: learner confirmed the flash works and reviewed the shape → mist redraw applied; loud-sound/rhythm answers deferred to her next visit)
- [ ] Final kick-the-tires exploration and feedback completed — after slice 6

## Final Review

- [ ] Final review complete — feedback resolved and learner confirms ready to ship

## Code Tour and App Map

- [ ] Learning activity complete — guided route, focused alternative, prior practice connected, or brief recap
- [ ] Optional edit and transfer reflection addressed — offered/declined/already covered/not applicable as appropriate
- [ ] `devpost/app-map.html` generated from finished code, checked, and shown, including a project-grounded practice to reuse

Activity and evidence: [what actually happened; real document/test/code references; unfinished work if interrupted]
Route and stops: [actual paths and symbols; guided stops completed, or reference-only route]
Edit outcome: [tried/kept/reverted/declined/not applicable; verification if changed]
Reflection: [offered/answered/declined/already covered — personal answer belongs only in the ignored profile]
Activity mode: [live app and editor, explicit static fallback, focused alternative, prior practice, or recap]

## Revisions

- 2026-10-18 (slice 2, research result): **Two-mic direction is not usable on the Xiaomi 12T Pro via `MIC` + `CAMCORDER` sources** — sustained loud sound near one edge gave ~0.0–0.2 dB difference between sources (mean |diff| ~2.4 dB across 220 samples; louder side near-random). Evidence: `probe_log.txt` (timestamped `PROBE bottom=… top=…` lines), probe readout in-app.
- 2026-10-18 (slice 2, round 2 — learner asked to retry): widened to five inputs (`CAMCORDER`, `MIC`, `VOICE_RECOGNITION`, `UNPROCESSED`, stereo L/R). **Confirmed: no direction signal.** Stereo L==R in 446/446 samples; during sustained loud sound all pairs within ~0.9 dB; large spreads only at onsets with flipping order (timing skew, not space). Evidence: `probe_log_r2.txt`.
- 2026-10-18 (slice 2, round 3 — decisive device-selection test): the phone exposes **two physical builtin mics as separate devices (id 17, id 19)**, but when two captures ran together the policy pinned both to one device; micA/micB offset constant ~8–10 dB regardless of sound position = AGC artifacts on one signal. Evidence: `probe_log_r3.txt`.
- 2026-10-19 (slice 2, round 4 — learner-requested final retry, source × device matrix with phase markers): all four sources (`MIC`, `CAMCORDER`, `VOICE_RECOGNITION`, `UNPROCESSED`) + a no-preference reference **routed to the same single device**; per-phase differences within **±0.2 dB** across the learner-marked protocol (quiet/top/bottom/left/right, ~940 samples); concurrent captures honor only the first capture's device preference. Evidence: `probe_log_r4.txt` (incl. `MicProbe` routing log + `PHASE` markers). **PLAN REVISION RESOLVED (kernel): direction removed — four rounds show the platform cannot provide it honestly on this device. Learner decision after reviewing all evidence: keep the honest core as the "sound pulse (visual vocabulary)" — center-expanding pulse, brightness/size ← strength, color ← loudness, onset shape + rhythm + fade-out ← measured signal behavior. `prd.md > Sound pulse (the visual vocabulary)` and `spec.md > Components` updated; the direction research stands as a documented finding (protocol + logs), not a failure.**

- 2026-10-18 (slice 1, environment): `permission_handler` 13.x requires Android SDK 37, whose platform package is published with a broken identity (`android-37.0`, ApiLevel `37.0`) that Gradle/AGP could not resolve, and the SDK manager kept reinstalling it on every build. Fix chosen: pinned `permission_handler: 12.0.3` (needs SDK ≤ 35; our SDK 36 satisfies it). No behavior difference for our needs (mic request + permanentlyDenied + openAppSettings all available). `flutter analyze` clean, `flutter test` passes, `flutter build apk --debug` succeeds. Learner check on the physical phone still pending (device was not connected via ADB at slice close).

- 2026-10-22 (look and feel): **Canvas revised dark → light.** The dark near-black surface planned in `prd.md > Look and Feel` and `spec.md > Look and Feel` read as clinical on the phone; a light canvas also leaves the pulse as the only bright thing on screen, which is the product's whole point. Shipped in `lib/theme.dart`: canvas `#F4F7F6`, ink `#10201F`, teal accent `#0E8C7F`, and the proximity semantics restated for light — very close red `#CE4338` (4.7:1 on white), farther orange `#C67C15` (3.3:1: fill/dot, not body text), unknown a quiet neutral `#7E9995` sitting deliberately outside the loudness scale. Every text colour is contrast-checked against its own background; values falling short are documented as fill-only. The "?" mark for unknowns moved from white to dark ink for the same reason. `prd.md` and `spec.md` updated in place.

- 2026-10-22 (sound-type bubbles): **Button-like chrome removed.** The circle, ring, shadow and colour wash were what made a bubble read as a *button*, and it is not one. The artwork now stands alone in a fixed 72 px box; loudness travels through the artwork's **scale** (0.75 → 1.0) instead of a coloured ring, applied as a `Transform` so the layout never re-flows as a sound changes. Shipped in `9f6d4ac`; `lib/ui/bubbles.dart` carries the reasoning.

- 2026-10-22 (vibration, bug fix): **One buzz per captured event, not per notification.** `_onSessionChanged` used to buzz whenever `_session.events.isNotEmpty`, but `events` is rolling display history that is never drained while a session runs, and `onLevel` notifies on every tick (~10/s) — so after the first strike the app buzzed continuously for the rest of the session. Fixed by separating *display history* from *pending work*: `SessionController` gained `pendingEventCount` + `consumeEvents()`, and the screen drains before buzzing. The toggle is honoured at two layers (draining ignores it, so events caught while off are dropped rather than replayed when it is switched on; `buzzOnEvent` also early-returns when off). Stale post-stop levels can no longer arm an event (`onLevel` now requires an active session). 6 new tests in `test/vibration_trigger_test.dart`, 31/31 green. Shipped in `3666601`.
