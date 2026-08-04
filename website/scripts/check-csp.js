// @ts-check
// Serves the built site under the real production CSP and asserts that nothing
// the pages need was thrown away by it.
//
// This check exists because the two servers a developer actually looks at lie.
// Neither `astro dev` nor `astro preview` sends a Content-Security-Policy
// header, so anything the production CSP forbids renders perfectly locally and
// breaks only once deployed. Two bugs shipped that way already:
//
//   Astro's default `inlineStylesheets: "auto"` inlined every stylesheet under
//   ~4kB into a <style> tag, which `style-src 'self'` blocks outright, so the
//   error pages lost their entire stylesheet in production. Fixed by pinning
//   `inlineStylesheets: "never"` in astro.config.mjs.
//
//   SpineNode.astro positioned each Signal Spine marker with an inline
//   `style="top: …"` attribute, which the same directive discards, leaving
//   every marker at `top: auto`. Fixed by moving the value onto a
//   `data-spine-top` attribute matched from the component's stylesheet.
//
// Both were invisible to `npm run build`, `astro check`, stylelint, eslint, and
// pa11y. This is the tripwire for the whole class.
//
// It reads the CSP out of vercel.json rather than restating it, so the header
// under test can never drift from the header that ships.
//
// Usage:
//   npm run build      # required first: this script serves dist/
//   npm run check:csp  # no network beyond localhost; CI-safe
//
// Puppeteer drives its own browser from `~/.cache/puppeteer`; no environment
// variable is needed. If it is missing or was truncated on unpack, reinstall it
// with `npx puppeteer browsers install chrome` under Node 22 LTS — see
// README.md's Tooling section for the failure mode and the fallback.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const WEBSITE_ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DIST_DIR = path.join(WEBSITE_ROOT, "dist");

/**
 * Content-Type per extension, for the handful `dist/` actually contains.
 *
 * A Map rather than an object literal so the lookup is not a computed property
 * access on a plain object (eslint-plugin-security's object-injection sink).
 * @type {Map<string, string>}
 */
const CONTENT_TYPES = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".svg", "image/svg+xml"],
  [".woff2", "font/woff2"],
  [".json", "application/json; charset=utf-8"],
  [".png", "image/png"],
  [".xml", "application/xml; charset=utf-8"],
  [".txt", "text/plain; charset=utf-8"],
  [".mp3", "audio/mpeg"],
]);

/**
 * The exact `Content-Security-Policy` value Vercel serves in production.
 *
 * Read out of vercel.json rather than copied here: a probe running a stale
 * policy would pass while production failed, which is precisely the failure
 * mode this script exists to prevent.
 * @returns {Promise<string>}
 */
async function productionCsp() {
  const raw = await readFile(path.join(WEBSITE_ROOT, "vercel.json"), "utf8");
  // JSON.parse returns `any`; the JSDoc cast documents the real shape for
  // readers, but doesn't change the static type of the parsed expression.
  // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
  const config = /** @type {{ headers?: { headers?: { key: string, value: string }[] }[] }} */ (
    JSON.parse(raw)
  );
  const header = (config.headers ?? [])
    .flatMap((entry) => entry.headers ?? [])
    .find((candidate) => candidate.key === "Content-Security-Policy");
  if (!header) {
    throw new Error("vercel.json no longer sets a Content-Security-Policy header.");
  }
  return header.value;
}

/**
 * Maps a request path to a file inside `dist/`.
 *
 * Mirrors vercel.json's `cleanUrls: true`, so `/404` resolves to `404.html`
 * and `/es/` to `es/index.html`, exactly as the deployed site does.
 * @param {string} pathname
 * @returns {string}
 */
function distRelativePath(pathname) {
  const decoded = decodeURIComponent(pathname);
  if (decoded.endsWith("/")) {
    return path.join(decoded, "index.html").replace(/^\/+/, "");
  }
  const relative = path.extname(decoded) ? decoded : `${decoded}.html`;
  return relative.replace(/^\/+/, "");
}

/**
 * Serves `dist/` with the production CSP attached to every response, and the
 * 404 fallback a static host performs for an unmatched path.
 * @param {string} csp
 * @returns {Promise<{ baseUrl: string, close: () => Promise<void> }>}
 */
