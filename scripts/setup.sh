#!/usr/bin/env bash
#
# setup.sh — check the local toolchain matches docs/ENVIRONMENT.md.
#
# Required tooling (blocks): Xcode/xcodebuild, Swift, Git.
# Swift lint/format tooling (advisory only until app/ exists;
# scripts/lint.sh no-ops the same way ci.yml does).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

check_required() {
	local name="$1" cmd="$2"
	if command -v "$cmd" >/dev/null 2>&1; then
		echo "ok   $name ($("$cmd" --version 2>&1 | head -1))"
	else
		echo "MISSING  $name — required, see docs/ENVIRONMENT.md" >&2
		FAIL=1
	fi
}

check_advisory() {
	local name="$1" cmd="$2"
	if command -v "$cmd" >/dev/null 2>&1; then
		echo "ok   $name ($("$cmd" --version 2>&1 | head -1))"
	else
		echo "advisory  $name not found — needed by scripts/lint.sh once app/ lands (brew install $cmd)"
	fi
}

echo "== Required =="
check_required "Xcode command line tools" xcodebuild
check_required "Swift" swift
check_required "Git" git

echo
echo "== Advisory (Swift lint/format, not yet required — app/ is unscaffolded) =="
check_advisory "SwiftLint" swiftlint
check_advisory "SwiftFormat" swiftformat
check_advisory "xcbeautify" xcbeautify

echo
echo "== Advisory (pre-commit secret/sensitive-file scanning) =="
check_advisory "gitleaks" gitleaks
check_advisory "Node (runs tools/check-sensitive-files.mjs)" node

echo
echo "== website/ (Node tooling: Stylelint, Prettier) =="
if [ -f "$REPO_ROOT/website/package.json" ]; then
	if command -v npm >/dev/null 2>&1; then
		(cd "$REPO_ROOT/website" && npm ci)
		echo "ok   website/ dependencies installed"
	else
		echo "advisory  npm not found — needed for website/ (brew install node)"
	fi
fi

echo
echo "== Git hooks =="
git -C "$REPO_ROOT" config core.hooksPath .githooks
echo "ok   core.hooksPath -> .githooks (secret scan + lint on commit, conventional-commit header check, build gate + main-push guard on push, manifest-change check on merge)"

echo
if [ "$FAIL" -ne 0 ]; then
	echo "One or more required tools are missing. See docs/ENVIRONMENT.md." >&2
	exit 1
fi
echo "Toolchain OK."
