import { exec } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import { cached, tile } from "../../../lib/cache";

/** Node runtime: shells out and reads files under the owner's home directory. */
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Local data, so a short TTL is only there to stop a reload storm from re-shelling. */
const TTL_SECONDS = 30;

const run = promisify(exec);

/** What each of the three tools can honestly report. */
interface ToolingSummary {
  rtk: { totalCommands: number; totalSaved: number; averageSavingsPercent: number } | null;
  caveman: { activeMode: string | null; modeChanges: { at: string; mode: string }[] };
  ponytail: { deferredShortcuts: number };
  note: string;
}

/**
 * `rtk gain --format json` — the one tool of the three with a real,
 * machine-readable savings figure.
 *
 * Lifetime totals, not this project's: `rtk gain -p` scopes to a project, but
 * the unscoped number is what the tool itself reports, and mislabelling a
 * lifetime figure as a project one is the exact fabrication this repo's
 * reporting rules forbid. The label in the UI says "lifetime".
 */
async function readRtk(): Promise<ToolingSummary["rtk"]> {
  const { stdout } = await run("rtk gain --format json", { timeout: 5000 });
  const parsed = JSON.parse(stdout) as {
    summary?: { total_commands?: unknown; total_saved?: unknown; avg_savings_pct?: unknown };
  };
  const summary = parsed.summary;
  if (!summary) {
    return null;
  }
  return {
    totalCommands: Number(summary.total_commands ?? 0),
    totalSaved: Number(summary.total_saved ?? 0),
    averageSavingsPercent: Number(summary.avg_savings_pct ?? 0),
  };
}

/**
 * Caveman's local state.
 *
 * **There is no savings data to show.** The plan this tile was written against
 * assumed `~/.claude/.caveman-history.jsonl` with per-session `output_tokens`
 * and `est_saved_tokens`. That file does not exist (checked 2026-08-12); what
 * the plugin actually writes is `.caveman-active` (the current level) and
 * `.caveman-mode-log.jsonl` (one row per level change, no token counts). So
 * this reports the mode and its history and stops there — inventing a savings
 * number from a mode log would be a fabrication, and at `lite` the plugin
 * declines to estimate savings even to its own `/caveman-stats`.
 */
async function readCaveman(): Promise<ToolingSummary["caveman"]> {
  const home = homedir();
  const readOptional = async (file: string): Promise<string | null> => {
    try {
      // eslint-disable-next-line security/detect-non-literal-fs-filename -- path is built from homedir()
      return await readFile(path.join(home, file), "utf8");
    } catch {
      return null;
    }
  };

  const activeMode = (await readOptional(".caveman-active"))?.trim() || null;
  const log = await readOptional(".caveman-mode-log.jsonl");
  const modeChanges = (log ?? "")
    .split("\n")
    .filter((line) => line.trim())
    .flatMap((line) => {
      try {
        const row = JSON.parse(line) as { ts?: unknown; mode?: unknown };
        return [{ at: new Date(Number(row.ts ?? 0)).toISOString(), mode: String(row.mode ?? "?") }];
      } catch {
        return [];
      }
    })
    .slice(-10);

  return { activeMode, modeChanges };
}

/**
 * Ponytail's only real per-repo figure: a debt count, not a savings percent.
 *
 * `ponytail-gain` prints fixed benchmark medians rather than anything measured
 * against this repo, so there is no honest savings number to surface. What is
 * real is the count of deliberate shortcut markers left in the code.
 */
async function readPonytail(repoRoot: string): Promise<ToolingSummary["ponytail"]> {
  try {
    const { stdout } = await run(
      `grep -rnE '(#|//) ?ponytail:' . --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=graphify-out --exclude-dir=.next | wc -l`,
      { cwd: repoRoot, timeout: 10_000 },
    );
    return { deferredShortcuts: Number(stdout.trim()) };
  } catch {
    // `grep` exits non-zero when it matches nothing, which is a real answer.
    return { deferredShortcuts: 0 };
  }
}

/** Reports what the three local dev tools can actually prove. */
export async function GET(): Promise<Response> {
  const repoRoot = path.resolve(process.cwd(), "..");
  const result = await tile("Tooling", async () =>
    cached("tooling", TTL_SECONDS, async () => {
      const [rtk, caveman, ponytail] = await Promise.all([
        readRtk().catch(() => null),
        readCaveman(),
        readPonytail(repoRoot),
      ]);
      return {
        rtk,
        caveman,
        ponytail,
        note: "Read from this machine. A hosted deployment sees none of it — see admin/README.md.",
      } satisfies ToolingSummary;
    }),
  );

  return Response.json(result, { headers: { "cache-control": "private, no-store" } });
}
