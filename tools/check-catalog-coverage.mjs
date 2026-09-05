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

/**
 * Whether one locale's entry actually carries translated text.
 *
 * A key is either a flat `stringUnit` or, when the source string counts
 * something, a `variations.plural` block of per-category units — "raised 1
 * alerts" is the bug that shape exists to prevent. Checking only `stringUnit`
 * would report every correctly-pluralised key as untranslated and push authors
 * back toward the ungrammatical flat form.
 *
 * @param {object|undefined} localization One locale's entry from a catalog key.
 * @returns {boolean} True when at least one non-empty value is present and no
 *   declared plural category is left blank.
 */
function hasTranslation(localization) {
  if (!localization) return false;
  const flat = localization.stringUnit?.value;
  if (typeof flat === "string" && flat.trim() !== "") return true;
  const categories = Object.values(localization.variations?.plural ?? {});
  if (categories.length === 0) return false;
  return categories.every((category) => {
    const value = category?.stringUnit?.value;
    return typeof value === "string" && value.trim() !== "";
  });
}

for (const path of catalogPaths) {
  const catalog = JSON.parse(readFileSync(path, "utf8"));
  for (const [key, entry] of Object.entries(catalog.strings ?? {})) {
    const localizations = entry.localizations ?? {};
    // A key with no localizations at all is source-language-only metadata
    // (e.g. CFBundleName) — only check keys that carry at least one
    // translation, since those are the ones a reviewer intended to localize.
    if (Object.keys(localizations).length <= 1) continue;
    for (const locale of REQUIRED_LOCALES) {
      if (!hasTranslation(localizations[locale])) {
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
