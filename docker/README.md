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
