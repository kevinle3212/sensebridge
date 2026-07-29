# GitHub repository rulesets (settings-as-code)

JSON mirrors of this repo's [Rulesets](https://github.com/kevinle3212/sensebridge/rules)
(Settings → Rules → Rulesets). **These files are not auto-applied** — GitHub
has no "read ruleset config from the repo" mechanism, so this directory only
prevents "what does `main`'s protection actually require" from living solely
in a web UI or in `TODO.md` prose. Per `CLAUDE.md`, applying or editing a live
ruleset is a `gh api` write and stays owner-run.

| File | Status | What it protects |
| --- | --- | --- |
| [`main-required-checks.json`](main-required-checks.json) | **Live** — mirrors ruleset id `19721689`, created 2026-07-24 | Blocks deletion/force-push on `main`; requires 7 status checks to pass (not strict — doesn't require branches up to date) |
| [`protect-main.json`](protect-main.json) | **Proposed, not yet applied** | The fuller spec from `TODO.md`'s "Owner actions pending" section: adds require-PR-before-merge (squash only, 0 required approvals — solo-maintained, see `CODEOWNERS`), linear history, and a different 7-check list scoped to checks that run on every PR (excludes `website/`-path-filtered and AI-first-pass checks — see the header comment history in `TODO.md` for why) |

## Keeping `main-required-checks.json` honest

This file only stays accurate if it's re-synced after a live edit. Check for
drift:

```sh
gh api repos/kevinle3212/sensebridge/rulesets/19721689 \
  --jq '{name, target, enforcement, bypass_actors, conditions, rules}' \
  > /tmp/live-ruleset.json
diff <(jq -S . .github/rulesets/main-required-checks.json) <(jq -S . /tmp/live-ruleset.json)
```

## Applying `protect-main.json`

Not yet created on GitHub — see `TODO.md`'s "Owner actions pending" section
for the full prerequisite checklist (repo must be public — it already is) and
UI-equivalent steps. Once approved:

```sh
gh api --method POST repos/kevinle3212/sensebridge/rulesets --input .github/rulesets/protect-main.json
```

To update an existing ruleset instead of creating one, use `--method PUT
repos/kevinle3212/sensebridge/rulesets/<id>`.
