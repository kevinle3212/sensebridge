// Strict ESLint flat config for the Astro-based marketing site. Lints
// `.astro`, `.ts`, and `.js` (currently `scripts/generate-audio.js`).
//
// Type-aware typescript-eslint rules (`strictTypeChecked`) are scoped to
// `.ts`/`.js` files only, where `parserOptions.project` gives them real type
// information. Full type-aware linting inside `.astro` frontmatter isn't
// reliably supported by astro-eslint-parser yet, so `.astro` files get
// eslint-plugin-astro's own (non-type-aware) `recommended` +
// `jsx-a11y-strict` configs instead — the latter is Astro's a11y rule set,
// built on top of eslint-plugin-jsx-a11y.
//
// One carve-out from type-aware linting, non-type-aware
// (`eslint:recommended` + the shared hardening rules) instead:
//   - `eslint.config.mjs` itself — several plugins it imports
//     (`eslint-plugin-astro`, `eslint-plugin-security`) ship no type
//     declarations, so their config objects resolve as untyped/`any` and
//     trip `no-unsafe-*` on ordinary, correct usage.

import js from "@eslint/js";
import { defineConfig } from "eslint/config";
import tseslint from "typescript-eslint";
import astro from "eslint-plugin-astro";
import security from "eslint-plugin-security";
import prettierConfig from "eslint-config-prettier";
import globals from "globals";

// eslint-plugin-security's recommended config ships every rule at "warn" —
// bump them all to "error" so a security finding can't slip through as a
// non-blocking warning. Derived from the plugin's own rule set, so it stays
// correct if the plugin adds rules later.
const securityRulesAsErrors = Object.fromEntries(
  Object.keys(security.configs.recommended.rules).map((rule) => [rule, "error"]),
);

// Hardening/correctness rules shared by every file this config lints,
// regardless of type-awareness.
const sharedRules = {
  // Safety-framing surface (docs/safety-framing.md): never let output
  // strings ship un-reviewed.
  "no-console": ["error", { allow: ["warn", "error"] }],

  // Security hardening beyond eslint-plugin-security's defaults.
  "no-eval": "error",
  "no-implied-eval": "error",
  "no-new-func": "error",
  "no-script-url": "error",

  // Correctness / strictness beyond eslint:recommended.
  eqeqeq: ["error", "always"],
  "no-var": "error",
  "prefer-const": "error",
  "no-shadow": "error",
  "no-return-await": "error",
  "no-param-reassign": "error",
  curly: ["error", "all"],
  "no-else-return": ["error", { allowElseIf: false }],
  "no-throw-literal": "error",
  "no-duplicate-imports": "error",
  "no-unused-expressions": "error",
  "no-promise-executor-return": "error",
  "require-await": "error",
  "prefer-template": "error",
  "object-shorthand": ["error", "always"],
};

export default defineConfig(
  {
    ignores: ["node_modules/**", "dist/**", ".astro/**"],
  },
  js.configs.recommended,
  ...astro.configs["flat/recommended"],
  ...astro.configs["flat/jsx-a11y-strict"],
  {
    // Type-aware typescript-eslint rules — `.js`/`.mjs`/`.ts`, excluding the
    // carve-out above (see file header).
    files: ["**/*.{js,mjs,ts}"],
    ignores: ["eslint.config.mjs"],
    extends: [...tseslint.configs.strictTypeChecked, ...tseslint.configs.stylisticTypeChecked],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
      parserOptions: {
        project: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: { security },
    rules: {
      ...securityRulesAsErrors,
      ...sharedRules,

      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-non-null-assertion": "error",
      "@typescript-eslint/consistent-type-imports": "error",
      "@typescript-eslint/no-shadow": "error",
      "@typescript-eslint/restrict-template-expressions": ["error", { allowNumber: true }],
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_", caughtErrorsIgnorePattern: "^_" },
      ],
    },
  },
  {
    // `.astro` frontmatter/template — non-type-aware rules only (see file
    // header); astro-eslint-parser already wires up @typescript-eslint/parser
    // internally via the `flat/recommended` config above.
    files: ["**/*.astro"],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
    },
    rules: {
      ...sharedRules,
    },
  },
  {
    // Non-type-aware carve-out — see file header.
    files: ["eslint.config.mjs"],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
    },
    rules: {
      ...sharedRules,
    },
  },
  {
    // media-has-caption doesn't fit this element: the natural-voice
    // narration reads aloud content that's already fully visible as text in
    // main#main, so a caption track would just duplicate the page text
    // rather than add anything a screen-reader or sighted user doesn't
    // already have.
    files: ["src/components/ReadAloud.astro"],
    rules: {
      "astro/jsx-a11y/media-has-caption": "off",
    },
  },
  prettierConfig,
);
