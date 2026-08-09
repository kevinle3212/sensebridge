// Ephemeral static file server for the built site, shared by the puppeteer
// smoke checks (scripts/check-scene-drag.js, scripts/check-bfcache.js).
//
// Extracted so the two checks serve `dist/` identically — a difference in
// content types or index resolution between them would show up as a fake
// failure in whichever one drifted. Binds port 0 (the OS picks a free one) and
// listens only on 127.0.0.1, so a run never holds a well-known port and never
// exposes the build beyond this machine; callers close it in a `finally`.
import { createServer } from "node:http";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const DIST_DIR = fileURLToPath(new URL("../../dist", import.meta.url));

// A Map rather than an object literal: indexing an object by a computed
// extension resolves as `any` under this repo's type-aware ESLint config.
const CONTENT_TYPES = new Map([
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".svg", "image/svg+xml"],
  [".json", "application/json; charset=utf-8"],
  [".woff2", "font/woff2"],
]);

/**
 * Resolves a request path to a file inside `dist/`, following the static
 * build's directory-index convention and refusing anything that escapes the
 * directory.
 * @param {string} urlPath Request path, e.g. `/` or `/_astro/app.js`.
 * @returns {Promise<string | null>} Absolute file path, or null if unservable.
 */
async function resolveFile(urlPath) {
  const relative = normalize(decodeURIComponent(urlPath.split("?")[0])).replace(
    /^(\.\.[/\\])+/,
    "",
  );
  const candidate = join(DIST_DIR, relative);
  if (!candidate.startsWith(DIST_DIR)) {
    return null;
  }
  // Every path below is derived from a request to this module's own ephemeral
  // localhost server and is confined to dist/ by the guard above.
  // eslint-disable-next-line security/detect-non-literal-fs-filename
  const stats = await stat(candidate).catch(() => null);
  if (stats?.isDirectory()) {
    const index = join(candidate, "index.html");
    // eslint-disable-next-line security/detect-non-literal-fs-filename
    return (await stat(index).catch(() => null)) ? index : null;
  }
  return stats?.isFile() ? candidate : null;
}

/**
 * Starts a static file server for `dist/` on an ephemeral port.
 * @param {string} label Caller name, used in the error if the bind fails.
 * @returns {Promise<{server: import("node:http").Server, port: number}>}
 */
export async function startDistServer(label) {
  const server = createServer((request, response) => {
    void resolveFile(request.url ?? "/").then((file) => {
      if (!file) {
        response.writeHead(404).end("not found");
        return;
      }
      response.writeHead(200, {
        "content-type": CONTENT_TYPES.get(extname(file)) ?? "application/octet-stream",
      });
      // eslint-disable-next-line security/detect-non-literal-fs-filename
      createReadStream(file).pipe(response);
    });
  });
  await new Promise((resolve) => {
    server.listen(0, "127.0.0.1", resolve);
  });
  const address = server.address();
  if (typeof address !== "object" || address === null) {
    throw new Error(`${label}: static server did not bind to a port.`);
  }
  return { server, port: address.port };
}
