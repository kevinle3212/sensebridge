---
name: website-design
description:
    Use for any visual or UX design work on the public marketing site under
    website/ — layout, typography, color, hierarchy, motion, copy, components,
    responsive behavior, or a design review. Routes design execution to
    impeccable and design-direction to Anthropic's frontend-design skill, then
    hands review to ui-reviewer and accessibility. Not for the iOS app UI
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

# Website design — integration seam

SenseBridge gained a public marketing site (`website/`, static HTML/CSS, no
framework). This skill is the **router** that ties four capabilities together so
they complement rather than duplicate each other. It owns no design rules of its
own — it delegates, in order, and enforces the two guardrails the generic tools
do not know about.

## Division of labor (who owns what)

| Capability | Role | Where it lives |
| --- | --- | --- |
| **impeccable** | Execution + evaluation: production-grade design, the `craft`/`critique`/`audit`/`polish`/`typeset`/`layout`/… commands, AI-slop detection, the `website/` DESIGN.md/PRODUCT.md context and `.impeccable/` detectors | [.gemini/skills/impeccable/SKILL.md](../impeccable/SKILL.md) — already wired across every assistant surface |
| **frontend-design** (Anthropic, official) | Design *direction*: style/palette/font-pairing choices that escape generic AI defaults; a second, Anthropic-maintained opinion on visual identity. SwiftUI is a supported stack, so it also informs app-side identity | Global skill — `anthropics/skills` (`skills/frontend-design`), Apache-2.0. Enable via the Claude Code plugin or `npx -y skills add anthropics/skills --skill frontend-design --agent claude-code` |
| **ui-reviewer** | Reviews structure/consistency of the result (HIG for app; component/style reuse and interaction quality for web) | [.agents/agents/ui-reviewer.md](../../../.agents/agents/ui-reviewer.md) |
| **accessibility** | Screen-reader-first review — a first-class requirement for this site, not an afterthought. Wins any conflict | [.agents/skills/accessibility/SKILL.md](../../../.agents/skills/accessibility/SKILL.md) |

**Why not install "UI/UX Pro" (the ui-ux-pro-max npm package)?** Its capability
— style/palette/font-pairing generation and a design-system brief — is already
covered by impeccable (`palette.mjs`, the brand/product registers) plus the
official `frontend-design` skill. The npm package is an unofficial,
single-maintainer distribution that ships executable install scripts; adopting it
would add supply-chain risk for a capability we already hold. Its *method* (pick a
color strategy and font pairing deliberately, against the brand register) is
folded into the flow below. See [`docs/TOOLING.md`](../../../docs/TOOLING.md).

## Flow

1. **Direction first** for a new surface or identity question: consult
   `frontend-design` for style/palette/font-pairing direction, anchored to the
   existing tokens in
   [`.agents/context/DESIGN.md`](../../../.agents/context/DESIGN.md) and
   `.impeccable/design.json`. Identity-preservation wins — do not restyle away
   committed brand tokens.
2. **Execute / evaluate** with impeccable: invoke the matching command
   (`/impeccable craft|critique|audit|polish|typeset|layout|…`) on the `website/`
   target. impeccable's brand register and AI-slop tests carry the detail.
3. **Review** the result through ui-reviewer (structure/consistency) and the
   accessibility skill (screen-reader pass, contrast, focus, reduced-motion).
   Accessibility is a blocking gate for this site, not advisory.
4. **Gate** what the design tools cannot judge: convene the
   [council](../council/SKILL.md) skill before any hard-to-reverse design-system
   decision (replacing the token system, adopting a framework, changing the
   brand register); run the standard `/code-review` on the implementation diff;
   and run the project `security-review` skill when a change touches scripts,
   CSP/headers, external resources, or anything else with a trust boundary.
   frontend-design's mandate to "take one real aesthetic risk" never overrides
   the restraint and honesty doctrines or committed brand tokens — on conflict,
   the guardrails below win.

## Two guardrails the generic tools do not enforce

- **Honesty over hype.** Never imply the app is available: no download/CTA
  language (no CTA implies a download exists yet), no claimed availability date,
  no safety/navigation guarantee. Pre-launch status stays transparent. See
  [`.agents/context/DESIGN.md`](../../../.agents/context/DESIGN.md) and
  [`.agents/context/PRODUCT.md`](../../../.agents/context/PRODUCT.md).
- **Safety-framing carries to marketing copy.** Awareness-not-safety framing
  applies to the site's product description exactly as it does to spoken output —
  route product-claim copy through the
  [safety-framing-reviewer](../../../.agents/agents/safety-framing-reviewer.md).
  A humanizer/de-slop pass must never soften a required hedge.
