# SenseBridge — project context for AI agents

Loaded by every BMM skill on activation. Scope: the **unobvious** rules an
agent gets wrong by default. Everything obvious from reading the code is
deliberately omitted. Authoritative sources, in order:
[`AGENTS.md`](../AGENTS.md), [`CLAUDE.md`](../CLAUDE.md),
[`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md).

## What this product is

An on-device iOS accessibility app that describes the physical world to blind
and low-vision users. The people it serves cannot see the screen, so the
audio, haptic, and caption layers *are* the product — not a presentation of it.

## The four doctrines

### 1. Awareness, not safety — highest-severity surface

Every spoken string, caption, and haptic hedges. Never assert unearned
certainty about the physical world.

- ✅ "There may be a step ahead." / "Looks like a door on your right."
- ❌ "The path is clear." / "It is safe to cross." / "There are no obstacles."

An LLM's default register is confident assertion. That default is a defect
here: a confident wrong description can walk someone into traffic. When
uncertain, say less, and hedge what you do say. Route any change touching
spoken output, alerts, captions, or haptics through the
`safety-framing-reviewer` agent.

### 2. Serverless and on-device

No backend, no accounts, no telemetry by default. Never introduce a network
round-trip for perception or reasoning. Anything leaving the device needs
explicit, revocable user consent **and** a privacy-doc update. Adding an API
call to "improve accuracy" is a doctrine violation, not an optimization.

### 3. Protocol seams

`SensingSource` → perception services → `Reasoning` → `RenderTarget`.
Dependencies point inward. Reasoning logic stays pure and
framework-independent — never couple it to a specific capture or render
framework.

### 4. Main thread stays free

No perception or model inference on the main thread. The UI must remain
responsive to VoiceOver *during* processing; a blocked main thread is a
screen reader that stops answering, which is worse than a slow app.

## Blocking gates — pass/fail, not aspirational

- **Zero unlabeled elements** on every screen. This is binary. "95% labeled"
  is a failure.
- Build passes (`xcodebuild build`; `swift build` where a package target
  exists).
- Tests pass. E2E floor is **three per feature**: happy path, error path,
  edge case.
- Safety-framing review for any physical-world output.
- Model-license clearance — **AGPL and Apple's `apple-amlr` are hard
  blockers**, not warnings.

## Traps that look like success

- **A simulator build proves nothing.** ARKit, LiDAR depth, Apple
  Intelligence, haptics, and the camera all produce *nothing* in a simulator,
  so most of this app cannot run there. Build for the device even when the
  simulator build passed — signing and arm64 are only exercised on a device
  destination.
- **A green CI pipeline is not validation.** CI cannot prove on-device
  latency, battery, thermal behavior, or blind-tester acceptance. State
  plainly which gates a machine verified and which still need device and
  human validation. Never let green CI imply the app was validated by the
  people it is for.
- **"Done" requires the owner can try it.** After any change to `app/`,
  rebuild and install to the device (`npm run app:install`) before reporting
  done. Doc-only and comment-only changes are exempt. The phone must be
  unlocked or the developer disk image will not mount — say that rather than
  reporting a bare failure.

## Hard stops

- **Never run `git` or `gh` autonomously.** Permission is per-command and
  per-session. Installing to the owner's own device is *not* owner-gated;
  every git/gh command still is.
- **Never commit to `main`.** Branch `feat/`, `fix/`, or `chore/`.
- **Never edit anything under `legal/`** without explicit owner approval.
- **Never start a long-running local server unless asked** — no `npm run
  dev`, no `astro preview`. Build to verify, then hand over the command.

## Conventions worth knowing

- `website/` is a *separate design surface* from the app: pre-launch, no CTA
  implying a download exists, honesty over hype. Its context lives in
  `.agents/context/`, not in `website/`.
- Prefer Serena's symbol tools over raw file reads on code, and let RTK's
  hook compact shell output — run covered commands bare rather than wrapping
  them in a pipeline.
- Update the nearest authoritative doc in the same change that alters
  behavior. Stale docs are worse than none.
