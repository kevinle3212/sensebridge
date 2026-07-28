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
FROM node:26-alpine@sha256:e88a35be04478413b7c71c455cd9865de9b9360e1f43456be5951032d7ac1a66 AS build

WORKDIR /app

COPY website/.npmrc website/package.json website/package-lock.json ./
# --omit=dev, not a plain `npm ci`: every package in website/'s
# devDependencies is lint/format/test/audit tooling that `astro build` never
# touches, so none of it belongs in this stage. This is the load-bearing half
# of the rule documented in docker/README.md's "Build-time dependencies" — the
# two packages Astro's build genuinely needs (@astrojs/react, react-scan) sit
# in `dependencies` precisely so this flag is safe. With the flag in place, a
# future devDependency import on a build path fails here instead of silently
# working and then breaking only in the deployed image.
RUN npm ci --omit=dev

COPY website/ .

# Absolute origin of this deployment (canonical links, sitemap, robots.txt,
# OG/Twitter meta). A static site is built once and served as files, so this is
# a *build*-time value, not a runtime one — changing it needs a rebuild, not a
# restart, which is why it is an ARG here and not an ENV on the runtime stage.
#
# Railway passes a service's variables to the Dockerfile build as build args,
# so setting SITE_URL under Service -> Variables is enough; the ARG below is
# what makes it visible to `npm run build`. Without it the build silently falls
# back to http://localhost:4321 and ships a deployment whose canonical URLs all
# point at localhost. Locally: `docker build --build-arg SITE_URL=... .`
#
# Left empty by default so an unconfigured build still succeeds — website/
# astro.config.mjs owns the fallback, and this stays the single source of it.
ARG SITE_URL=""
ENV SITE_URL=$SITE_URL

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