async function serveDist(csp) {
  const server = createServer((request, response) => {
    /**
     * @param {string} relative
     * @param {number} status
     * @returns {Promise<void>}
     */
    const send = async (relative, status) => {
      const file = path.join(DIST_DIR, relative);
      // Traversal guard: a request for `/../../etc/passwd` must not escape
      // dist/, even on a localhost-only probe.
      if (!file.startsWith(DIST_DIR)) {
        response.writeHead(403).end();
        return;
      }
      try {
        // Path is confined to DIST_DIR by the guard directly above.
        // eslint-disable-next-line security/detect-non-literal-fs-filename
        const body = await readFile(file);
        response.writeHead(status, {
          "Content-Type": CONTENT_TYPES.get(path.extname(file)) ?? "application/octet-stream",
          "Content-Security-Policy": csp,
        });
        response.end(body);
      } catch {
        if (relative === "404.html") {
          response.writeHead(404).end("not found");
          return;
        }
        // What a static host does with an unmatched path, and the only way to
        // exercise the 404 page the way a visitor actually reaches it.
        await send("404.html", 404);
      }
    };

    const { pathname } = new URL(request.url ?? "/", "http://localhost");
    void send(distRelativePath(pathname), 200);
  });

  await new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      resolve(undefined);
    });
  });

  const address = server.address();
  if (address === null || typeof address === "string") {
    throw new Error("probe server did not bind to a TCP port.");
  }
  return {
    baseUrl: `http://127.0.0.1:${address.port}`,
    close: () =>
      new Promise((resolve) => {
        server.close(() => {
          resolve(undefined);
        });
      }),
  };
}

/**
 * What each probed route must still be true of once the CSP has had its say.
 *
 * Each `assert` is serialized into the page by Puppeteer and runs in the
 * browser, so it may only use browser globals. It returns failure strings;
 * empty means the route passed.
 * @type {{ path: string, name: string, assert: () => string[] }[]}
 */
const ROUTES = [
  {
    path: "/",
    name: "home — Signal Spine markers sit at heading level",
    assert: () => {
      /** @type {string[]} */
      const failures = [];
      const nodes = [...document.querySelectorAll("[data-spine-node]")];
      if (nodes.length === 0) {
        failures.push("no [data-spine-node] markers found on the page at all");
      }
      // 4rem/6rem/8rem against the 16px root font size the site never changes.
      // A Map, not an object literal, to keep the lookup off an injection sink.
      const expected = new Map([
        ["4rem", "64px"],
        ["6rem", "96px"],
        ["8rem", "128px"],
      ]);
      for (const node of nodes) {
        const token = node.getAttribute("data-spine-top") ?? "";
        const wanted = expected.get(token);
        if (wanted === undefined) {
          failures.push(`marker has unhandled data-spine-top="${token}"`);
          continue;
        }
        const computed = getComputedStyle(node);
        if (computed.position !== "absolute") {
          failures.push(`marker ${token} computed position: ${computed.position}, want absolute`);
        }
        if (computed.top !== wanted) {
          failures.push(`marker ${token} computed top: ${computed.top}, want ${wanted}`);
        }
      }
      return failures;
    },
  },
  {
    path: "/",
    name: "home — the page-load sequence still runs",
    assert: () => {
      /** @type {string[]} */
      const failures = [];
      if (!document.querySelector("[data-page-loader]")) {
        failures.push("the page-load overlay is missing from a content page");
      }
      if (!document.querySelector('script[src="/page-load.js"]')) {
        failures.push("the page-load bootstrap is missing from a content page");
      }
      return failures;
    },
  },
  {
    path: "/",
    name: "home — CSSOM custom properties are writable under style-src 'self'",
    // `style-src` governs <style> elements, style attributes, and stylesheet
    // loads. It does not govern CSSOM writes. Motion code across the site sets
    // custom properties this way precisely because it is the CSP-safe channel
    // for a per-frame number, so the assumption is asserted, not trusted.
    assert: () => {
      const probe = document.createElement("div");
      document.body.append(probe);
      probe.style.setProperty("--csp-probe", "42px");
      const written = getComputedStyle(probe).getPropertyValue("--csp-probe").trim();
      probe.remove();
      return written === "42px" ? [] : [`style.setProperty was blocked (read back "${written}")`];
    },
  },
  {
    // A genuinely unmatched path, served the way a static host serves
    // dist/404.html, rather than the /404 route spelled out by hand. This is
    // how a visitor actually reaches this page.
    path: "/no-such-page-anywhere",
    name: "unmatched path — 404 body, stylesheet intact, no page-load sequence",
    assert: () => {
      /** @type {string[]} */
      const failures = [];
      if (document.querySelector("[data-page-loader]")) {
        failures.push("the page-load overlay is rendered on a status page");
      }
      if (document.querySelector('script[src="/page-load.js"]')) {
        failures.push("the page-load bootstrap is rendered on a status page");
      }
      if (document.documentElement.dataset.pageLoad !== undefined) {
        failures.push("data-page-load was set on a status page — content was covered");
      }
      // The heading is styled by an external stylesheet. Where style-src ate
      // it, this falls back to the UA default rather than Fraunces, which is
      // the shape the earlier error-page regression took.
      const heading = document.querySelector("h1");
      if (!heading) {
        failures.push("no <h1> on the status page");
      } else {
        const family = getComputedStyle(heading).fontFamily;
        if (!family.includes("Fraunces")) {
          failures.push(`h1 font-family is ${family} — stylesheet lost`);
        }
      }
      return failures;
    },
  },
  {
    path: "/500",
    name: "500 — no page-load sequence",
    assert: () => {
      /** @type {string[]} */
      const failures = [];
      if (document.querySelector("[data-page-loader]")) {
        failures.push("the page-load overlay is rendered on a status page");
      }
      if (document.documentElement.dataset.pageLoad !== undefined) {
        failures.push("data-page-load was set on a status page — content was covered");
      }
      return failures;
    },
  },
];

