#!/usr/bin/env node
/**
 * check-catalog-coverage.mjs — fail the build if any String Catalog key is
 * missing an es or vi translation.
 *
 * Guardrail for docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
 * "Guardrails for the new tooling": Tasks 3, 19, and 20 must land new copy in
 * es/vi in the same commit as the en source, or SenseBridge's three-language
 * doctrine silently drifts to two. Read-only — never writes or
 * auto-translates anything.
 *
 * Run: node tools/check-catalog-coverage.mjs
 * Wired into `npm run check`.
 */
import { readFileSync } from "node:fs";

const REQUIRED_LOCALES = ["es", "vi"];

const catalogPaths = [
  "app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Resources/Localizable.xcstrings",
  "app/SenseBridge/Resources/Localizable.xcstrings",
  "app/SenseBridge/Resources/InfoPlist.xcstrings",
];

const failures = [];

for (const path of catalogPaths) {
  const catalog = JSON.parse(readFileSync(path, "utf8"));
  for (const [key, entry] of Object.entries(catalog.strings ?? {})) {
    const localizations = entry.localizations ?? {};
    // A key with no localizations at all is source-language-only metadata
    // (e.g. CFBundleName) — only check keys that carry at least one
    // translation, since those are the ones a reviewer intended to localize.
    if (Object.keys(localizations).length <= 1) continue;
    for (const locale of REQUIRED_LOCALES) {
      const value = localizations[locale]?.stringUnit?.value;
      if (!value || value.trim() === "") {
        failures.push(`${path}: "${key}" is missing a ${locale} translation`);
      }
    }
  }
}

if (failures.length > 0) {
  console.error(`check-catalog-coverage: ${failures.length} missing translation(s)\n`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}
console.log("check-catalog-coverage: every key with translations carries es and vi.");
