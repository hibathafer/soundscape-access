---
doc: scope
status: approved
---
<!-- `status` is the progress state every skill reads. Write `draft` when you first save this file,
     and change it to `approved` when the learner clearly approves the displayed plan ("looks good" counts).
     Do not request a second sign-off. Never skip the draft save —
     an unsaved draft dies with the conversation. -->

# Soundscape Access

A mobile app that helps a deaf or hard-of-hearing user notice and identify selected sounds around them during ordinary moments, not only in dangerous ones. It offers a visual and optional haptic view of sound strength and behavior; it does not replace hearing or identify where a sound came from. A real starting point is enough; this does not have to be a super-app.

## The Unique Kernel
A live visual pulse that represents a sound's **strength and behavior** (onset, repetition, and fade), paired with **artwork that names a supported sound category** (car, speech, door…). In other words, the phone offers a **visual sense of selected sounds in the environment**. If we deleted the pulse and nobody noticed the difference, nothing distinctive would be left — this is the kernel of the project. Direction was part of the initial idea, but was removed after the documented device tests found no reliable directional signal.

## Who It's For
Deaf or hard-of-hearing people who want to feel the sound of their environment **in ordinary time**, not only when something is dangerous.
What they do instead today: relying on constant watching, or alerts that are very limited (a doorbell, someone touching their shoulder) — there is no continuous sense of what is going on around them.

## The Core Loop
The user opens the app and starts a session → the app captures a sound → the pulse describes its **strength and behavior**, and an **icon appears when a supported category is identified** → the user decides what to do → as the sound dies away, the pulse fades. No direction or distance measurement is claimed.
The user comes back because the environment feels alive around them — "ears that stay on," by their own choice.

## Inspiration & Identity
- The Korean drama *Twinkling Watermelon*: the scene where a ringing bell switches the lights on so the characters know danger is coming, and the scene where a deaf child is in danger while his hearing brother calls him and he cannot hear him. **Light and flash as a channel of awareness.** (Reference link to be added.)
- The feeling to aim for: **calm, aware presence** — not panic, not constant alarms. The app supports the user; it does not shout at them.

## Why This Matters to the Learner
In her words: "I am from the group with physical disabilities, so I know the community of people with special needs up close… every time I build an idea, my goal is to make things easier for a specific group."
Her previous project: a simple MVP that listed the accessibility facilities available to people with physical disabilities (ramp? elevator?) — the questions she faces when going anywhere. This time she chose another group she cares about: deaf and hard-of-hearing people.

## What "Working" Looks Like
The demo video (first minute): the app open on screen → a supported sound plays → the phone shows the corresponding category when recognized and a pulse that follows the sound's strength/behavior → the source stops → the pulse fades.
The "wow" moment she wants: "a different feeling toward sounds for the first time" — the sound environment reaching the user through visual and optional haptic feedback.

## The POC Boundary
In the first version (the agreed minimum):
1. Capturing sounds and classifying them into the **five categories** specified in `prd.md`.
2. **A visual pulse** that follows sound strength, onset, repetition, and fade; it does not track direction or distance.
3. **Artwork naming a supported sound category**, with an honest unknown state.
4. Running **with the screen on, phone in hand or in front of the user**.

## Later
- **Always-on background operation (24/7) and vibration while the screen is off** (the sleep mode she described) — a stretch goal, to be attempted only if research (`4-spec`) shows it is feasible and time allows.
- More sound categories and higher classification accuracy.
- Public deployment — optional anyway.

## Evidence-based revision

The initial direction-tracking idea was removed on 2026-10-19 after four
on-device microphone experiments on the Xiaomi 12T Pro did not establish
a reliable directional signal. The learner chose the sound-behavior pulse
as the kernel instead. The experiment evidence and decision are recorded
in `devpost/spec.md` and `devpost/checklist.md`; direction is not a current
feature or a delivery claim.

## Explicitly Cut
- **Multiple vibration patterns** as an alternative to icons — they tire the user's memory and clutter the experience (her own concern about too much vibration).
- **Recognizing "every sound in the world"** — a deliberate limit: 3–5 categories prove the idea. As she put it: "It does not have to be a super-app… at least it should be a beginning."
