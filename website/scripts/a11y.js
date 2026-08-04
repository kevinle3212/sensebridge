// Runs the pa11y-ci accessibility gate against a preview of the built site.
//
// The URLs in .pa11yci.json are absolute (http://127.0.0.1:4321/...), so the
// gate needs a server. Historically that was a manual two-terminal dance:
// `npm run preview` in one, `npm run test:a11y` in the other. Wrapping it was
// deliberately avoided because a start/stop wrapper that crashes between start
// and stop leaves an orphaned `astro preview` process holding port 4321, and
// ../CLAUDE.md forbids leaving a port held by something the owner never asked
// to start.
//
// This wrapper sidesteps that instead of managing it: the preview server runs
// **in this process** via Astro's programmatic `preview()`, so the listening
// socket is owned by this PID. However this script dies — a thrown error, an
// uncaught rejection, Ctrl-C, even SIGKILL — the kernel closes the socket with
// the process. There is no window in which a crash can strand the port, which
// is why no signal handlers or cleanup traps appear below: the guarantee comes
// from process ownership, not from remembering to tidy up.
//
// pa11y-ci itself stays a child process rather than a library call, so
// .pa11yci.json remains the single source of URLs, standard, and Chrome flags
// for both this script and CI. It must be spawned asynchronously: `spawnSync`
// blocks this process's event loop, so the in-process server could never
// answer a request and every URL would time out.
//
// Two engines run per URL: HTML CodeSniffer (pa11y's default) and axe-core.
// They disagree usefully — axe catches things htmlcs does not, and vice versa.
//
// .pa11yci.json sets `levelCapWhenNeedsReview: "warning"` because of how the
// axe runner reports: it folds axe's `incomplete` results ("I could not
// determine this — a human should look") in alongside real `violations`, and
// without the cap a needs-review item inherits axe's `serious` impact and
// surfaces as a build-failing error. On this site that misfires on every
// unstyled link: the animated underline in global/_base.scss is a
// `linear-gradient` background-image on the anchor itself, so axe returns
// `messageKey: "bgGradient"` and declines to compute a ratio. Capping those at
// warning keeps genuine axe violations failing the build while letting
// needs-review items report as what they are. The underlying ratios are not
// left unproven — abstracts/_tokens.scss carries the computed figure for every
// text-carrying token, against the worst background it is placed on.
//
// Usage:
//   npm run test:a11y   # builds dist/ if missing, serves it, runs the gate
import { spawn } from "node:child_process";
import net from "node:net";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { build, preview } from "astro";

const WEBSITE_ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DIST_DIR = path.join(WEBSITE_ROOT, "dist");
const PA11Y_CI = path.join(WEBSITE_ROOT, "node_modules/.bin/pa11y-ci");
const CONFIG = path.join(WEBSITE_ROOT, ".pa11yci.json");

/**
 * Host and port the URLs in .pa11yci.json point at.
 *
 * 127.0.0.1 rather than localhost on purpose: bare `astro preview` binds `::1`,
 * which those URLs do not reach, and pa11y then fails against a server that is
 * demonstrably up.
 */
const HOST = "127.0.0.1";
const PORT = 4321;

/**
 * Reports whether something already answers on the gate's host and port.
 *
 * Lets an owner who is already running `npm run preview` keep using it: this
 * script then tests against their server instead of failing on a port clash.
 *
 * @returns {Promise<boolean>} True when a connection succeeds.
 */
function portIsServed() {
  return new Promise((resolve) => {
    const socket = net
      .connect({ host: HOST, port: PORT })
      .on("connect", () => {
        socket.destroy();
        resolve(true);
      })
      .on("error", () => {
        resolve(false);
      });
  });
}

/**
 * Writes a variant of `.pa11yci.json` with a different WCAG level, so the
 * blocking AA gate and the advisory AAA pass can never drift to different URL
 * lists — the URLs, timeout, and Chrome flags all come from the one file.
 *
 * The variant lands in the OS temp directory rather than the repo: it is
 * generated state, and a second checked-in config is exactly the duplicate
 * this avoids.
 *
 * @param {string} standard A pa11y standard name, e.g. `"WCAG2AAA"`.
 * @returns {string} Absolute path to the generated config.
 */
function writeVariantConfig(standard) {
  // JSON.parse returns `any`; the JSDoc cast documents the real shape for
  // readers, but doesn't change the static type of the parsed expression.
  // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
  const base = /** @type {{defaults?: Record<string, unknown>}} */ (
    JSON.parse(fs.readFileSync(CONFIG, "utf8"))
  );
  const variant = { ...base, defaults: { ...base.defaults, standard } };
  const target = path.join(os.tmpdir(), `pa11yci-${standard.toLowerCase()}.json`);
  // The path is the OS temp directory joined with a name derived from this
  // file's own literal `standard` argument; nothing here comes from outside
  // the process.
  // eslint-disable-next-line security/detect-non-literal-fs-filename
  fs.writeFileSync(target, JSON.stringify(variant, null, 2));
  return target;
}

/**
 * Runs pa11y-ci to completion, streaming its output.
 *
 * @param {string} [config] Config path; defaults to the repo's `.pa11yci.json`.
 * @returns {Promise<number>} pa11y-ci's exit code; non-zero means failures.
 */
function runPa11yCi(config = CONFIG) {
  return new Promise((resolve) => {
    spawn(PA11Y_CI, ["--config", config], {
      cwd: WEBSITE_ROOT,
      stdio: "inherit",
    })
      // A missing binary or a signal both mean "the gate did not pass".
      .on("error", (error) => {
        console.error(`test:a11y: could not run pa11y-ci — ${error.message}`);
        resolve(1);
      })
      .on("close", (code) => {
        resolve(code ?? 1);
      });
  });
}

/**
 * Serves the built site and runs the accessibility gate over it.
 *
 * Exits with pa11y-ci's own status so the command works as a CI gate.
 */
async function main() {
  if (!fs.existsSync(DIST_DIR)) {
    console.warn("test:a11y: no dist/ — building it first.");
    await build({ root: WEBSITE_ROOT, logLevel: "error" });
  }

  const borrowed = await portIsServed();
  if (borrowed) {
    console.warn(`test:a11y: reusing the server already on ${HOST}:${PORT}.`);
  }

  const server = borrowed
    ? null
    : await preview({
        root: WEBSITE_ROOT,
        logLevel: "error",
        server: { host: HOST, port: PORT },
      });

  try {
    process.exitCode = await runPa11yCi();

    // The AAA pass reports, it does not block. W3C's own guidance is that Level
    // AAA conformance is not achievable for whole sites as a general policy, so
    // failing a build on it would either be ignored or quietly weakened until
    // it meant nothing. Running it advisory keeps the number honest and visible
    // — which is what `legal/ACCESSIBILITY_STATEMENT.md` claims happens here.
    // `console.warn` rather than `log`: the repo's ESLint config allows only
    // warn and error, matching the other scripts in this directory.
    console.warn("\ntest:a11y: WCAG2AAA pass (advisory — does not fail the build)");
    const aaa = await runPa11yCi(writeVariantConfig("WCAG2AAA"));
    console.warn(
      aaa === 0
        ? "test:a11y: WCAG2AAA pass found no issues."
        : "test:a11y: WCAG2AAA pass found issues (advisory; see above).",
    );
  } finally {
    await server?.stop();
  }
}

await main();
