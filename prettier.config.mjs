// prettier.config.mjs — root Prettier config, paired with eslint.config.mjs.
// Same scope as that file: the repo's hand-authored .mjs tooling
// (`.claude/hooks/*.mjs`, `.claude/hooks/global/*.mjs`, `.cursor/hooks/*.mjs`,
// `tools/*.mjs`) plus this file and eslint.config.mjs themselves.
//
// Everything under a `skills/` directory is out of scope, same reason as
// eslint.config.mjs's own header comment: `impeccable`'s vendor-managed
// .mjs gets overwritten on the next `npx impeccable update` run, so a
// formatting pass can't survive.
//
// website/ has its own .prettierrc — this config does not touch it.
//
// Run: npm run format:mjs (check) / npm run format:mjs:fix (write)

export default {
  printWidth: 100,
  tabWidth: 2,
  useTabs: false,
  semi: true,
  singleQuote: false,
  trailingComma: "all",
  arrowParens: "always",
  endOfLine: "lf",
};