/** Property the in-page listener parks reported CSP violations on. */
const VIOLATION_KEY = "__cspViolations";

async function main() {
  const csp = await productionCsp();
  const { baseUrl, close } = await serveDist(csp);
  // --enable-unsafe-swiftshader: the home route mounts the same WebGL glasses
  // scene check-bfcache.js/check-scene-drag.js need it for — without software
  // WebGL, headless Chrome never settles the scene's asset requests, and
  // page.goto's networkidle0 wait times out (30s) instead of ever resolving.
  const browser = await puppeteer.launch({
    args: ["--no-sandbox", "--enable-unsafe-swiftshader"],
  });
  /** @type {string[]} */
  const failures = [];

  try {
    for (const route of ROUTES) {
      const page = await browser.newPage();
      // Anything the CSP actually refused, straight from the browser. A
      // violation is reported even when the page still looks right, which is
      // what makes this useful beyond the hand-written assertions above.
      await page.evaluateOnNewDocument((key) => {
        /** @type {string[]} */
        const store = [];
        Object.defineProperty(window, key, { value: store });
        document.addEventListener("securitypolicyviolation", (event) => {
          store.push(`${event.violatedDirective} blocked ${event.blockedURI || "inline"}`);
        });
      }, VIOLATION_KEY);

      // domcontentloaded, not networkidle0: the home route mounts a
      // continuously-animated WebGL scene (same one check-scene-drag.js/
      // check-bfcache.js already avoid networkidle0 for), so "zero network
      // connections for 500ms" may never actually occur, and a fast local
      // run getting lucky under 30s just masked the CI-runner timeout this
      // caused. The follow-up wait below still gives late CSP-triggering
      // resource loads a bounded window to register a violation, capped
      // instead of open-ended.
      await page.goto(`${baseUrl}${route.path}`, { waitUntil: "domcontentloaded" });
      await page.waitForNetworkIdle({ idleTime: 500, timeout: 3000 }).catch(() => null);
      const routeFailures = await page.evaluate(route.assert);
      const violations = await page.evaluate((key) => {
        // `Reflect.get` rather than `window[key]`: the bracket form is an
        // object-injection sink to eslint-plugin-security, and the key is a
        // module constant either way. Its return type is `any`, same as
        // JSON.parse above, so the cast documents the shape without changing it.
        // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
        const store = /** @type {string[] | undefined} */ (Reflect.get(window, key));
        return store ?? [];
      }, VIOLATION_KEY);
      await page.close();

      for (const failure of routeFailures) {
        failures.push(`${route.name}: ${failure}`);
      }
      for (const violation of new Set(violations)) {
        failures.push(`${route.name}: CSP violation — ${violation}`);
      }
      const ok = routeFailures.length === 0 && violations.length === 0;
      // `console.warn` rather than `log`: the repo's ESLint config allows only
      // `warn` and `error`.
      console.warn(`${ok ? "ok  " : "FAIL"} ${route.path}  ${route.name}`);
    }
  } finally {
    await browser.close();
    await close();
  }

  if (failures.length > 0) {
    console.error(`\n${failures.length} CSP failure(s) under: ${csp}\n`);
    for (const failure of failures) {
      console.error(`  - ${failure}`);
    }
    process.exit(1);
  }
  console.warn(`\nAll ${ROUTES.length} route checks clean under the production CSP.`);
}

await main();
