// Loads `.env` into `process.env` for anything in website/ that runs on Node.
//
// Import it for its side effect, first, before reading `process.env`:
//
//   import "./load-env.js";
//
// Why this exists at all: Astro only injects `.env` into *your site's* code
// via Vite, and only under an `import.meta.env` prefix. It does not populate
// `process.env` for astro.config.mjs (which runs before Vite is configured)
// nor for the standalone scripts in this directory. Without this, every one of
// them would need its own loader, or a `--env-file-if-exists` flag remembered
// at each call site — and the one you forget is the one that silently reads a
// default and builds the wrong thing.
//
// Precedence: anything already in the environment wins. `.env` is a local
// convenience, so a CI secret or a hosting provider's project setting is never
// overwritten by a stale file on a developer's disk. Node's own loader has
// exactly this behavior, which is why it is used rather than a dependency.
//
// Repo root is read first so shared values live in one place; website/.env
// then wins for anything site-specific. Both are git-ignored and both are
// optional — with neither present, everything here still runs on its defaults.
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";

// Derived from this file's own location, never from user input — which is what
// the fs-filename lint rule is guarding against.
/* eslint-disable security/detect-non-literal-fs-filename */
for (const relativePath of ["../../.env", "../.env"]) {
  const envFile = fileURLToPath(new URL(relativePath, import.meta.url));
  if (existsSync(envFile)) process.loadEnvFile(envFile);
}
/* eslint-enable security/detect-non-literal-fs-filename */
