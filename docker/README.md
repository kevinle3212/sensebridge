# docker/

Container setup for `website/`, the only part of this repo that deploys
anywhere (the app is on-device, serverless — see the repo's `CLAUDE.md`).

## Layout

- `Dockerfile` — two stages: `node:22-alpine` builds the Astro static site,
  `nginxinc/nginx-unprivileged:alpine` serves `dist/`. Both stages pinned to
  digest (kept current by the `docker` Dependabot ecosystem entry).
- `Dockerfile.dockerignore` — allowlists `website/` (minus its own
  `node_modules`/`dist`/`.astro`) plus `nginx.conf.template`. Everything else
  in the repo root — including `app/`, `.git`, `legal/` — never reaches the
  build context.
- `nginx.conf.template` — rendered to `/etc/nginx/conf.d/default.conf` at
  container start, substituting `$PORT` from the environment (the base
  image's own `20-envsubst-on-templates.sh` entrypoint script does this).
- `docker-compose.yml` — local-only: `dev` (hot-reload Astro dev server) and
  `web` (the production image, as deployed). Not used by Railway.

## Build context

The build context is the **repo root**, not this directory — the Dockerfile
`COPY`s from `website/...`. Building directly:

```sh
docker build -f docker/Dockerfile -t sensebridge-website .
docker run -p 8080:8080 sensebridge-website
```

Or via Compose (also repo-root context, resolved from this file's location):

```sh
docker compose -f docker/docker-compose.yml up dev   # http://localhost:4321, hot reload
docker compose -f docker/docker-compose.yml up web   # http://localhost:8080, prod image
```

## Security posture

- Both base images pinned by digest, not mutable tag.
- Runtime stage runs as `nginx` (uid 101), never root — no `npm install` in
  the final image at all, so no third-party package (and its transitive
  dependency tree) ships in the runtime image's attack surface.
- `Dockerfile.dockerignore` is an allowlist: only `website/` and the nginx
  template can ever enter the build context.
- No secrets in the image. `ELEVENLABS_API_KEY` (see `website/README.md`'s
  Read-aloud controls) is a local, generation-time-only secret — it produces
  `website/public/audio/main.mp3` ahead of time; only that output file ships,
  never the key.

## Railway deploy

Railway builds `docker/Dockerfile` directly via `railway.toml` at the repo
root. The service's **Root Directory must be the repo root** (Railway
dashboard → Settings → Source) — not `website` — since the build context has
to include both `docker/` and `website/`. `dockerfilePath` in `railway.toml`
is relative to that root. Full first-time setup: see `website/README.md`'s
Deployment section.

Railway deploys itself: its GitHub App watches `main` and rebuilds on every
push, with no GitHub Actions involvement in the deploy step itself.

### Preview environment

A second Railway environment, `preview`, exists for previewing in-flight
`website/` changes — [`sensebridge-preview.up.railway.app`](https://sensebridge-preview.up.railway.app),
linked from the root `README.md`. It auto-deploys via
[`.github/workflows/railway-preview-deploy.yml`](../.github/workflows/railway-preview-deploy.yml)
on every push to **any branch except `main`** that touches `docker/**`,
`website/**`, or `railway.toml` — a GitHub Actions workflow calling
`railway up`, not Railway's own native branch watch, so it never touches
`production`'s existing GitHub-App-based auto-deploy on the same service.
Needs the `RAILWAY_TOKEN` repository secret (a Railway *project* token, not a
personal one — see `TODO.md` for the full walkthrough) or the job fails
closed.

To redeploy by hand instead of waiting for CI:

```sh
railway up --service sensebridge --environment preview --ci
```

`railway.toml`'s `[deploy]` also sets `healthcheckPath = "/"` with a 30s
timeout and a 15s `overlapSeconds` — Railway won't cut traffic over to a new
deployment (or stop the old one) until that path answers, so a container
that starts but serves broken output never goes live, and the switch itself
is zero-downtime. This is a platform-level check on top of, not instead of,
the Dockerfile's own `HEALTHCHECK`, which only `docker inspect`/Compose/the
CI job below can see.

### CI check

`.github/workflows/railway-deploy-check.yml` builds `docker/Dockerfile` and
smoke-tests the running container (waits for the `HEALTHCHECK` to report
`healthy`, then `curl`s `/`) on every push/PR touching `docker/**`,
`website/**`, or `railway.toml`. It exists so a Dockerfile- or
dependency-classification break (see "Build-time dependencies" below) is
caught before merge, not discovered after Railway's own auto-deploy fails in
production — which is exactly what happened once already: a Root
Directory/`railway.toml` location mismatch merged without this check reaching
that build path.

### Build-time dependencies

Stage 1 runs `npm ci --omit=dev`, not a plain `npm ci` — most of
`website/`'s `devDependencies` are lint/format/test/audit tooling never
touched by `astro build`, but two are build-time requirements despite the
"dev" label and live in `dependencies` instead:

- `@astrojs/react` — imported directly by `astro.config.mjs`.
- `react-scan` — imported by an `import.meta.env.DEV`-gated `<script>` in
  `BaseLayout.astro`; Vite still resolves the import before dead-code-
  eliminating the `false` branch, so the package must be physically
  installed even though it never ships to production.

If a future change adds a new devDependency import anywhere Astro's build
touches (including inside a dev-only conditional), the CI check above will
catch the resulting build failure — move that package to `dependencies` the
same way.

### CLI commands

Railway CLI is available two ways: install it globally
(`npm install -g @railway/cli` or `brew install railway`) for use anywhere on
the machine, or use the project-local devDependency (already in
`website/package.json`, installed via `npm install` inside `website/`) so
`npm run railway:*` scripts work without a global install. Both resolve to
the same CLI; the global one is what a fresh contributor is more likely to
already have, the local one pins an exact version for this repo.

```sh
npm run railway:status        # linked project/service/environment + latest deployment status
npm run railway:logs           # last 100 log lines from the latest deployment
npm run railway:logs:build      # build logs from the latest deployment (add --latest to include in-progress builds)
npm run railway:redeploy       # pull latest main and redeploy — the only way to get a fix live
                                # after a push, since Railway does not redeploy automatically on
                                # its own once the *previous* deploy already failed
```

Or with the CLI directly (`railway --help` for the full command list):
`railway logs --build <deployment-id>` for a specific deployment's build log,
`railway logs --http` for request logs, `railway status --json` to inspect
the linked service's full config (builder, `rootDirectory`, restart policy)
as Railway currently sees it — the fastest way to confirm `railway.toml` is
actually being read rather than silently falling back to Railpack.

**Known accepted risk:** `@railway/cli`'s `tar` dependency (`tar@6.2.1`) has
a high/critical `npm audit` finding (path traversal / symlink CVEs, fixed
only in `tar@7`, which breaks `@railway/cli`'s postinstall via an ESM
default-export mismatch — no patched `6.x` release exists). Accepted because
it's dev-only: the Dockerfile's `--omit=dev` means it's never installed in
the image Railway actually builds and serves, and it's not a `dependencies`
entry a consumer of this repo would inherit. Re-evaluate if `@railway/cli`
ships a fix.
