#!/usr/bin/env node
// End-to-end smoke test for the admin dashboard's front door.
//
// The auth gate is the only security-relevant code in this app, and a
// typecheck proves nothing about it: `fail closed` is a runtime property. This
// starts the real production server twice and drives it over HTTP.
//
// Three cases, matching the repo's e2e floor:
//   happy path — correct password returns the dashboard
//   error path — wrong or missing credentials return 401, never content
//   edge case  — no ADMIN_PASSWORD set returns 503 rather than serving open
//
// Run: node scripts/smoke.mjs   (after `npm run build`)

import { spawn } from "node:child_process";
import process from "node:process";

const PORT = 4399;
const BASE = `http://127.0.0.1:${PORT}`;
const PASSWORD = "smoke-test-password-long-enough";

let failures = 0;

/** Records one assertion's outcome without aborting the remaining cases. */
function check(name, condition, detail = "") {
  if (condition) {
    console.log(`  ok — ${name}`);
  } else {
    failures += 1;
    console.error(`  FAIL — ${name}${detail ? `: ${detail}` : ""}`);
  }
}

/** Basic-auth header for a password. The username half is ignored by the gate. */
function basic(password) {
  return `Basic ${Buffer.from(`owner:${password}`).toString("base64")}`;
}

/** Polls until the server answers or the deadline passes. */
async function waitForServer(deadlineMs = 30_000) {
  const until = Date.now() + deadlineMs;
  while (Date.now() < until) {
    try {
      await fetch(BASE, { signal: AbortSignal.timeout(1000) });
      return true;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  return false;
}

/**
 * Runs `body` against a freshly-started production server, then stops it.
 *
 * @param {Record<string, string>} env Extra environment for the server.
 * @param {() => Promise<void>} body Assertions to run while it is up.
 */
async function withServer(env, body) {
  const server = spawn("npx", ["next", "start", "--port", String(PORT)], {
    env: { ...process.env, ...env },
    stdio: "ignore",
  });
  try {
    if (!(await waitForServer())) {
      failures += 1;
      console.error("  FAIL — server never became reachable");
      return;
    }
    await body();
  } finally {
    server.kill("SIGTERM");
    // Give it a moment to release the port before the next case binds it.
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
}

console.log("admin smoke:");

// Edge case first: an unconfigured deployment must refuse, not run open.
await withServer({ ADMIN_PASSWORD: "" }, async () => {
  const response = await fetch(BASE);
  check("no ADMIN_PASSWORD returns 503", response.status === 503, `got ${response.status}`);
  const body = await response.text();
  check("503 body does not leak dashboard content", !body.includes("SenseBridge admin</h1>"));
});

// A password under the 16-character floor is treated the same as none.
await withServer({ ADMIN_PASSWORD: "short" }, async () => {
  const response = await fetch(BASE);
  check("a too-short ADMIN_PASSWORD returns 503", response.status === 503, `got ${response.status}`);
});

await withServer({ ADMIN_PASSWORD: PASSWORD }, async () => {
  const anonymous = await fetch(BASE);
  check("no credentials returns 401", anonymous.status === 401, `got ${anonymous.status}`);
  check(
    "401 asks for Basic credentials",
    (anonymous.headers.get("www-authenticate") ?? "").startsWith("Basic"),
  );
  check("401 body serves no dashboard content", !(await anonymous.text()).includes("<h1>"));

  const wrong = await fetch(BASE, { headers: { authorization: basic("wrong-password-entirely") } });
  check("a wrong password returns 401", wrong.status === 401, `got ${wrong.status}`);

  // A password with the right prefix must not pass — the compare is whole-value.
  const prefix = await fetch(BASE, { headers: { authorization: basic(PASSWORD.slice(0, -1)) } });
  check("a near-miss password returns 401", prefix.status === 401, `got ${prefix.status}`);

  const ok = await fetch(BASE, { headers: { authorization: basic(PASSWORD) } });
  check("the correct password returns 200", ok.status === 200, `got ${ok.status}`);
  const page = await ok.text();
  check("the dashboard renders its heading", page.includes("SenseBridge admin"));
  check("all three tiles render", ["Coding activity", "Sentry", "Dev tooling"].every((t) => page.includes(t)));
  // Tiles must degrade, not crash, when their upstream is unconfigured — which
  // is exactly the state here, with no Sentry token in the environment.
  check("an unconfigured tile fails soft", page.includes("unavailable"));

  const api = await fetch(`${BASE}/api/tooling`);
  check("API routes are gated too", api.status === 401, `got ${api.status}`);

  const security = await fetch(BASE, { headers: { authorization: basic(PASSWORD) } });
  check("CSP is set", (security.headers.get("content-security-policy") ?? "").includes("frame-ancestors 'none'"));
  check("responses are not cacheable", (security.headers.get("cache-control") ?? "").includes("no-store"));
});

console.log(failures === 0 ? "admin smoke: all cases pass" : `admin smoke: ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
