---
doc: prd
status: approved
---
<!-- `status` is the progress state every skill reads. Write `draft` when you first save this file,
     and change it to `approved` when the learner clearly approves the displayed plan ("looks good" counts).
     Do not request a second sign-off. Never skip the draft save —
     an unsaved draft dies with the conversation. -->

<!-- This is the complete product definition: the scope sketch, filled in.
     Completeness is the standard, not length — a short PRD for a small product is correct.
     Keep it inside the approved POC boundary. Keep heading names stable and descriptive:
     `4-spec` and `5-build` reference them by name. -->

# Soundscape Access — Product Requirements

A session-based mobile app that gives a deaf or hard-of-hearing user a live sense of the sounds around them — that something just happened, how strong it is, how it behaves, and what it is — without getting in the way of normal phone use. *(Revised 2026-10-19: "where they come from" was removed after four on-device experiment rounds proved direction is not obtainable through public APIs on the test device — see `checklist.md > Revisions`.)*
Source: `scope.md > The Unique Kernel`, `scope.md > The Core Loop`.

## The Core Journey
The complete path, end to end (numbered steps, plain language):

1. The user opens the app and sees **one screen**: a large **Start/Stop** button in the center and a smaller **vibration toggle** (see `Screens and Layout`).
2. The first time they start, a **gentle one-line explanation** appears — in a friendly tone — explaining why the app needs the microphone, immediately followed by the system's microphone-permission dialog.
3. The user presses **Start**. A small toast confirms: **"Working now."**
4. The user **leaves the app** — back to the home screen or into other apps — and keeps using the phone normally. The session continues without obstructing phone use *(with a documented fallback: if background capture proves infeasible, the session runs with the app in front — see `Open Questions`)*.
5. Sounds arrive: a **live pulse** ignites at the center of the screen and expands outward — brighter and larger for stronger sounds (see `Look and Feel`). The pulse's **shape** shows how the sound began (a sharp flash for a sudden bang, a soft glow for a gradual rise) and a **repeating rhythm** for repeated sounds like knocking or alarm beeps.
6. A **swipeable bubble** (messenger-chat-head style) shows an **icon naming the sound type** in the live area; the user can swipe it down to dismiss it.
7. If a sound cannot be identified, the same bubble appears with a **neutral "?" mark in white** — no special alarm, no special vibration — while the pulse still fires, so the user knows a sound is there to investigate.
8. If **two sounds** arrive at once, both are shown, each with its own pulse and color.
9. The optional **vibration toggle**: when enabled during the session, the phone vibrates as sounds are captured (e.g., phone in a pocket) — simple, not pattern-based.
10. As the sound stops, its pulse fades and disappears. The user presses **Stop** to end the session.

## Screens and Layout
- **One screen only** (no navigation):
  - **Center:** large Start/Stop button — the single primary action (learner: "a screen with one button in the middle").
  - **Secondary:** a small, non-intrusive **vibration toggle** the user turns on himself when he wants it (e.g., pocket).
  - **Live area:** the sound pulse renders across the whole screen area; sound-type bubbles float above it and can be swiped away.
- Leaving the app (home screen / other apps) is part of the intended flow — the app must not force itself to stay in front of the user (see `States and Boundaries` for the fallback).
- No other screens exist in this version. The microphone permission dialog is a system dialog, preceded by the app's one-line explanation.

