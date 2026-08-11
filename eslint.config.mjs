// eslint.config.mjs — root ESLint config for the repo's hand-authored .mjs
// tooling: `.claude/hooks/*.mjs`, `.claude/hooks/global/*.mjs`, `.cursor/hooks/*.mjs`, `tools/*.mjs`.
//
// Everything under a `skills/` directory is out of scope on purpose: the
// `impeccable` skill's .mjs files are vendor-managed by
// `npx impeccable install/update` (mirrored into 3 harness dirs), so a
// hand-fixed quote style there is overwritten on the next run. Every other
// skill lives once under `.agents/skills/` (see `.agents/manifest.json`),
// with harness dirs symlinked back — no separate regeneration step.
//
// website/ has its own eslint.config.mjs + Prettier (singleQuote: false)
// covering website/*.mjs already; this config does not touch it.
//
// Run: npm run lint:mjs

export default [
  {
    files: [
      ".claude/hooks/*.mjs",
      ".claude/hooks/global/*.mjs",
      ".cursor/hooks/*.mjs",
      "tools/*.mjs",
    ],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
    },
    rules: {
      quotes: ["error", "double", { avoidEscape: true }],
    },
  },
];
