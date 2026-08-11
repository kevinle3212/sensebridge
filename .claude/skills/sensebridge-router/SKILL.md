---
name: sensebridge-router
description: "Route requests to the canonical SenseBridge skills for Swift concurrency, accessibility, safety framing, security, dependency and model-license audits, BMAD planning, website design and SEO, Stripe, testing, and maintenance. Use when a matching local skill is needed and no direct symlink exists yet in .claude/skills/."
---

# Canonical skill router

Read `.agents/manifest.json`, select the one matching canonical skill under
`.agents/skills/`, and follow it. Do not duplicate or amend canonical policy in
this adapter.

Every registered skill is also symlinked directly into `.claude/skills/` for
native autoload — this router exists only as a fallback for a skill added to
the manifest before its symlink is created.
