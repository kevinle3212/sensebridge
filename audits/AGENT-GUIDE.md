# Audit Agent Guide

Instructions for AI agents (Claude Code, Cursor, Codex, Gemini, and others)
performing audits in this repository. Follow this so every audit is consistent,
verifiable, and honest about its limits.

Claude Code agents should invoke the `audit-refresh` skill
(`.agents/skills/audit-refresh/SKILL.md`), which automates the procedure below;
every reviewer agent under `.agents/agents/` also carries an "Audit Output"
block that routes its findings to the matching category here.

## Procedure

1. **Pick the category** that matches the audit focus (see `README.md`). Use
   `general` only for genuinely cross-cutting work.
2. **Generate the report** first, so metadata is captured against the exact
   commit you audit:

    ```bash
    audits/scripts/new-audit.sh <type> "short title"
    ```

3. **Inspect before changing anything.** Record every file, screen, or surface
   you examine under "Files Inspected." Prefer read-only search tools for the
   discovery pass.
4. **Record findings** in the "Issues Found" table with an honest severity:

    | Severity | Meaning                                                             |
    | -------- | ------------------------------------------------------------------- |
    | Critical | Confidently-wrong physical-world output, data leak, or broken flow  |
    | High     | Screen unusable via VoiceOver, blocked capability, blocking bug     |
    | Medium   | Degraded UX/latency, partial coverage, non-blocking correctness     |
    | Low      | Cosmetic, minor inconsistency, nice-to-have                         |
    | Info     | Observation, no action required                                     |

   Severity note specific to this project: a single confidently-wrong,
   safety-adjacent statement about the physical world (e.g. an unhedged "it is
   clear ahead") is the highest-severity class of bug here — treat it as
   Critical even when nothing crashes. See `docs/safety-framing.md`.
5. **Fix what is realistic in scope**, keeping changes surgical (see root
   `CLAUDE.md`). Log each fix under "Fixes Applied" and list touched files under
   "Files Modified."
6. **Verify.** Run the relevant gates and paste real output under "Verification
   Performed":
    - App: `xcodebuild build`, `xcodebuild test` (or `swift build` /
      `swift test` for SPM packages), plus a manual VoiceOver pass of any
      changed screen.
    - Accessibility: Xcode Accessibility Inspector audit; zero unlabeled
      interactive elements is a hard gate.
7. **Be honest about verification limits.** State plainly what could not be
   verified — e.g. "not tested on a physical device; only the iOS Simulator was
   available" or "VoiceOver behaviour verified in Simulator, not with a real
   blind tester." Never imply a device, an assistive technology, or a human
   tester was exercised when it was not. The single validation that counts —
   a blind person using it eyes-free and finding it useful — is almost never
   something an audit can claim; say so.
8. **Do not claim files are locked.** Integrity is enforced by review
   (CODEOWNERS + branch protection), not by the filesystem.

## Consistency rules

- One report per audit run; never overwrite a prior report. Supersede it with a
  new report that links back.
- Keep reports Markdown-clean (mirror `logs/` formatting conventions).
- Use UTC timestamps (the generator does this).
- Reference issues by their table number throughout the report.
- Wrap all paths, commands, and identifiers in backticks.

## Prompt snippet (reusable)

> Perform a `<type>` audit of SenseBridge. Generate a report with
> `audits/scripts/new-audit.sh <type> "<title>"`, inspect the relevant surfaces
> before modifying anything, record findings with honest severities, apply only
> surgical fixes, run the verification gates (build, tests, VoiceOver pass), and
> paste real command output. State explicitly what you could not verify —
> especially whether a real device or a blind tester was involved. Do not claim
> any file is locked.
