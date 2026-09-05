# admin — single-owner dashboard

A small Next.js app that shows project telemetry in one place: WakaTime coding
activity, Sentry issue health, and what the local dev tooling can honestly
report. **Not part of the product**, not deployed with `website/`, and not
something a visitor ever reaches.

## Scope, and what is deliberately absent

The dashboard is a **read-only view over data that already exists elsewhere**.
It has no database, no write path, and no background jobs — every tile is a
live read behind a cache. That is the whole design: adding a store would make
this a second system to operate, and nothing here is worth operating.

Not included, on purpose:

- **No TODO/session-log surfacing.** `TODO.md` and `sessions/` are read where
  they live, in the editor, by the same person who writes them.
- **No CI status tile.** GitHub's own Actions tab is better at it and is one
  click away.
- **No writes of any kind.** Every token this app holds is read-scoped.

## Running it

```sh
cd admin
npm install
npm run dev                    # http://localhost:4331
```

Any username works at the Basic-auth prompt; only the password is checked.

### Environment

Create `admin/.env.local` by hand. `tools/check-sensitive-files.mjs` refuses to
publish any `.env*` file unless its exact path is listed in that script's
`NAME_CHECK_EXEMPT` allowlist — the root and `website/` examples are; this
directory's deliberately is not, because the table below documents the same
information without a second file to keep in sync.

| Variable | Required | What it is |
| --- | --- | --- |
| `ADMIN_PASSWORD` | Yes | 16 characters or more. Shorter than that, or unset, and every route serves 503. |
| `SENTRY_READ_TOKEN` | Sentry tile | Read-scoped token (`event:read`, `project:read`, `org:read`). |
| `SENTRY_ORG` | Sentry tile | Organization slug. |
| `SENTRY_PROJECT` | Sentry tile | Project slug. |
| `WAKATIME_API_KEY` | WakaTime tile | Falls back to `~/.wakatime.cfg` when unset. |

A tile whose variables are missing renders "unavailable" rather than failing
the whole page.

## Why it runs locally

Two of the three tiles read files that only exist on the owner's machine:

| Tile | Source | Works on a host? |
| --- | --- | --- |
| Sentry | `https://sentry.io/api/0/` with a read-scoped token | Yes |
| WakaTime | `WAKATIME_API_KEY`, else `~/.wakatime.cfg` | Yes, with the env var set |
| Dev tooling | `rtk gain --format json`, `~/.claude/.caveman-*`, a `grep` over the repo | **No** |

The tooling tile is the local-only one. Deploying this app would need a sync
step — a cron pushing an aggregate somewhere the host can read — and that sync
is not built, because a dashboard that only the owner can see is already best
run on the owner's laptop. If it ever is deployed, the tooling tile fails soft
and renders "unavailable" rather than breaking the page.

## What each tile will and will not claim

Honesty here is the same rule the product follows: **report what is measured,
never a number that was not.**

- **rtk** has a real machine-readable figure (`rtk gain --format json`). Shown
  as **lifetime** totals, which is what that command returns — labelling them
  as this project's would be a fabrication.
- **caveman** has **no savings data on disk.** The plugin writes
  `.caveman-active` (current level) and `.caveman-mode-log.jsonl` (one row per
  level change). There are no token counts in either, so the tile shows the
  level and nothing more. An earlier plan for this dashboard assumed a
  `.caveman-history.jsonl` with `output_tokens` and `est_saved_tokens`; that
  file does not exist (checked 2026-08-12).
- **ponytail** has no per-repo savings figure at all — `ponytail-gain` prints
  fixed benchmark medians, not measurements. The tile shows the one real
  number: how many deliberate `ponytail:` shortcut markers are in the tree.

## Security

- `ADMIN_PASSWORD` gates every route including the API handlers, in
  `proxy.ts`, and **fails closed**: unset or under 16 characters serves
  503 rather than running open.
- The Sentry token must be read-scoped (`event:read`, `project:read`,
  `org:read`). Never `project:write` or `org:admin`.
- No secret is prefixed `NEXT_PUBLIC_`, and none is read outside a server
  route — that is why the page fetches its own API handlers rather than
  calling upstreams directly.
- Responses are `private, no-store`; a CSP, `frame-ancestors 'none'`, and
  `noindex` are set in `next.config.mjs` and `app/layout.tsx`.
- Upstream calls have an 8-second timeout and **no retries**. A rate-limited
  API is not something to hammer on a page refresh.
