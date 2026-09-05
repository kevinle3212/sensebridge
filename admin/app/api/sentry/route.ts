import { cached, tile } from "../../../lib/cache";

/** Node runtime: this route reads `process.env` secrets and talks to Sentry server-side only. */
export const runtime = "nodejs";

/** Never prerender — the whole point is a live read. */
export const dynamic = "force-dynamic";

/** How long a Sentry response stays fresh. Sentry rate-limits per organisation. */
const TTL_SECONDS = 120;

/** Shape returned to the dashboard. */
interface SentrySummary {
  project: string;
  unresolvedIssues: number;
  topIssues: { title: string; culprit: string; count: string; lastSeen: string }[];
}

/**
 * Server-side Sentry read.
 *
 * `SENTRY_READ_TOKEN` must be **read-scoped** (`event:read`, `project:read`,
 * `org:read`) and never `project:write` or `org:admin`. It is secret material:
 * it lives in the host's environment store, appears in `.env.example` as a
 * placeholder only, is never committed, and never reaches a client bundle —
 * which is why this is a route handler rather than a fetch from the page.
 */
export async function GET(): Promise<Response> {
  const result = await tile("Sentry", async () =>
    cached("sentry", TTL_SECONDS, async () => {
      const token = process.env.SENTRY_READ_TOKEN?.trim();
      const org = process.env.SENTRY_ORG?.trim();
      const project = process.env.SENTRY_PROJECT?.trim();
      if (!token || !org || !project) {
        throw new Error("SENTRY_READ_TOKEN, SENTRY_ORG, and SENTRY_PROJECT must all be set");
      }

      const url = new URL(`https://sentry.io/api/0/projects/${org}/${project}/issues/`);
      url.searchParams.set("query", "is:unresolved");
      url.searchParams.set("statsPeriod", "14d");

      const response = await fetch(url, {
        headers: { authorization: `Bearer ${token}` },
        // No retry anywhere in this app: a dashboard tile that cannot load is
        // a tile that says so, not a client that hammers a rate-limited API.
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) {
        throw new Error(`Sentry responded ${response.status}`);
      }

      const issues = (await response.json()) as {
        title?: unknown;
        culprit?: unknown;
        count?: unknown;
        lastSeen?: unknown;
      }[];

      return {
        project,
        unresolvedIssues: issues.length,
        topIssues: issues.slice(0, 5).map((issue) => ({
          title: String(issue.title ?? "untitled"),
          culprit: String(issue.culprit ?? ""),
          count: String(issue.count ?? "0"),
          lastSeen: String(issue.lastSeen ?? ""),
        })),
      } satisfies SentrySummary;
    }),
  );

  return Response.json(result, {
    // Private: this response is scoped to one authenticated owner and must not
    // be held by any shared cache between them and the server.
    headers: { "cache-control": "private, no-store" },
  });
}
