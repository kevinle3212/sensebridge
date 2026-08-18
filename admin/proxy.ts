import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/**
 * Single-owner gate for the whole dashboard.
 *
 * Named `proxy`, in `proxy.ts`: Next 16 renamed the `middleware` convention
 * and warns on the old name.
 *
 * This app surfaces a Sentry read token's output, local tooling telemetry, and
 * WakaTime activity — none of it catastrophic, all of it nobody else's
 * business. One password is the right weight of control for a one-person
 * dashboard: an OAuth provider would add an external dependency and a callback
 * surface to protect something with a single user.
 *
 * **Fails closed.** With `ADMIN_PASSWORD` unset the app serves 503 to every
 * route rather than running open. A dashboard that quietly becomes public the
 * moment an environment variable goes missing is worse than one that stops.
 */
export function proxy(request: NextRequest) {
  const expected = process.env.ADMIN_PASSWORD;
  if (!expected || expected.length < 16) {
    // Deliberately not "unauthorized": nothing the visitor can type fixes this,
    // and prompting for a password that cannot be checked invites guessing.
    return new NextResponse(
      "ADMIN_PASSWORD is unset or shorter than 16 characters. This dashboard refuses to serve without it.",
      { status: 503, headers: { "content-type": "text/plain; charset=utf-8" } },
    );
  }

  const header = request.headers.get("authorization") ?? "";
  const [scheme, encoded] = header.split(" ");
  if (scheme !== "Basic" || !encoded) {
    return unauthorized();
  }

  let decoded: string;
  try {
    decoded = atob(encoded);
  } catch {
    return unauthorized();
  }

  // The username half is ignored on purpose — there is exactly one user, so a
  // second secret to remember buys nothing. `indexOf`, not `split`, so a
  // password containing a colon still compares whole.
  const separator = decoded.indexOf(":");
  const supplied = separator === -1 ? "" : decoded.slice(separator + 1);

  return constantTimeEquals(supplied, expected) ? NextResponse.next() : unauthorized();
}

/** Prompts for credentials without hinting at what was wrong. */
function unauthorized(): NextResponse {
  return new NextResponse("Unauthorized", {
    status: 401,
    headers: {
      "www-authenticate": 'Basic realm="SenseBridge admin", charset="UTF-8"',
      "content-type": "text/plain; charset=utf-8",
    },
  });
}

/**
 * Compares two strings in time that does not depend on where they first differ.
 *
 * Hand-rolled because middleware runs on the Edge runtime, where
 * `node:crypto`'s `timingSafeEqual` is unavailable. Length is compared first
 * and does leak — that is inherent to comparing raw secrets of differing
 * length, and a password length is not the secret.
 */
function constantTimeEquals(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  if (left.length !== right.length) {
    return false;
  }
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    // Non-null assertions are safe: both arrays are the same length and the
    // loop never leaves it.
    difference |= left[index]! ^ right[index]!;
  }
  return difference === 0;
}

export const config = {
  // Everything except Next's own static output. The API routes are covered
  // deliberately: they are the half that reads secrets.
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
