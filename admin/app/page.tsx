import { headers } from "next/headers";
import type { TileResult } from "../lib/cache";

/** Always live: every tile is a point-in-time read, and a cached page would lie. */
export const dynamic = "force-dynamic";

/**
 * Fetches one tile's route handler from the server side of this same app.
 *
 * Going back through HTTP rather than importing the handler keeps each tile's
 * caching, timeout, and fail-soft behaviour in exactly one place, and means a
 * broken tile cannot take the page down with it.
 */
async function loadTile<T>(pathname: string): Promise<TileResult<T>> {
  const requestHeaders = await headers();
  const host = requestHeaders.get("host") ?? "localhost:4331";
  const protocol = requestHeaders.get("x-forwarded-proto") ?? "http";
  try {
    const response = await fetch(`${protocol}://${host}${pathname}`, {
      // Forward the owner's credentials so the middleware gate applies to the
      // internal call too — the dashboard must not have a way around its own
      // front door.
      headers: { authorization: requestHeaders.get("authorization") ?? "" },
      cache: "no-store",
    });
    return (await response.json()) as TileResult<T>;
  } catch {
    return { ok: false, reason: `${pathname} could not be reached.` };
  }
}

/** Mirrors `app/api/wakatime/route.ts`'s payload. Duplicated rather than shared: the route is the wire contract, and importing its types would couple the page to a module that must stay server-only. */
interface WakaTimeSummary {
  range: string;
  humanReadableTotal: string;
  dailyAverage: string;
  languages: { name: string; percent: number; text: string }[];
  projects: { name: string; percent: number; text: string }[];
}

/** Mirrors `app/api/sentry/route.ts`'s payload — see the note on `WakaTimeSummary`. */
interface SentrySummary {
  project: string;
  unresolvedIssues: number;
  topIssues: { title: string; culprit: string; count: string; lastSeen: string }[];
}

/** Mirrors `app/api/tooling/route.ts`'s payload — see the note on `WakaTimeSummary`. */
interface ToolingSummary {
  rtk: { totalCommands: number; totalSaved: number; averageSavingsPercent: number } | null;
  caveman: { activeMode: string | null; modeChanges: { at: string; mode: string }[] };
  ponytail: { deferredShortcuts: number };
  note: string;
}

/** A card with a heading, rendering either its children or why it has nothing. */
function Card({
  title,
  result,
  children,
}: {
  title: string;
  result: { ok: boolean; reason?: string };
  children: React.ReactNode;
}) {
  return (
    <section className="card" aria-labelledby={`${title.toLowerCase().replace(/\W+/g, "-")}-heading`}>
      <h2 id={`${title.toLowerCase().replace(/\W+/g, "-")}-heading`}>{title}</h2>
      {result.ok ? children : <p className="unavailable">{result.reason}</p>}
    </section>
  );
}

/** The dashboard. Three tiles, each independently fail-soft. */
export default async function Page() {
  const [wakatime, sentry, tooling] = await Promise.all([
    loadTile<WakaTimeSummary>("/api/wakatime"),
    loadTile<SentrySummary>("/api/sentry"),
    loadTile<ToolingSummary>("/api/tooling"),
  ]);

  return (
    <main>
      <h1>SenseBridge admin</h1>
      <p className="lede">
        Project telemetry for the owner. Not part of the product, not deployed with the marketing
        site, and it asserts nothing it cannot read.
      </p>

      <div className="grid">
        <Card title="Coding activity" result={wakatime}>
          {wakatime.ok && (
            <>
              <p className="figure">{wakatime.data.humanReadableTotal}</p>
              <p className="caption">
                {wakatime.data.range} · {wakatime.data.dailyAverage} per day
              </p>
              <h3>Languages</h3>
              <ul>
                {wakatime.data.languages.map((language) => (
                  <li key={language.name}>
                    {language.name} — {language.text} ({language.percent.toFixed(1)}%)
                  </li>
                ))}
              </ul>
              <h3>Projects</h3>
              <ul>
                {wakatime.data.projects.map((project) => (
                  <li key={project.name}>
                    {project.name} — {project.text}
                  </li>
                ))}
              </ul>
            </>
          )}
        </Card>

        <Card title="Sentry" result={sentry}>
          {sentry.ok && (
            <>
              <p className="figure">{sentry.data.unresolvedIssues}</p>
              <p className="caption">
                unresolved issues in {sentry.data.project}, last 14 days
              </p>
              <ul>
                {sentry.data.topIssues.map((issue) => (
                  <li key={`${issue.title}-${issue.lastSeen}`}>
                    <strong>{issue.title}</strong>
                    {issue.culprit ? ` — ${issue.culprit}` : ""} ({issue.count} events)
                  </li>
                ))}
              </ul>
              {sentry.data.topIssues.length === 0 && <p>No unresolved issues.</p>}
            </>
          )}
        </Card>

        <Card title="Dev tooling" result={tooling}>
          {tooling.ok && (
            <>
              <h3>rtk</h3>
              {tooling.data.rtk ? (
                <ul>
                  <li>{tooling.data.rtk.totalCommands.toLocaleString()} commands, lifetime</li>
                  <li>{tooling.data.rtk.totalSaved.toLocaleString()} tokens saved, lifetime</li>
                  <li>{tooling.data.rtk.averageSavingsPercent.toFixed(1)}% average saving</li>
                </ul>
              ) : (
                <p className="unavailable">`rtk gain` is not reachable from here.</p>
              )}

              <h3>caveman</h3>
              <p>
                Level: <strong>{tooling.data.caveman.activeMode ?? "off"}</strong>
              </p>
              <p className="caption">
                No savings figure: the plugin records the level and when it changed, not token
                counts, so there is nothing here to total.
              </p>

              <h3>ponytail</h3>
              <p>
                <strong>{tooling.data.ponytail.deferredShortcuts}</strong> deferred shortcuts
                (`ponytail:` markers)
              </p>
              <p className="caption">
                A debt count, not a savings figure — `ponytail-gain` reports fixed benchmark
                medians, never anything measured against this repo.
              </p>

              <p className="caption">{tooling.data.note}</p>
            </>
          )}
        </Card>
      </div>
    </main>
  );
}
