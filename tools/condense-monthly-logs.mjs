#!/usr/bin/env node
// Condenses last calendar month's sessions/<YYYY-MM-DD>/*.md files into one
// sessions/<YYYY-MM>/SESSIONS.md, then removes the per-day directories —
// sessions/ is gitignored local scratch, so this is a plain merge, not a
// history rewrite. Audit reports under audits/ are append-only (see
// audits/AGENT-GUIDE.md) and are never moved, edited, or deleted here;
// instead this builds a derived audits/<YYYY-MM>/INDEX.md linking to that
// month's reports in place.
//
// Usage: node tools/condense-monthly-logs.mjs [--month=YYYY-MM]
// Defaults to the month before the current one.

import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));

function targetMonth() {
  const arg = process.argv.find((a) => a.startsWith("--month="));
  if (arg) return arg.split("=")[1];
  const now = new Date();
  const prev = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  return `${prev.getFullYear()}-${String(prev.getMonth() + 1).padStart(2, "0")}`;
}

function condenseSessions(month) {
  const sessionsDir = join(repoRoot, "sessions");
  let dayDirs;
  try {
    dayDirs = readdirSync(sessionsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory() && d.name.startsWith(month))
      .map((d) => d.name)
      .sort();
  } catch {
    return { count: 0 };
  }

  const chunks = [];
  for (const day of dayDirs) {
    const dayPath = join(sessionsDir, day);
    const files = readdirSync(dayPath)
      .filter((f) => f.endsWith(".md"))
      .sort();
    for (const f of files) chunks.push(readFileSync(join(dayPath, f), "utf8").trimEnd());
  }
  if (chunks.length === 0) return { count: 0 };

  const outDir = join(sessionsDir, month);
  mkdirSync(outDir, { recursive: true });
  const outPath = join(outDir, "SESSIONS.md");
  writeFileSync(outPath, chunks.join("\n\n---\n\n") + "\n");

  for (const day of dayDirs) rmSync(join(sessionsDir, day), { recursive: true, force: true });

  return { count: chunks.length, outPath };
}

function indexAudits(month) {
  const auditsDir = join(repoRoot, "audits");
  const compact = month.replace("-", "");
  const categories = readdirSync(auditsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !["scripts", "templates"].includes(d.name))
    .map((d) => d.name)
    .sort();

  const entries = [];
  for (const category of categories) {
    const catDir = join(auditsDir, category);
    const files = readdirSync(catDir).filter((f) => f.endsWith(".md") && f.startsWith(compact));
    for (const file of files.sort()) {
      const text = readFileSync(join(catDir, file), "utf8");
      const title = (text.match(/^#\s+(.+)$/m) || [, file])[1];
      entries.push({ category, file, title });
    }
  }
  if (entries.length === 0) return { count: 0 };

  const outDir = join(auditsDir, month);
  mkdirSync(outDir, { recursive: true });
  const lines = [
    `# Audits index — ${month}`,
    "",
    "Generated index of that month's append-only audit reports — derived and",
    "safe to regenerate. The reports it links to are never moved, edited, or",
    "deleted (see `audits/AGENT-GUIDE.md`).",
    "",
    "| Category | Report | Title |",
    "| --- | --- | --- |",
    ...entries.map((e) => `| ${e.category} | [\`${e.file}\`](../${e.category}/${e.file}) | ${e.title} |`),
    "",
  ];
  const outPath = join(outDir, "INDEX.md");
  writeFileSync(outPath, lines.join("\n"));
  return { count: entries.length, outPath };
}

const month = targetMonth();
const sessions = condenseSessions(month);
const audits = indexAudits(month);

console.log(`Month: ${month}`);
console.log(
  sessions.count ? `Sessions: condensed ${sessions.count} file(s) into ${sessions.outPath}` : "Sessions: nothing to condense",
);
console.log(
  audits.count ? `Audits: indexed ${audits.count} report(s) into ${audits.outPath}` : "Audits: nothing to index",
);
