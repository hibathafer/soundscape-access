# Soundscape Access

**Turn the sounds around you into something you can see and feel.**

Soundscape Access is an Android accessibility app that listens to the
environment and reports it in two non-auditory channels: a live visual
"sound pulse", and vibration. It is built for people who are blind or
have low vision, and for anyone in a situation where they cannot look up
or listen closely.

Everything runs **on the device**. There is no server, no account, and
no network access at runtime — the microphone stream never leaves the
phone.

---

## The problem

A person who cannot see the room has to reconstruct it from hearing
alone, which means:

- **"Is that a car or a bird?"** — sounds arrive unnamed and unranked.
- **"How loud is it, really?"** — loudness is the cue that tells you
  whether something needs attention, but hearing alone is a poor gauge.
- **"Is something happening repeatedly?"** — a steady hum and a series
  of knocks feel different, and the difference matters.

Existing tools tend to be either research prototypes with no product
polish, or fixed single-purpose alerts. This project aims at a small,
coherent, genuinely usable screen: one tap to start, and the
environment starts describing itself.

## What it does

| Feature | Behaviour |
|---|---|
| **Start / Stop** | One large button. Microphone permission is requested once, with an explanation first. |
| **Sound pulse** | A soft mist cloud whose size, colour and rhythm follow the sound — grows with loudness, re-rolls a wave on every detected strike. |
| **Sound-type bubbles** | Up to a handful of labelled bubbles (car, speech, door, alarm, birds). A repeat sound refreshes its bubble rather than piling up duplicates. Swipe a bubble down to dismiss it. |
| **Vibration** | Each detected sound can also be felt. On/off is a single toggle. |
| **Colour key** | Close / Farther / Unknown is shown as words *and* swatches before the session starts — colour is never the only signal. |
| **Unknown, honestly** | When the model is not confident enough, the app says *unknown* instead of guessing a name. |

## What it deliberately does **not** do

**It does not tell you where a sound is coming from.**

This was attempted seriously and abandoned on evidence. Six logged runs
of an on-device two-microphone probe live in the repository as
`probe_log.txt` … `probe_log_r6_direction.txt`. The first four rounds
are summarised in [`devpost/spec.md`](devpost/spec.md); the decisive
ones failed the criteria that were fixed *before* the test ran:

- the left/right axis produced the **same sign on both ends**;
- the *no-difference* control (source equidistant from both mics) came
  out **larger** than either end it should sit between;
- a fixed inter-channel offset of about −1.9 dB dominated every
  position regardless of where the source actually was.

A metric that reads loudest where the truth is "no difference" is not
measuring direction. Rather than ship a plausible-looking arrow that
was not actually measured, the feature was left out. The probe code
remains in the repository, gated behind a `const` flag, so the work is
reproducible.

## How it works

```
microphone  →  0.975 s windows  →  YAMNet (TensorFlow Lite, on-device)
                                       │
                          ┌────────────┴────────────┐
                          ▼                         ▼
                 5 categories + unknown     loudness / onset / rhythm
                          │                         │
                          ▼                         ▼
                   sound bubbles             sound pulse + vibration
```

- **Classification** — YAMNet scores are mapped by hand onto five
  categories (`cars`, `speech`, `door`, `alarm`, `birds`) using index
  sets built from the real `yamnet_class_map.csv`. Anything below the
  confidence threshold (0.35) resolves to `unknown`. Two strong
  categories at once produce two bubbles.
- **Behaviour** — loudness, onset (sudden vs gradual) and rhythm
  (continuous vs repeating) are measured from the level envelope, not
  guessed.
- **Rendering** — the pulse is deliberately *mist*, not a defined
  shape: a centre lobe plus three offset lobes, heavily blurred.

## Getting started

**Requirements**

- Flutter 3.44.6 (stable) or newer
- An Android device or emulator (Android 14 / API 34 was used for
  development)
- A JDK for the Android build

**Run it**

```bash
flutter pub get
flutter run
```

**Build an APK**

```bash
flutter build apk --debug
```

## Testing

```bash
flutter analyze   # no issues
flutter test      # 25 tests
```

The tests cover the category index map (disjointness, threshold
behaviour, honest unknown fallback), the session/bubble rules, the
behaviour analyzer, and a widget test that renders the screen.

## Planning documents

This project was built with the Devpost Learn Skill Pack. The three
generated planning documents are in the repository under [`devpost/`](devpost/):

| Document | Contents |
|---|---|
| [`devpost/scope.md`](devpost/scope.md) | The idea and what was cut out of it |
| [`devpost/prd.md`](devpost/prd.md) | Product definition: journeys, states, edge cases, boundaries |
| [`devpost/spec.md`](devpost/spec.md) | Technical blueprint: stack, components, data, file structure, decisions |

## Project structure

```
lib/
  audio/        microphone capture and permission flow
  analyze/      loudness, onset and rhythm from the level envelope
  classify/     YAMNet wrapper + category index mapping
  direction/    two-mic research probe (gated off by default)
  session/      session state, sound bubbles, vibration
  ui/           screen, sound pulse, bubbles
  theme.dart    light, high-contrast colour system
android/        native audio input + probe instrumentation
assets/model/   bundled YAMNet TFLite model and labels
devpost/        scope.md, prd.md, spec.md
probe_log*.txt  raw on-device research evidence
```

## Platform

Android only. iOS and desktop targets are not implemented.

## License

[MIT](LICENSE)
