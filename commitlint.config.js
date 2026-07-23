// Mirrors .githooks/commit-msg's bash regex: type(scope): subject, max 72
// chars for the subject specifically. This is the CI-enforced source of
// truth; the bash regex is the dependency-free local fallback when Node
// isn't installed (see .githooks/commit-msg and docs/TOOLING.md).
module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [
      2,
      "always",
      [
        "feat",
        "fix",
        "docs",
        "style",
        "refactor",
        "perf",
        "test",
        "build",
        "ci",
        "chore",
        "revert",
      ],
    ],
    "type-case": [2, "always", "lower-case"],
    "type-empty": [2, "never"],
    "scope-case": [2, "always", "lower-case"],
    "scope-empty": [0],
    "subject-empty": [2, "never"],
    "subject-full-stop": [0, "never", "."],
    "subject-max-length": [2, "always", 72],
    "header-max-length": [2, "always", 100],
  },
  ignores: [(message) => /^(Merge |Revert |fixup! |squash )/.test(message)],
};
