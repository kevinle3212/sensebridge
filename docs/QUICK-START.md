---
title: Quick Start
---

# Quick Start

> Status: pre-launch. There is no App Store or TestFlight build yet — "getting
> the app on your device" today means building it from source with a free
> Apple ID. See [`docs/DISTRIBUTION.md`](DISTRIBUTION.md) for why, and when
> that changes.

This page is the fast path: a few minutes from clone to a running app on your
own iPhone. For the full toolchain reference, troubleshooting, and the
signing details, see [`docs/ENVIRONMENT.md`](ENVIRONMENT.md); for how
distribution to *other people's* phones works, see
[`docs/DISTRIBUTION.md`](DISTRIBUTION.md).

## What you need

- A **Mac** with a current **Xcode** (Swift 6 toolchain, iOS 26 SDK+).
- A **personal Apple ID** — free, not the paid Developer Program.
- An **iPhone 15 Pro or later** (Apple Intelligence support is required for
  the on-device models). The simulator runs the app but can't exercise the
  camera, microphone, or LiDAR features described below.

## Get it running

1. Clone the repo and open the project:

   ```sh
   git clone https://github.com/kevinle3212/sensebridge.git
   cd sensebridge
   open app/SenseBridge.xcodeproj
   ```

2. In Xcode: **Settings → Accounts → add your personal Apple ID** (not the
   paid Developer Program).
3. Select the `SenseBridge` target → **Signing & Capabilities** → pick your
   personal team from the dropdown. `app/project.yml` already sets
   `CODE_SIGN_STYLE: Automatic`, so Xcode fills in the rest.
4. Plug in your iPhone, select it as the run destination, and hit **Run**.
   First launch: on the phone, go to **Settings → General → VPN & Device
   Management** and trust your developer certificate.
5. **Heads up:** a free personal-team signature expires after 7 days —
   re-run from Xcode to re-sign. No API keys or paid account needed for this
   path.
6. Optional but recommended once, from the repo root:

   ```sh
   scripts/setup.sh
   ```

   Checks your toolchain and enables the repo's git hooks (secret scanning,
   lint, commit-message and workflow-file checks) — only relevant if you
   plan to contribute code, not to just run the app.

That's it — the app should now be on your phone. Turn on **VoiceOver**
(Settings → Accessibility → VoiceOver, or triple-click the side button if
you've set up that shortcut) before using it; SenseBridge is designed
VoiceOver-first. Keep reading below for what each screen actually does.

---

# Usage Guide

This section tracks **what the app actually does right now**, not the
long-term vision — see [`docs/ROADMAP.md`](ROADMAP.md) for where features are
headed. It changes as the project progresses; if you're implementing a
feature described here as "scaffold only," update its row in the table below
in the same change (see [Keeping this guide current](#keeping-this-guide-current)).

## First launch

SenseBridge opens straight to its one main screen — no onboarding, no
sign-in (there are no accounts; see [`docs/PRIVACY.md`](PRIVACY.md)). The
camera and microphone permission prompts appear the first time a feature
that needs them actually runs, not on launch.

## Navigating the app

The home screen is a flat, single-level list — not a grid or a tab bar — so
a VoiceOver user reaches every mode with simple up/down swipes instead of
hunting through nested menus:

| Screen | VoiceOver label | What it's for |
| --- | --- | --- |
| Read | "Read document" | Reads printed text aloud from a photo |
| Identify | "Identify object" | Names what a photo is mostly likely of |
| Describe | "Describe scene" | Composes a hedged, one-sentence description of a photo |
| Awareness | "Obstacle awareness" | Cautious alerts about what may be nearby, using LiDAR |
| Sounds | "Sound alerts" | Announces recognized sounds nearby |
| Settings | "Settings" | Change the app's display language |

Every control on every screen already carries a VoiceOver label and hint —
that's a hard project gate (zero unlabeled elements), independent of whether
the feature behind it is fully wired yet. See
[`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md).

## Feature status

Each capture-based feature (Read, Identify, Describe, Awareness, Sounds) has
a real screen, a real button, and a real accessibility label today — what's
still landing is the pipeline behind the button (camera/microphone/LiDAR
capture → on-device model → spoken result). Settings is the one fully
functional feature end to end.

| Feature | Today | What happens once wired |
| --- | --- | --- |
| Read | UI scaffold — screen and button exist, capture pipeline not yet wired | Captures a photo, runs on-device OCR, reads any text aloud |
| Identify | UI scaffold — screen and button exist, capture pipeline not yet wired | Captures a photo, names the most likely object, speaks a hedged result |
| Describe | UI scaffold — screen and button exist, capture pipeline not yet wired | Captures a photo, composes and speaks a cautious one-sentence scene description |
| Awareness | UI scaffold — screen, safety disclaimer, and button exist, LiDAR pipeline not yet wired | Gives cautious, probabilistic proximity alerts — explicitly **not** a navigation or safety device, see [`docs/SAFETY-FRAMING.md`](SAFETY-FRAMING.md) |
| Sounds | UI scaffold — screen and button exist, listening pipeline not yet wired | Listens for recognizable nearby sounds and announces them |
| Settings — Language | **Functional today** | Switch between System, English, Español, and Tiếng Việt; persists across launches |

Camera and microphone permission strings are already configured
(`app/project.yml`), so the system prompt is ready to appear the moment a
pipeline starts actually requesting the sensor — you won't see it yet on a
fresh install.

## Obstacle Awareness — read this before using it

The Awareness screen states this before the button, and VoiceOver announces
it before anything else on that screen: obstacle awareness is **not** a
safety or mobility device. It does not replace a cane, a guide dog, or
orientation-and-mobility training. Once wired, it will give cautious,
probabilistic alerts only — see
[`docs/SAFETY-FRAMING.md`](SAFETY-FRAMING.md) for the full doctrine behind
this, which governs every spoken/caption/haptic string in the app.

## Keeping this guide current

The Feature status table above is the living source of truth for "what does
the app do today" — update it in the same change that wires a feature's
pipeline (per [`AGENTS.md`](../AGENTS.md#docs-sync-per-change)), not as a
follow-up. If a feature moves from "UI scaffold" to functional, flip its
"Today" cell and, if the interaction changes (new settings, new permission
prompt, multi-step flow instead of one capture button), update the relevant
row's description too. Don't let this page describe a feature as working
when it isn't — that's the one thing this project treats as a hard rule, see
[`docs/SAFETY-FRAMING.md`](SAFETY-FRAMING.md) and the honesty framing in
[`README.md`](../README.md).

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
