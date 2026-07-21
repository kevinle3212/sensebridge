# Static marketing site — built with Astro in stage 1, served by nginx
# (unprivileged, non-root) in stage 2. See docker/README.md for the full
# local-dev and Railway deploy flow.
#
# Build context is the repo root, not this docker/ directory — Railway's
# dockerfilePath (railway.toml) points here from a root-directory build, and
# COPY paths below are written relative to that root.
#
# Both stages are pinned to manifest-list digests, not mutable tags — same
# supply-chain rationale as the GitHub Actions pins in
# .github/workflows/security.yml. Dependabot's `docker` ecosystem entry
# (.github/dependabot.yml) opens a PR to bump these digests whenever a new
# image is published, so they never need a manual registry lookup.
FROM node:22-alpine@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2 AS build

WORKDIR /app

COPY website/.npmrc website/package.json website/package-lock.json ./
RUN npm ci

COPY website/ .
RUN npm run build

# nginx-unprivileged, not plain nginx: runs as uid 101 (nginx) on port 8080
# out of the box, so the runtime stage never touches root and never installs
# an npm package — the previous `npm install --global serve@14` pulled an
# unpinned, unlocked dependency tree into the final image at build time,
# which was the source of the "high" vulnerability scan findings this setup
# replaces.
FROM nginxinc/nginx-unprivileged:alpine@sha256:18d67281256ded39ff65e010ae4f831be18f19356f83c60bc546492c7eb6dd23

# Railway injects PORT at runtime; default here only matters for `docker run`
# without -e PORT=. The image's own entrypoint scripts (20-envsubst-on-
# templates.sh) render nginx.conf.template -> conf.d/default.conf on start.
ENV PORT=8080

COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --spider -q "http://127.0.0.1:${PORT}/" || exit 1
