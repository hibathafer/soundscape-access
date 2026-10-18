---
doc: spec
status: approved
---
<!-- `status` is the progress state every skill reads. Write `draft` when you first save this file,
     and change it to `approved` when the learner clearly approves the displayed plan ("looks good" counts).
     Do not request a second sign-off. Never skip the draft save —
     an unsaved draft dies with the conversation. -->

<!-- Adaptive template. The one rule: anything `5-build` will point at needs its own heading.
     Write the plain-language sections so the learner can read them back to someone else. -->

# Soundscape Access — Technical Spec

## How This Works, In Plain Language

The app is one Flutter program (written in Dart) that runs on the phone. It has five simple parts that talk to each other:

1. **The ears (Audio Capture)** — a small piece that keeps listening while the session runs and passes a slice of what it hears to the next part, many times per second.
2. **The name-giver (Sound Classifier)** — a tiny AI model called **YAMNet** that lives *inside the phone*. It hears a slice and answers: "this sounds like a car / speech / a door / an alarm / birds / I don't know," with a confidence number. Nothing leaves the phone — free, works offline, private.
3. **The compass (Direction Estimator)** — uses the phone's two microphones (top and bottom on the Xiaomi 12T Pro) and compares which one hears the sound louder, to guess which side the sound came from. *This is the part we agreed to test on the real phone first*; if it misbehaves, we sit down and adjust the plan honestly — we never fake the direction.
4. **The brain (Session Controller)** — decides when a session starts and stops, applies the rules: known sound → colored bubble, unknown → white "?" bubble, vibration only when the user turned it on, and tries to keep listening after the user leaves the app (with the approved fallback: the app stays in front if the phone refuses).
5. **The face (Flash + Bubbles UI)** — the screen part everyone sees: the flash that starts on the sound's side and fades the other way, the swipeable icon bubbles, the two buttons.

**Why this shape and nothing more elaborate:** everything runs on the phone — no servers, no accounts, no internet, no keys, no cost. A proof of concept must start instantly and record cleanly for the demo video, and the audience we serve deserves sounds that don't leave their device.

## The Core Journey Through the System

PRD ref: `prd.md > The Core Journey`.

1. **User opens the app** → App Shell renders the single dark screen (Start/Stop + vibration toggle) from in-memory state (fresh by default).
2. **First start** → Session Controller asks Audio Capture for microphone access → the gentle one-line explanation shows, then the system dialog.
   - Denied → friendly message + route to settings (`prd.md > States and Boundaries > Permission denied`).
3. **User presses Start** → Session Controller: sessionActive = true → toast **"Working now"** → Audio Capture begins streaming PCM slices.
4. **User leaves the app** → Session Controller attempts the Android **foreground service (type: microphone)** so capture continues; if the phone refuses or kills it → approved fallback: session continues with the app in front (`prd.md > Open Questions`).
5. **Each audio slice** flows two ways, in parallel:
   - → **Sound Classifier (YAMNet)** → category + confidence. Confident result → mapped to one of the five categories; weak/unknown → white "?" (`prd.md > Unknown sounds`).
   - → **Direction Estimator** → side/strength from the two microphones' level difference.
6. **Results merge** in the Session Controller into a *sound event* {category, direction, strength, proximity color} → **Flash + Bubbles UI**: flash ignites on the sound's side with the proximity color, icon bubble appears (swipeable); two sounds → two events, both shown (`prd.md > Simultaneous sounds`).
7. **Vibration toggle on** → Vibration Service buzzes on captured events (`prd.md > Vibration (manual, simple)`).
8. **Source/user moves away** → level drops → event strength fades → flash dims and disappears; **Stop** → sessionActive = false → capture, service, vibration end.

## Stack

