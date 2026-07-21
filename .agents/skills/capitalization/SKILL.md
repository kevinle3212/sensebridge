---
name: capitalization
description:
    Use when writing or reviewing any heading, title, label, button, status
    chip, or full-sentence copy — determines whether it takes Title Case or
    sentence case, and how to apply each correctly.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If a string's role is ambiguous (heading vs. prose, label vs. sentence), infer
it from context (surrounding Markdown structure, UI element type) and state the
assumption rather than blocking. Only ask when the same string is genuinely used
both ways and the two rules would produce different output.

# Capitalization

Canonical rule source for `AGENTS.md` → "UI and copy conventions": Title Case
for non-sentence labels, sentence case for full sentences. This skill is the
single place that spells out *how* — other files link here instead of
restating the algorithm.

## Which style applies

| Style | Applies to |
| --- | --- |
| **Title Case** | The document title only — the single `#` (H1) at the top of a file — plus UI labels, buttons, nav items, status chips, and table column headers |
| **Sentence case** | Every section heading below the title (`##` through `######`), body prose, list items that are full sentences, spoken/caption/haptic strings, error and empty-state messages, alt text, commit subjects, PR titles |

This is the established, near-universal convention already in this repo's ~700
existing headings — confirmed by audit, not a new rule: H1 is the one Title
Case heading per file; everything under it reads as sentence case. Don't
Title Case a `##`+ heading just because it "looks like a title."

**Named exception — fixed section labels.** `Tool Fallback`, `Clarify Before
Acting`, and `Audit Output` are standardized boilerplate headers reused
verbatim across every skill and agent file. Treat them as fixed labels, not
prose headings — leave them Title Case. Don't invent new ones; if a genuinely
new cross-cutting boilerplate section is needed, ask before deciding its case.

**Strict headers — never re-case.** Some `#` titles are literal identifiers,
not prose, and casing rules never apply to them:

- Slash-command files (`.claude/commands/*.md`, and equivalents under
  `.codex/`, `.github/`, etc.) whose H1 is the command's own invocation name
  — `# cleanup-commit`, `# docker-clean`, `# handoff`. The heading *is* the
  identifier; changing its case would misrepresent the command name. (A
  command file with a genuine descriptive title, like
  `# Security Review — SenseBridge`, is ordinary prose and follows the normal
  H1 Title Case rule — only literal command-name headers are exempt.)
