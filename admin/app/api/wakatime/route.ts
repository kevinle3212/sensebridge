import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import { cached, tile } from "../../../lib/cache";

/** Node runtime: reads `~/.wakatime.cfg` and calls WakaTime server-side only. */
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** WakaTime's own stats are computed daily; two minutes is plenty. */
const TTL_SECONDS = 120;

/** Shape returned to the dashboard. */
interface WakaTimeSummary {
  range: string;
  humanReadableTotal: string;
  dailyAverage: string;
  languages: { name: string; percent: number; text: string }[];
  projects: { name: string; percent: number; text: string }[];
}

/**
 * Resolves the WakaTime API key.
 *
 * Prefers `WAKATIME_API_KEY` from the environment so a deployment can supply
 * it without a config file, and falls back to the `~/.wakatime.cfg` the editor
 * plugins already write — which is the whole reason this runs locally by
 * default (see admin/README.md).
 *
 * Read server-side only. A WakaTime key grants read access to the owner's full
 * coding history, so it must never reach a client bundle or a `NEXT_PUBLIC_*`
 * variable.
 */
async function resolveApiKey(): Promise<string> {
  const fromEnvironment = process.env.WAKATIME_API_KEY?.trim();
  if (fromEnvironment) {
    return fromEnvironment;
  }

  const configPath = path.join(homedir(), ".wakatime.cfg");
  // eslint-disable-next-line security/detect-non-literal-fs-filename -- path is built from homedir(), not input
  const contents = await readFile(configPath, "utf8");
  const match = /^\s*api_key\s*=\s*(\S+)\s*$/m.exec(contents);
  if (!match?.[1]) {
    throw new Error("no api_key in ~/.wakatime.cfg and WAKATIME_API_KEY is unset");
  }
  return match[1];
}

/** Fetches the owner's last-7-days coding summary. */
export async function GET(): Promise<Response> {
  const result = await tile("WakaTime", async () =>
    cached("wakatime", TTL_SECONDS, async () => {
      const key = await resolveApiKey();
      const response = await fetch("https://wakatime.com/api/v1/users/current/stats/last_7_days", {
        headers: { authorization: `Basic ${Buffer.from(key).toString("base64")}` },
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) {
        throw new Error(`WakaTime responded ${response.status}`);
      }

      const body = (await response.json()) as {
        data?: {
          human_readable_range?: unknown;
          human_readable_total?: unknown;
          human_readable_daily_average?: unknown;
          languages?: { name?: unknown; percent?: unknown; text?: unknown }[];
          projects?: { name?: unknown; percent?: unknown; text?: unknown }[];
        };
      };
      const data = body.data ?? {};
      const top = (entries: { name?: unknown; percent?: unknown; text?: unknown }[] = []) =>
        entries.slice(0, 5).map((entry) => ({
          name: String(entry.name ?? "unknown"),
          percent: Number(entry.percent ?? 0),
          text: String(entry.text ?? ""),
        }));

      return {
        range: String(data.human_readable_range ?? "last 7 days"),
        humanReadableTotal: String(data.human_readable_total ?? "—"),
        dailyAverage: String(data.human_readable_daily_average ?? "—"),
        languages: top(data.languages),
        projects: top(data.projects),
      } satisfies WakaTimeSummary;
    }),
  );

  return Response.json(result, { headers: { "cache-control": "private, no-store" } });
}
