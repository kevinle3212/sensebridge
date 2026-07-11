---
name: accessibility
description:
    Use when auditing or changing any screen, control, spoken output, or
    navigation — the core quality bar for SenseBridge. Covers VoiceOver,
    Dynamic Type, contrast, focus management, and the rotor.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If the scope or expected outcome is ambiguous, interview the user with focused
questions before making changes. State assumptions and confirm them first.

# Accessibility

The app being usable eyes-free **is the product**, not a quality layer. Run this
skill whenever you touch UI, spoken output, alerts, or navigation. It pairs with
the [accessibility-reviewer](../../agents/accessibility-reviewer.md) agent.

## Hard gates (blocking)

- **Zero unlabeled interactive elements.** Every control has a meaningful
  VoiceOver label ("Read document", not "button").
- **Correct traits** so the rotor works (buttons, headers, adjustable).
- **Focus is managed** after every action — move VoiceOver focus to the result
  or post an announcement; never strand the user.
- **Async results announce themselves** (`UIAccessibility.post` / SwiftUI
  `AccessibilityNotification`).

## Also verify

- Dynamic Type honoured (no hardcoded font sizes); layout survives the largest
  text size without clipping.
- Contrast sufficient; no meaning in colour alone; Increase Contrast supported.
- Reduce Motion and Reduce Transparency respected.
- No custom gestures that conflict with VoiceOver's standard gestures.

## Validation

- Xcode **Accessibility Inspector** audit on each changed screen.
- **Manual VoiceOver pass**, eyes closed or screen-curtained.
- State honestly whether a real device or a blind tester was involved — Simulator
  VoiceOver is not the same as validation by a blind user, which is the only test
  that fully counts.

Persist findings via the `audit-refresh` skill under `audits/accessibility/`.