## Look and Feel
Established in the `3-prd` design beat (learner's answers):
- **Dark background** — the flash must read clearly; the dark surface makes light the hero of the screen.
- **Warm and friendly character** — "an app that supports you, not one that shouts at you" (`scope.md > Inspiration & Identity`).
- **Fairly large, clear type** — the user glances and returns to what they were doing.
- **Color semantics** (content rules, not decoration):
  - **Red** — very loud sound (usually a close source).
  - **Orange** — moderately loud sound.
  - **White** — sound present but type unknown (neutral, outside the loudness scale).
  - Color is never the only signal: the pulse's **brightness and shape** always carry the same information.
- The pulse expands from the center with every sound and fades away, echoing the drama's "light as a channel of awareness" identity. *(Revised 2026-10-19 with the kernel change — loudness honestly approximates closeness, but no direction is claimed.)*

## Features and Behavior

### Sound capture and classification (session-based)
While a session is active, the app captures ambient sound and classifies it into **exactly five categories** (learner's confirmed list):
1. Cars / traffic (engine, horn)
2. Speech / human voices
3. Door / knocking
4. Alarm / bell / beep (incl. reversing-vehicle beeps)
5. Birds / nature

- [ ] Acceptance criterion: with a car-horn sample played from one side, the app shows the car icon in a bubble during the sound.
- [ ] Acceptance criterion: the five categories are the only types shown in this version; nothing else is promised to the user.

### Sound pulse (the visual vocabulary)
The pulse is the kernel. Every real sound ignites it; its properties honestly describe the sound:
- **Ignition and expansion**: the pulse starts at the screen center and expands outward; **brightness and size follow the sound's strength** (loud sounds = big, bright; soft sounds = small, dim).
- **Color follows loudness** (a practical proxy for closeness): **red** very loud, **orange** moderate — see `Look and Feel`. No direction is claimed (removed after documented device research — `checklist.md > Revisions`).
- **Onset shape**: a **sudden** sound (bang, door slam) produces a **sharp fast flash**; a **gradual** sound (speech building up, birds) produces a **soft quick fade-in**. Measured from how fast the level rises, not guessed.
- **Rhythm**: **repeated** sounds (knocking, alarm beeps) produce **rhythm rings** — the pulse visibly re-strikes with each beat; a **continuous** sound (engine, speech) produces one **sustained** pulse that holds while the sound holds.
- The pulse **fades out** as the sound dies, and the screen returns to calm.
- [ ] Acceptance criterion: a loud sudden sound produces a bright, sharp, large pulse that fades when the sound stops.
- [ ] Acceptance criterion: a repeating sound (e.g., knocking) produces visibly re-striking rings; a continuous sound produces one held pulse.
- [ ] Acceptance criterion: a soft sound produces a small dim pulse — never as bright as a loud one.

### Sound-type bubbles
- Each identified sound appears as a **floating bubble with the category icon** in the live area — styled like messenger chat heads: visible, calm, non-blocking.
- The user can **swipe a bubble down to dismiss** it.
- [ ] Acceptance criterion: a recognized sound shows its icon bubble; swiping removes it without affecting the session.

### Simultaneous sounds
- Two sounds at once → two bubbles, each with its own pulse and color (red/orange by loudness).
- [ ] Acceptance criterion: playing two different sounds at once shows both bubbles with their own pulses.

### Unknown sounds
- If classification cannot name a sound, the bubble still appears with a **neutral "?" in white** — the learner's decision: "if it disappears, the situation becomes worse; our goal is to help, so at least there remains a source for the sound."
- No special vibration and no alarm styling for unknowns; the pulse still shows that a sound happened and how strong it was.
- [ ] Acceptance criterion: an unclassifiable sound produces a white "?" bubble and no crash; the pulse still fires.

### Vibration (manual, simple)
- The vibration toggle is **manual and session-scoped**: vibrate when sounds are captured while the session runs — deliberately **not** pattern-per-sound (cut in `scope.md > Explicitly Cut`).
- [ ] Acceptance criterion: with the toggle on, capturing a sound produces a vibration; with it off, none.

### Starting and stopping
- Start → toast **"Working now"** → the user may leave the app; the session keeps running (fallback in `Open Questions`).
- The center button toggles: pressing it again stops the session. *(Assumption: toggle behavior — learner did not specify an alternative.)*

## States and Boundaries
- **First use** — a friendly one-line explanation of why the microphone is needed, then the system permission dialog. (Learner: "I definitely prefer explaining to him gently why we need the permission.")
- **Permission denied** — a friendly short message that the app cannot work without the microphone, plus a route to the device settings. *(Assumption, surfaced for confirmation during review.)*
- **Quiet environment / no sounds to show** — the screen stays calm and empty of bubbles; the session remains active. *(Assumption: no "active" indicator was specified beyond the start toast.)*
- **Unknown sound** — white "?" bubble as described; session unaffected.
- **Leaving the app** — intended flow: capture continues without obstructing phone use; if the platform refuses background capture, fallback = the session runs with the app in front (see `Open Questions`).
- **No accounts, no stored data** — nothing persists between sessions in this version; closing the app ends the session's state.

## Product Decisions
Decisions the learner made during the interview, with reasons:
- **Icons + pulse for sound identity** — chosen over vibration patterns (patterns are hard to memorize and cluttered) and over text (reading breaks the continuous feel).
- **Proximity colors (red/orange) + neutral white for unknown** — "I want the color to indicate the source's proximity"; white keeps unknowns outside the danger scale.
- **Unknown sounds are shown, not hidden** — "our goal is to help, so at least there remains a source for the sound… he can track it and find out."
- **Session must not obstruct phone use** — a sound-sense must not force the user to stare at it; background capture for the *session* is required intent, with a documented fallback because it needs technical research.
- **Five categories fixed for v1** — highest recurrence and importance, chosen from a suggested list and confirmed by the learner: "all of them — they are the best choice, most recurring, and most important."
- **Gentle permission explanation before the system dialog** — matches the identity of a supporting app.
- **Visual direction: dark + warm/friendly + fairly large clear type.**
- **Manual vibration toggle** (on/off per the user's will, e.g., pocket) rather than automatic constant vibration — her own concern: constant vibration becomes annoying.
- **Kernel revised 2026-10-19: direction removed, sound-behavior vocabulary added** — four on-device experiment rounds proved the platform gives apps one mixed audio signal on the Xiaomi 12T Pro (evidence in `checklist.md > Revisions`; logs `probe_log*.txt`). Learner decision after seeing the evidence: keep building the honest core — a center-expanding pulse whose brightness/size follow strength, color follows loudness, and whose **onset shape, rhythm, and duration** describe how the sound behaves — instead of a direction claim the device cannot support. Stated by the learner: "this is a learning hackathon and the value is building something real and effective."

## What We're Building
The proof of concept must, to be complete:
1. One dark, warm, single-screen app with a large Start/Stop button and a vibration toggle.
2. Gentle microphone-permission explanation on first use, and a friendly denied state.
3. Session-based capture that classifies into the five fixed categories.
4. Sound pulse (the visual vocabulary): center-expanding pulse; brightness/size follow strength; color follows loudness (red/orange); onset shape (sharp vs soft), rhythm (re-strike vs sustained), and fade-out — all measured from the real signal. *(Revised 2026-10-19; direction removed after documented device research.)*
5. Swipeable icon bubbles per sound; white "?" bubble for unknown sounds; two-sound display.
6. Manual vibration during the session.
7. Start toast ("Working now"), the ability to leave the app without blocking phone use *(or the documented foreground fallback)*, and a working Stop.
8. The behavior shown in `scope.md > What "Working" Looks Like` demonstrable in a one-minute demo video.

## Deferred From the POC
Named with reasons so they never slip into the build unnoticed:
- **Always-on 24/7 background operation with the screen off** (the sleep mode) — needs research; was cut to Later in `scope.md > Later`.
- **More categories and higher classification accuracy** — accuracy work is out of scope; five categories prove the kernel.
- **Public deployment** — optional by the hackathon rules; a local recording is fine for the video.

## Possible Later Enhancements
- Sleep/vibration mode with the screen off, user-armed.
- Additional sound categories and richer "what is it" detail.
- Cooler color steps beyond orange for very distant sounds.
- A deeper settings surface (categories on/off, sensitivity).

## Non-Goals
- **Recognizing every sound in the world** — deliberately capped at five categories ("it does not have to be a super-app… at least it should be a beginning" — `scope.md > Explicitly Cut`).
- **Multiple vibration patterns per sound type** — cut as memorization-heavy and cluttered.
- **Accounts, profiles, history, cloud sync, sharing** — nothing in this product implies them.
- **Being an alarm-only danger app** — the identity is continuous, calm awareness in ordinary time, not emergency alerting.

## Open Questions
- **Background capture for the session** (leaving the app while capturing): must be investigated in `4-spec`. Does it block `4-spec` approval? **No** — the fallback (foreground session) is already approved; spec must document which path the device research supports. Flagged for `5-build` verification on the actual device.
- **Direction detection** — **resolved 2026-10-19 (negative)**: four on-device rounds proved no directional signal is obtainable on the Xiaomi 12T Pro via public APIs; direction was removed from the kernel and replaced (learner decision) by the sound-behavior vocabulary — see `checklist.md > Revisions` and `spec.md > Decisions and Open Issues`.
- **Reference link** for *Twinkling Watermelon* — cosmetic, can be added anytime.
- **Assumptions labeled in this document:** toggle stop behavior; denied-permission message; quiet-state presentation. Consequential enough to confirm during review; none block `4-spec`.
