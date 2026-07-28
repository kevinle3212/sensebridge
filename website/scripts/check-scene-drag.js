// Smoke check for the Spatial Future stage's drag-to-orbit affordance
// (src/scripts/scenes/core.ts's createDragOrbit, wired up by glasses.ts).
//
// The gesture itself is the thing that cannot be proven by a typecheck or a
// build, so this drives a real pointer over the built site instead of asking a
// human to try dragging the glasses. Asserts, in order:
//   1. the glasses stage mounts its WebGL scene at all (`.scene-active` + a
//      <canvas>) — otherwise the drag has nothing to turn;
//   2. pressing and moving over the stage marks it `.scene-dragging`;
//   3. releasing clears that class again (no stuck "grabbing" cursor);
//   4. the page logged no errors while all of that happened.
//
// Usage: `npm run build && node scripts/check-scene-drag.js`. Serves `dist/`
// on an ephemeral port for the duration of the run and closes it again — it
// never leaves a server holding a port behind.
import { createServer } from "node:http";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const DIST_DIR = fileURLToPath(new URL("../dist", import.meta.url));
// Generous, because a CI runner renders this scene through software WebGL.
const SCENE_MOUNT_TIMEOUT_MS = 30_000;

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
  // Every path below is derived from a request to this script's own
  // ephemeral localhost server and is confined to dist/ by the guard above.
  // eslint-disable-next-line security/detect-non-literal-fs-filename
  const stats = await stat(candidate).catch(() => null);
  if (stats?.isDirectory()) {
    const index = join(candidate, "index.html");
    // eslint-disable-next-line security/detect-non-literal-fs-filename
    return (await stat(index).catch(() => null)) ? index : null;
  }
  return stats?.isFile() ? candidate : null;
}

/** Starts a static file server for `dist/` on an ephemeral port. */
async function startServer() {
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
    throw new Error("check-scene-drag: static server did not bind to a port.");
  }
  return { server, port: address.port };
}

const failures = [];

/**
 * Records a failure instead of throwing, so one run reports every problem.
 * @param {boolean} condition Assertion that must hold.
 * @param {string} message What the assertion was checking.
 */
function expect(condition, message) {
  if (condition) {
    console.warn(`  ok   ${message}`);
  } else {
    failures.push(message);
    console.warn(`  FAIL ${message}`);
  }
}

const STAGE = "[data-scene='glasses']";

/**
 * Returns the stage's viewport-centre once a pointer press there would actually
 * reach the stage.
 *
 * Two things get in the way of naively measuring and clicking. The page uses
 * Lenis smooth scrolling, so `scrollIntoView()` animates and an immediate
 * measurement names coordinates the element has already left. And the
 * `[data-page-loader]` overlay covers the viewport until the intro finishes,
 * swallowing the press even once the coordinates are right. Rather than couple
 * to either mechanism, this hit-tests: it asks the page what `elementFromPoint`
 * returns at the stage's centre and waits until that is the stage itself or a
 * descendant — which is precisely the condition a real pointer needs.
 *
 * @param {import("puppeteer").Page} page Page under test.
 * @returns {Promise<{x: number, y: number} | null>} Usable centre point, or
 *   null if the stage never became reachable.
 */
async function waitForReachableStageCentre(page) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const probe = await page.$eval(STAGE, (element) => {
      const rect = element.getBoundingClientRect();
      const point = { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
      const topmost = document.elementFromPoint(point.x, point.y);
      return { point, reachable: topmost !== null && element.contains(topmost) };
    });
    if (probe.reachable) {
      return probe.point;
    }
    await new Promise((resolve) => {
      setTimeout(resolve, 100);
    });
  }
  return null;
}
const { server, port } = await startServer();
const browser = await puppeteer.launch({
  headless: true,
  // SwiftShader gives headless Chrome the WebGL2 context quality-gate.ts
  // probes for; without it the scene never mounts and the drag is untestable.
  // --disable-dev-shm-usage keeps Chrome off the small /dev/shm that CI
  // containers hand out, a routine cause of silent renderer crashes there.
  args: ["--enable-unsafe-swiftshader", "--no-sandbox", "--disable-dev-shm-usage"],
});

// Distinct from "passed": set when the runner cannot provide WebGL2 at all, in
// which case the site correctly declines to mount the scene and there is no
// gesture to exercise. Reported loudly rather than dressed up as a pass.
let skipped = false;

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 900 });
  const pageErrors = [];
  page.on("pageerror", (error) => {
    pageErrors.push(error.message);
  });
  page.on("console", (message) => {
    if (message.type() === "error") {
      pageErrors.push(message.text());
    }
  });

  // `domcontentloaded`, deliberately not `networkidle0`: the page lazy-loads a
  // ~700kB three.js chunk as a scene comes into view, so "no connections for
  // 500ms" is not a readiness signal worth hanging on — it timed out on CI when
  // this used it. The `.scene-active` wait below is the real signal.
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });

  await page.$eval(STAGE, (element) => {
    element.scrollIntoView({ block: "center" });
  });

  let sceneMounted = true;
  try {
    await page.waitForSelector(`${STAGE}.scene-active canvas`, {
      timeout: SCENE_MOUNT_TIMEOUT_MS,
    });
  } catch {
    sceneMounted = false;
  }

  if (sceneMounted) {
    expect(true, "glasses stage mounts its WebGL scene");
  } else {
    const hasWebgl2 = await page.evaluate(
      () => document.createElement("canvas").getContext("webgl2") !== null,
    );
    if (hasWebgl2) {
      expect(false, "glasses stage mounts its WebGL scene (WebGL2 is available, so this is real)");
      if (pageErrors.length > 0) {
        console.error(`  page errors: ${pageErrors.join("; ")}`);
      }
    } else {
      skipped = true;
    }
  }

  if (sceneMounted) {
    const box = await waitForReachableStageCentre(page);
    if (!box) {
      expect(false, "stage centre becomes reachable by a pointer (overlay never cleared?)");
    } else {
      await page.mouse.move(box.x, box.y);
      await page.mouse.down();
      await page.mouse.move(box.x + 120, box.y + 40, { steps: 12 });
      const draggingDuringGesture = await page.$eval(STAGE, (element) =>
        element.classList.contains("scene-dragging"),
      );
      expect(draggingDuringGesture, "dragging over the stage marks it .scene-dragging");

      await page.mouse.up();
      const draggingAfterRelease = await page.$eval(STAGE, (element) =>
        element.classList.contains("scene-dragging"),
      );
      expect(!draggingAfterRelease, "releasing the pointer clears .scene-dragging");

      expect(pageErrors.length === 0, `no page errors during the gesture${pageErrors.join("; ")}`);
    }
  }
} finally {
  await browser.close();
  server.close();
}

if (skipped) {
  console.warn(
    "check-scene-drag: SKIPPED — this runner has no WebGL2 context, so the site " +
      "correctly declines to mount the scene and the drag cannot be exercised " +
      "here. This is not a pass.",
  );
  process.exit(0);
}
if (failures.length > 0) {
  console.error(`check-scene-drag: ${failures.length} failure(s).`);
  process.exit(1);
}
console.warn("check-scene-drag: drag-to-orbit affordance is wired end to end.");
