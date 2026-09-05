---
name: website-design
description:
    Use for any visual or UX design work on the public marketing site under
    website/ — layout, typography, color, hierarchy, motion, copy, components,
    responsive behavior, or a design review. Applies this project's two
    guardrails on top of the global design router. Not for the iOS app UI
    (that is SwiftUI — use ui-reviewer + accessibility directly) and not for
    backend or non-UI work.
user-invocable: true
argument-hint: "<design or review task on website/>"
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or forcing
  it. Note which tool you used and why. Never fall back to a tool the repository
  or user has explicitly prohibited.

# Website design — SenseBridge

**The routing lives in the global `design` skill**
(`~/.claude/skills/design/SKILL.md`): direction via `frontend-design`, execution
and evaluation via `impeccable`, review via `accessibility`, and `council` for
hard-to-reverse design-system decisions. Read it first.

This file adds only what is specific to `website/` — the project context those
generic tools cannot know, and two guardrails they do not enforce.

## Project context to anchor to

- Design tokens and brand register:
  [`.agents/context/DESIGN.md`](../../context/DESIGN.md) and
  `.impeccable/design.json`. Identity preservation wins — do not restyle away
  committed tokens.
- Product framing: [`.agents/context/PRODUCT.md`](../../context/PRODUCT.md).
- Review here goes through [ui-reviewer](../../agents/ui-reviewer.md) for
  structure and consistency alongside the global `accessibility` skill.
  **Accessibility is a blocking gate for this site**, not advisory.
- Trust-boundary changes — scripts, CSP or headers, external resources — also
  run this project's [security-review](../security-review/SKILL.md).

## Two guardrails the generic design tools do not enforce

- **Honesty over hype.** Never imply the app is available: no download or CTA
  language, no claimed availability date, no safety or navigation guarantee.
  Pre-launch status stays transparent. See `DESIGN.md` and `PRODUCT.md`.
- **Safety framing carries to marketing copy.** Awareness-not-safety applies to
  the site's product description exactly as it does to spoken output — route
  product-claim copy through
  [safety-framing-reviewer](../../agents/safety-framing-reviewer.md). A
  humanizer or de-slop pass must never soften a required hedge.

## Why not the "UI/UX Pro" npm package

Its capability — palette and font-pairing generation, a design-system brief — is
already covered by impeccable (`palette.mjs`, the brand registers) plus the
official `frontend-design` skill. The package is an unofficial, single-maintainer
distribution shipping executable install scripts; adopting it would add
supply-chain risk for a capability we already hold. Its *method* is folded into
the global router's flow. See [`docs/TOOLING.md`](../../../docs/TOOLING.md).
