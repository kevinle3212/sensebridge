# Static marketing site — built with Astro in stage 1, then served as plain
# static files from `dist/`, the same way local preview does
# (`npm run build && npx serve dist`), just pinned + PORT-aware for Railway.
# See README.md's Deployment section for the full deploy flow.
FROM node:22-alpine AS build

WORKDIR /app

COPY .npmrc package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:22-alpine

WORKDIR /app

RUN npm install --global serve@14

COPY --from=build /app/dist ./dist

# node:22-alpine ships a non-root `node` user (uid 1000) — use it so the
# static file server never runs as root.
USER node

EXPOSE 3000
CMD ["sh", "-c", "serve -s dist -l tcp://0.0.0.0:${PORT:-3000}"]