| Choice | What it is | Why | Tradeoff accepted |
|---|---|---|---|
| **Flutter + Dart** (learner's choice) | One codebase → Android + iOS; UI framework | Learner: "I want to settle on one language and develop myself" | Platform-specific features (mic, vibration, background) need plugins/bridges — more moving parts than pure native |
| **YAMNet via `tflite_flutter`** (learner-agreed) | On-device sound classification model (TensorFlow Lite) | Free, offline, private; classes cover our five categories | Medium accuracy — proves the idea, not perfect on every device |
| **Android (Kotlin) bridge in `android/`** | Host-side code for two-mic capture + foreground service | Android 14 requires real service/permission plumbing Flutter can't do alone | Some logic lives outside Dart — documented below |
| **`vibration` package** | Simple on/off haptics | Matches the "manual, simple" decision; no patterns | None for this scope |

Documentation links:
- Flutter: https://docs.flutter.dev · Dart: https://dart.dev/language
- `tflite_flutter`: https://pub.dev/packages/tflite_flutter
- YAMNet (model card): https://www.tensorflow.org/hub/tfhub/dev/google/yamnet — **unverified: a ready-to-use `.tflite` file and its labels file; confirm availability/size in the first build step; alternative = convert the SavedModel ourselves (flagged in `Important Failure Modes`).**
- `vibration`: https://pub.dev/packages/vibration
- Foreground service types (Android 14, `microphone`): https://developer.android.com/guide/components/foreground-services
- Recording audio from selected mic sources (Android `AudioRecord`): https://developer.android.com/reference/android/media/AudioRecord

**Unverified — check early in the build:** exact package versions; whether individual (unmerged) microphone streams are selectable on the Xiaomi 12T Pro; Android 14's "start foreground service with microphone type only from foreground" rule as implemented.

## Where It Runs and How Someone Tries It

- **Runtime:** Android app on a real phone. Test device: **Xiaomi 12T Pro, Android 14 (SDK 34)**, connected via USB debugging (verified present: Flutter SDK + ADB on the dev machine). An emulator may be used for pure UI work — it has no real dual-mic setup, so **direction and classification tests run on the real device**.
- **Start (developer):** connect the phone → `flutter run` → app installs and opens.
- **Start (for the demo video / a reviewer):** `flutter build apk` → install the APK on the phone → open **Soundscape Access** → press Start.
- **Demo recording:** local screen recording of the phone (no deployment needed). Submission requires **a short demo video + a public GitHub repository**; deployment is optional and not chosen here (can be revisited in `6-ship`).
- **Device setup notes (Xiaomi):** enable Developer options + USB debugging; for background capture, allow **Autostart** and exempt the app from battery optimization (MIUI/HyperOS is known to kill background services).

## Look and Feel

Carried forward from `prd.md > Look and Feel` and `scope.md > Inspiration & Identity` — direction, not a design system:
- **Dark, near-black surface** (e.g. deep blue-black like `#0F1720`) so light is the hero; Flutter Material 3 **dark theme** with custom colors can fully honor this.
- **Warm, friendly character:** rounded shapes, calm spacing, plain supportive copy ("Working now"), no alarm-red UI chrome; color is used for data, not to frighten.
- **Fairly large, clear type:** default Material text scaled up; glanceable labels.
- **Color semantics (exact values to implement):** proximity red ≈ `#E2574C`, farther orange ≈ `#F4B942`, unknown white `#FFFFFF`; the flash is a soft edge glow/gradient whose position and strength always carry the same information as the color.
- Stack constraint: Flutter themes cover all of the above; no design tooling beyond code is needed.

## Components

### App Shell (single screen)
Renders the only screen: large center Start/Stop, small vibration toggle, live area beneath. Owns navigation nowhere — there is none.
PRD ref: `prd.md > Screens and Layout`.

### Audio Capture Service
Keeps the microphone open for the session; streams short PCM slices (mono, 16 kHz — YAMNet's expected input) to the classifier and the direction estimator; stops on Stop/app kill. Handles the permission flow: gentle one-line explanation → system dialog.
PRD ref: `prd.md > Features and Behavior > Sound capture and classification (session-based)`, `prd.md > States and Boundaries > First use`.

### Sound Classifier (YAMNet, on-device)
Loads the TFLite model + labels from `assets/model/`; per slice returns scores → mapped to exactly five categories: cars/traffic, speech, door/knock, alarm/bell/beep, birds/nature. Below confidence threshold → **unknown**. Threshold is an implementation constant, tuned during the build against real sounds (not a learner decision).
PRD ref: `prd.md > Sound capture and classification`, `prd.md > Unknown sounds`.

### Direction Estimator
Compares input levels across the phone's microphones (top vs bottom on the test device) to estimate the sound's side and strength. **Research-first:** build step 1 verifies (a) individual mic sources are selectable on this device, (b) a measurable level difference exists from a known side. Android `AudioRecord` via the Kotlin bridge.
PRD ref: `prd.md > Directional flash`. Known limits: two mics on one axis bias top/bottom discrimination; left/right may be weaker — results decide the honest adjustment (see `Decisions and Open Issues`).

### Session Controller
Single owner of session state: Start/Stop, the "Working now" toast, vibration toggle, sound events, and the **background attempt** (Android foreground service, type `microphone`, started while the app is in the foreground) with the approved fallback to a foreground session.
PRD ref: `prd.md > Starting and stopping`, `prd.md > Leaving the App (state)`, `prd.md > Product Decisions > Session must not obstruct phone use`.

### Visual Feedback — Flash + Bubbles
Consumes sound events: renders the directional edge flash (side, strength, proximity color; fades as the level drops), and the swipeable messenger-style bubbles (category icon; white "?" for unknown). Two simultaneous events render independently.
PRD ref: `prd.md > Directional flash`, `prd.md > Sound-type bubbles`, `prd.md > Simultaneous sounds`.

### Vibration Service
Thin wrapper over the `vibration` package: buzz once per captured event while the toggle is on; no patterns. Needs `VIBRATE` permission (normal level).
PRD ref: `prd.md > Vibration (manual, simple)`.

## Data Model

Nothing persists — no database, no files written by the app (PRD: "nothing persists between sessions"). All state is in-memory:

| Piece of data | Lives where | Updated when | User leaves & returns |
|---|---|---|---|
| `sessionActive` | Session Controller (memory) | Start/Stop pressed | Fresh app start = session off (state lost, by design) |
| `vibrationEnabled` | in-memory | toggle tapped | resets to off |
| `soundEvent {category, confidence, side, strength, color}` | ephemeral — created per detection, consumed by UI, discarded | every audio slice result | gone |
| YAMNet model + labels | `assets/` (bundled, read-only) | never at runtime | unchanged |
| Demo sample sounds | `assets/samples/` (bundled, **labeled sample data**) | never at runtime | unchanged |

## File Structure

```
soundscape-access/
├── android/                    # Android host: manifest, permissions, Kotlin bridge
│   └── app/src/main/
│       ├── AndroidManifest.xml # RECORD_AUDIO, FOREGROUND_SERVICE(_MICROPHONE), VIBRATE; service type=microphone
│       └── kotlin/…/           # dual-mic AudioRecord bridge + foreground service
├── lib/
│   ├── main.dart               # app entry; dark theme
│   ├── ui/
│   │   ├── home_screen.dart    # the single screen (App Shell)
│   │   ├── flash.dart          # directional flash rendering
│   │   └── bubbles.dart        # swipeable sound-type bubbles
│   ├── audio/
│   │   ├── capture.dart        # mic stream (16 kHz PCM slices)
│   │   └── permission.dart     # gentle explanation + system dialog flow
│   ├── classify/
│   │   ├── yamnet.dart         # TFLite wrapper: slice → scores
│   │   └── categories.dart     # 5-category mapping + confidence threshold
│   ├── direction/
│   │   └── estimator.dart      # two-mic level comparison (+ research notes)
│   ├── session/
│   │   ├── controller.dart     # session state, events, start/stop
│   │   ├── background.dart     # foreground-service attempt + fallback
│   │   └── vibration_service.dart
│   └── theme.dart              # colors: red/orange/white semantics, dark palette
├── assets/
│   ├── model/                  # yamnet.tflite + labels.txt (verified in build step 1)
│   └── samples/                # demo sounds (labeled sample data)
├── test/                       # tests for classifier mapping, session rules
├── devpost/                    # Devpost learning workspace (learner-profile.md gitignored)
├── README.md                   # run/setup instructions
├── pubspec.yaml
└── .gitignore
```

The learner should be able to read this tree and know where everything lives; `5-build` slices the work along these folders.

## External Services and Dependencies

**None external.** No servers, no APIs, no accounts, no keys, no paid or rate-limited services — cost: **$0**, limits: **none**. Everything else is a bundled library or asset:

| Dependency | Type | Link | Notes |
|---|---|---|---|
| Flutter SDK / Dart | toolchain | docs.flutter.dev | Installed on the dev machine (verified) |
| `tflite_flutter` | pub package | pub.dev/packages/tflite_flutter | version to pin at build |
| YAMNet model | bundled asset (Apache-2.0) | tensorflow.org/hub/tfhub/dev/google/yamnet | availability of a `.tflite` copy unverified — see failure modes |
| `vibration` | pub package | pub.dev/packages/vibration | — |
| Android AudioRecord / FGS APIs | OS built-in | developer.android.com | no key needed |

## Important Failure Modes

- **Microphone permission denied** → friendly message + button opening device settings (as agreed in the PRD); app stays usable for nothing else. (`prd.md > Permission denied`)
- **Classifier unsure / silent environment** → no bubble for silence; white "?" bubble when a sound exists but can't be named — never a crash, never a hidden sound. (`prd.md > Unknown sounds`)
- **Background capture refused/killed (Xiaomi MIUI/HyperOS)** → approved fallback: session keeps running with the app in front; setup note (Autostart/battery exemption) documented in `Where It Runs`. (`prd.md > Open Questions`)
- **Two-mic direction not available on this device** → plan-revision conversation with the learner (agreed in `4-spec`); degraded options are decided together — **the direction is never faked**.
- **YAMNet `.tflite` file unavailable/incompatible** → convert from the TensorFlow Hub model ourselves, or swap to an equally small sound-classification model — decide in build step 1, before UI work.

## What Was Simplified and Why

- **On-device YAMNet** instead of a cloud classification API — learner-agreed: free, offline, private; a cloud option stays a possible later enhancement only if the core succeeds and time remains.
- **No persistence at all** instead of settings/history — the PRD stores nothing; restart = fresh session.
- **One screen, no navigation/settings** — the whole product is one loop; a settings surface is a later enhancement.
- **Bundled labeled sample sounds** for the demo instead of depending on live traffic outside — the demo must work in a recording on demand (samples are labeled as sample data; the live path remains real and primary).
- **Simple vibration (on/off)** instead of per-sound patterns — learner's cut: patterns are memorization-heavy and cluttered.

## Decisions and Open Issues

**Learner decisions (with reasons):**
- **Flutter + Dart** — "settle on one language and develop myself." Tradeoff: platform bridges for mic/background.
- **On-device YAMNet now; cloud option only as a later enhancement** — free/offline/privacy accepted with medium accuracy; conditional extension if core succeeds and time remains.
- **Android on a real device (Xiaomi 12T Pro), local run + recording** — no deployment required; deployment stays optional for `6-ship`.
- **Direction tested on the real phone first; decide from results** — "let's try my device first and decide based on the outcome."
- **Background capture attempted with honest fallback** (carried from the PRD).

**Implementation details derived from those decisions:** the packages, file layout, category threshold, and event shape above — implementation choices, not learner decisions.

**One useful unknown (agreed investigation):**
- **Can this app hear the two microphones separately on the Xiaomi 12T Pro, and is the level difference usable for direction?** Clarified by: build step 1 — record from selected mic sources while a sound comes from a known side, compare levels on screen. Evidence needed: a repeatable per-mic level difference (top/bottom first; left/right assessed separately). If unavailable → the agreed plan-revision conversation, options presented honestly (never fake the kernel). Record the outcome here during the build.

**Still unresolved (carryover):**
- `prd.md > Open Questions` — background capture feasibility: approach now specified (FGS type `microphone` from foreground; fallback foreground session); device verification happens in `5-build`.
- YAMNet `.tflite` asset availability — resolve in build step 1.
- `prd.md` labeled assumptions (toggle stop, denied-permission copy, quiet-state presentation) — trivial, confirmed at review unless changed.
- *Twinkling Watermelon* reference link — cosmetic.
