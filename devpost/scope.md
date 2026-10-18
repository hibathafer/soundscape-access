---
doc: scope
status: approved
---
<!-- `status` is the progress state every skill reads. Write `draft` when you first save this file,
     and change it to `approved` when the learner clearly approves the displayed plan ("looks good" counts).
     Do not request a second sign-off. Never skip the draft save —
     an unsaved draft dies with the conversation. -->

# Soundscape Access

A mobile app that makes a deaf or hard-of-hearing user aware of the sounds around them — where they came from, how strong they are, and what they actually are — during ordinary moments, not only in dangerous ones. The goal is to get as close as we can to natural hearing: "as if I can hear everything around me." A real starting point is enough; this does not have to be a super-app.

## The Unique Kernel
A live flash across the screen that represents a sound's **direction and intensity**, moving and fading as the source moves away, paired with an **icon that names the type of sound** (car, speech, door…). In other words, the phone stops being an alarm and becomes a **continuous sense of the environment**. If we deleted the flash and nobody noticed the difference, nothing distinctive would be left — this is the kernel of the project.

## Who It's For
Deaf or hard-of-hearing people who want to feel the sound of their environment **in ordinary time**, not only when something is dangerous.
What they do instead today: relying on constant watching, or alerts that are very limited (a doorbell, someone touching their shoulder) — there is no continuous sense of what is going on around them.

## The Core Loop
The user opens the app and keeps it in front of them (screen on) → the app captures a sound → the phone **flashes from the direction of the sound** (stronger toward the source, weaker on the opposite side) and an **icon appears naming the sound type** → the user decides: ignore it, pay attention, or move → as the user or the source moves away, **the flash shifts toward the source, dims, and disappears**.
The user comes back because the environment feels alive around them — "ears that stay on," by their own choice.

## Inspiration & Identity
- The Korean drama *Twinkling Watermelon*: the scene where a ringing bell switches the lights on so the characters know danger is coming, and the scene where a deaf child is in danger while his hearing brother calls him and he cannot hear him. **Light and flash as a channel of awareness.** (Reference link to be added.)
- The feeling to aim for: **calm, aware presence** — not panic, not constant alarms. The app supports the user; it does not shout at them.

## Why This Matters to the Learner
In her words: "I am from the group with physical disabilities, so I know the community of people with special needs up close… every time I build an idea, my goal is to make things easier for a specific group."
Her previous project: a simple MVP that listed the accessibility facilities available to people with physical disabilities (ramp? elevator?) — the questions she faces when going anywhere. This time she chose another group she cares about: deaf and hard-of-hearing people.

## What "Working" Looks Like
The demo video (first minute): the app open on screen → a car horn or similar sound plays **from one side** (left / behind) → the phone **flashes immediately from that side and shows an icon for the sound type** → the source stops or moves away → **the flash shifts toward the source, dims, and disappears**.
The "wow" moment she wants: "a different feeling toward sounds for the first time" — the sound environment reaching the user through the screen.

## The POC Boundary
In the first version (the agreed minimum):
1. Capturing sounds and classifying them into **a limited set of categories (3–5)**; exact categories to be decided in `3-prd`.
2. **A flash that tracks direction and intensity** and fades as distance grows.
3. **An icon naming the sound type** (chosen approach: icons + flash).
4. Running **with the screen on, phone in hand or in front of the user**.

## Later
- **Always-on background operation (24/7) and vibration while the screen is off** (the sleep mode she described) — a stretch goal, to be attempted only if research (`4-spec`) shows it is feasible and time allows.
- More sound categories and higher classification accuracy.
- Public deployment — optional anyway.

## Explicitly Cut
- **Multiple vibration patterns** as an alternative to icons — they tire the user's memory and clutter the experience (her own concern about too much vibration).
- **Recognizing "every sound in the world"** — a deliberate limit: 3–5 categories prove the idea. As she put it: "It does not have to be a super-app… at least it should be a beginning."