- Template placeholders (`audits/templates/audit-template.md`'s `# {{TITLE}}`)
  — the literal token gets substituted at generation time; there's no prose
  to case.
- Filename-as-title headers with no prose content (`# GAPS.md`,
  `# PROJECT_OVERVIEW.md`) — nothing to case; leave as the bare filename.

When in doubt whether a header is "strict" (an identifier) or a prose title,
check whether re-casing it would change what a human or tool needs to type to
invoke/reference it — if yes, it's strict; leave it alone.

**Named exception — numbered top-level chapters.** In `CLAUDE.md`/
`CLAUDE.template.md` and `docs/planning/*` (the project's planning series)
(`## 1. Executive Review`, `## 19. Open Source Strategy`, ...), a
plain-numbered `##` heading functions as a chapter title, not a narrative
sub-heading — Title Case, same as an H1. This
does **not** extend to letter-prefixed sub-items in the same documents (`###
B1. Getting the app onto devices`, `### C1. Why Apache 2.0 for SenseBridge's
own code`, GAPS.md's `### M2 — ...`) — those stay sentence case; only the
first word after the number/dash is capitalized because it opens the clause,
not because the whole heading is titled.

**Named exception — audit/report templates.** `audits/templates/audit-template.md`
uses Title Case for its section labels (`## Files Inspected`, `## Issues
Found`, ...) because they're fixed form fields instantiated into every
generated audit report, not prose headings. Don't sentence-case these.

If one string is reused in both a heading and a sentence (e.g., a feature name
inside a paragraph), keep its own casing as a proper noun in both places —
proper nouns are never re-cased.

## Title Case algorithm

1. Capitalize the **first and last word**, always, regardless of what it is.
2. Capitalize every **major word**: nouns, pronouns, verbs (including short
   ones — "Is", "Be", "Are"), adjectives, adverbs, subordinating conjunctions.
3. Lowercase every **minor word** — articles (`a`, `an`, `the`), coordinating
   conjunctions (`and`, `but`, `or`, `nor`, `for`, `so`, `yet`), and
   prepositions (`of`, `in`, `on`, `to`, `for`, `with`, `from`, `at`, `by`,
   `up`, `off`, `via`, ...) — **unless** rule 1 makes it the first or last
   word, or it's the second half of a phrasal verb where it carries meaning
   (`Set Up`, `Sign In`, `Log Out` — capitalize `Up`/`In`/`Out` there).
4. Capitalize the first word after a colon or em dash (it starts a new
   clause): `Setup: Environment Variables`, not `Setup: environment Variables`.
5. Hyphenated compounds: capitalize the first element always; capitalize later
   elements too unless the element is a minor word per rule 3
   (`On-Device Processing`, `Follow-Up Steps`, but `Opt-in Flow` only if "in"
   reads as a minor preposition there — prefer `Opt-In Flow` since it's a
   phrasal verb per rule 3's exception).
6. Never re-case: acronyms, proper nouns, code spans, or file/identifier names
   — copy them verbatim regardless of position.

**Worked examples** (H1 titles and UI labels — never `##`+ headings)

- `# Accessibility Standards for Contributors` — "for" lowercase (minor
  preposition), rest capitalized.
- `# Safety Framing: Awareness, Not Safety` — "Not" capitalized after the
  comma (major word), colon starts a new clause per rule 4.
- `# Tooling — Global vs. Project Decision Matrix` — "vs." lowercase (minor),
  rest capitalized.
- `Set Up` (button label) — "Up" capitalized, phrasal verb per rule 3's
  exception.
- `What Is SenseBridge?` (UI label) — "Is" capitalized (verb), "SenseBridge"
  untouched (proper noun), question mark kept.

## Sentence case algorithm

1. Capitalize only the **first word** and any **proper nouns / acronyms**
   inside the sentence (`VoiceOver`, `OCR`, `HIG`, `ANE`, `TestFlight`,
   `SenseBridge`, `Swift`, `SwiftUI`, `Xcode`, `iOS`, `macOS`, `GitHub`).
2. Everything else — including words that would be capitalized in a Title
   Case heading — stays lowercase.
3. Full grammar applies: correct punctuation, no sentence fragments presented
   as complete sentences, consistent terminology, no comma splices.
4. Spoken/caption/haptic strings additionally follow the awareness-not-safety
   hedging rule in `docs/SAFETY-FRAMING.md` — that framing constraint is
   independent of casing and is not relaxed here.

### Worked examples

- `## The three doctrines (non-negotiable)` — only "The" capitalized; a `##`
  heading, not the H1 title.
- `### Phase 3: the deaf-user dimension (post-MVP)` — "the" stays lowercase
  even right after the colon — sentence case does not re-capitalize after
  punctuation the way Title Case does.
- "VoiceOver users hear a hedge before every spoken claim." — "VoiceOver"
  preserved mid-sentence.
- "Looks like a person is nearby." (spoken output) — sentence case, hedged
  per the safety-framing doctrine, not an assertion of certainty.

## Acronyms and proper nouns (preserve exactly, any position)

`VoiceOver`, `OCR`, `HIG`, `ANE`, `TestFlight`, `SenseBridge`, `Swift`,
`SwiftUI`, `Xcode`, `iOS`, `macOS`, `API`, `CI`, `CI/CD`, `PR`, `URL`, `FAQ`,
`SDK`, `MIT`, `AGPL`, `WCAG`. Extend this list rather than guessing casing for
a new acronym — check how the project already spells it (`rg` for the term)
before introducing a new one.

## Non-negotiables regardless of style

- Never alter text inside backticks, code fences, or file paths — copy
  verbatim.
- Never re-case a proper noun to fit the surrounding pattern.
- The [log-markdown](../log-markdown/SKILL.md) skill's "sentence-case
  headings" rule for `logs/` is consistent with the default rule above, not a
  special case — it exists there mainly to rule out ALL-CAPS or ad hoc casing
  in throwaway run notes.

## Validation

When auditing existing copy, flag a heading or label only when it clearly
violates the algorithm above — not for stylistic taste. When unsure whether a
word is "major" (adverb) or "minor" (preposition) in context, prefer leaving
it as-is over a low-confidence rewrite, and note the ambiguous case instead of
guessing silently.
