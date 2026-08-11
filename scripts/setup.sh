#!/usr/bin/env bash
#
# setup.sh — check the local toolchain matches docs/ENVIRONMENT.md, and
# optionally install what's missing.
#
# Required tooling (blocks): Git everywhere; Xcode/xcodebuild + Swift on
# macOS only, since app/ is a macOS-only Xcode project (see
# docs/ENVIRONMENT.md#platform-support) — not applicable on Linux/Windows,
# where this script instead checks the website/docs/tooling path. Windows
# means Git Bash or WSL2 here (see docs/ENVIRONMENT.md#platform-support) —
# this is a bash script either way, so no separate Windows code path exists.
#
# Advisory tooling (report, and offer to install): Swift lint/format
# (macOS-only), secret/sensitive-file scanning, shell/workflow/dependency
# linters. Installed via Homebrew — works on macOS and Linuxbrew, which is
# why the install offer is not gated to Darwin. Root and website/ npm
# dependencies (eslint, prettier, markdownlint-cli2, commitlint, Stylelint,
# etc.) are handled by `npm ci`, not this per-tool path.
#
# Flags:
#   -y, --yes         non-interactive: install every missing advisory tool
#                      without prompting (for scripted/CI use)
#   -n, --no-install   never prompt or install; report only (this was the
#                      only behavior before interactive install existed —
#                      also the default when stdin isn't a terminal)
#   -h, --help         print this help and exit
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
AUTO_YES=0
NO_INSTALL=0

usage() {
	sed -n '3,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
	case "$1" in
		-y | --yes)
			AUTO_YES=1
			;;
		-n | --no-install)
			NO_INSTALL=1
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "setup.sh: unrecognized argument '$1' (see --help)" >&2
			exit 2
			;;
	esac
	shift
done

# shellcheck source=scripts/env.sh
. "$REPO_ROOT/scripts/env.sh"

OK_TOOLS=()
INSTALLED_TOOLS=()
FAILED_TOOLS=()
SKIPPED_TOOLS=()

have_brew() { command -v brew >/dev/null 2>&1; }

# Interactive per-tool prompt. -y answers every prompt yes; -n (or a
# non-terminal stdin, e.g. piped into `sh`) answers every prompt no without
# asking, matching the pre-existing report-only behavior.
confirm() {
	local prompt="$1" reply
	if [ "$AUTO_YES" -eq 1 ]; then
		return 0
	fi
	if [ "$NO_INSTALL" -eq 1 ] || [ ! -t 0 ]; then
		return 1
	fi
	read -r -p "$prompt [y/N] " reply || return 1
	case "$reply" in
		[Yy]*) return 0 ;;
		*) return 1 ;;
	esac
}

# Runs an install command, capturing its output to tmp/ so a failure prints
# a short tail instead of flooding the terminal with the full brew/npm log.
# The full log path is always echoed so nothing is actually lost.
run_install() {
	local name="$1" log_slug="$2"
	shift 2
	local log="$REPO_ROOT/tmp/setup-install-${log_slug}.log"
	mkdir -p "$REPO_ROOT/tmp"
	echo "installing  $name ($*)"
	if "$@" >"$log" 2>&1; then
		rm -f "$log"
		return 0
	fi
	echo "FAILED      $name — '$*' exited non-zero. Last 15 lines of $log:" >&2
	tail -n 15 "$log" >&2
	return 1
}

check_required() {
	local name="$1" cmd="$2" formula="${3:-}"
	if command -v "$cmd" >/dev/null 2>&1; then
		OK_TOOLS+=("$name")
		echo "ok          $name ($("$cmd" --version 2>&1 | head -1))"
		return
	fi
	if [ -n "$formula" ] && have_brew && confirm "install $name via 'brew install $formula'?"; then
		if run_install "$name" "$formula" brew install "$formula"; then
			INSTALLED_TOOLS+=("$name")
			echo "ok          $name installed"
			return
		fi
		FAILED_TOOLS+=("$name — brew install $formula failed, see log above")
	fi
	echo "MISSING     $name — required, see docs/ENVIRONMENT.md" >&2
	SKIPPED_TOOLS+=("$name — required, see docs/ENVIRONMENT.md")
	FAIL=1
}

check_advisory() {
	local name="$1" cmd="$2" formula="$3" context="$4"
	if command -v "$cmd" >/dev/null 2>&1; then
		OK_TOOLS+=("$name")
		echo "ok          $name ($("$cmd" --version 2>&1 | head -1))"
		return
	fi

	if have_brew; then
		if confirm "install $name via 'brew install $formula'? ($context)"; then
			if run_install "$name" "$formula" brew install "$formula"; then
				INSTALLED_TOOLS+=("$name")
				echo "ok          $name installed"
				return
			fi
			FAILED_TOOLS+=("$name — brew install $formula failed, see log above")
			return
		fi
		SKIPPED_TOOLS+=("$name — $context (brew install $formula)")
		echo "advisory    $name not found — $context (brew install $formula)"
		return
	fi

	SKIPPED_TOOLS+=("$name — $context (brew install $formula; install Homebrew first: https://brew.sh)")
	echo "advisory    $name not found — $context (brew install $formula; install Homebrew first: https://brew.sh)"
}

echo "== Required =="
if [ "$(uname -s)" = Darwin ]; then
	# `xcode-select --install` opens a GUI installer with no scriptable
	# confirmation step, so this stays report-only rather than routing
	# through run_install like the Homebrew-installable tools below.
	if command -v xcodebuild >/dev/null 2>&1; then
		OK_TOOLS+=("Xcode command line tools")
		echo "ok          Xcode command line tools ($(xcodebuild -version 2>&1 | head -1))"
	else
		echo "MISSING     Xcode command line tools — required, run 'xcode-select --install' (or install Xcode from the App Store), see docs/ENVIRONMENT.md" >&2
		SKIPPED_TOOLS+=("Xcode command line tools — run 'xcode-select --install'")
		FAIL=1
	fi
	if command -v swift >/dev/null 2>&1; then
		OK_TOOLS+=("Swift")
		echo "ok          Swift ($(swift --version 2>&1 | head -1))"
	else
		echo "MISSING     Swift — required, comes with Xcode command line tools, see docs/ENVIRONMENT.md" >&2
		SKIPPED_TOOLS+=("Swift — comes with Xcode command line tools")
		FAIL=1
	fi
else
	echo "n/a         Xcode command line tools — app/ is macOS-only, not required on $(uname -s) (see docs/ENVIRONMENT.md)"
	echo "n/a         Swift — app/ is macOS-only, not required on $(uname -s) (see docs/ENVIRONMENT.md)"
fi
check_required "Git" git git

echo
echo "== Advisory (Swift lint/format, not yet required — app/ is unscaffolded) =="
if [ "$(uname -s)" = Darwin ]; then
	check_advisory "SwiftLint" swiftlint swiftlint "needed by scripts/lint.sh once app/ lands"
	check_advisory "SwiftFormat" swiftformat swiftformat "needed by scripts/lint.sh once app/ lands"
	check_advisory "xcbeautify" xcbeautify xcbeautify "readable xcodebuild output in scripts/lint.sh and CI"
else
	echo "n/a         SwiftLint / SwiftFormat / xcbeautify — app/ is macOS-only, not applicable on $(uname -s)"
fi

echo
echo "== Advisory (pre-commit secret/sensitive-file scanning) =="
check_advisory "gitleaks" gitleaks gitleaks "npm run check:secrets, .githooks/pre-commit"
check_advisory "ggshield" ggshield ggshield "GitGuardian scan; run 'ggshield auth login' after install"
check_advisory "actionlint" actionlint actionlint "lints .github/workflows/*.yml, npm run lint:actions"

echo
echo "== Advisory (shell and dependency linting) =="
check_advisory "shellcheck" shellcheck shellcheck "npm run lint:shell, .githooks/pre-commit"
check_advisory "osv-scanner" osv-scanner osv-scanner "npm run check:deps, .githooks/pre-push"

echo
echo "== Repo root (Node tooling: commitlint, eslint, prettier, markdownlint-cli2) =="
if command -v npm >/dev/null 2>&1; then
	if run_install "root npm dependencies" "npm-ci-root" npm --prefix "$REPO_ROOT" ci; then
		OK_TOOLS+=("root npm dependencies")
		echo "ok          root dependencies installed (commitlint, eslint, prettier, markdownlint-cli2)"
	else
		FAILED_TOOLS+=("root npm dependencies — npm ci failed, see log above")
	fi
else
	echo "advisory    npm not found — commit-msg falls back to its dependency-free bash regex, and lint:mjs/lint:md/format:mjs are unavailable, until installed (brew install node)"
	SKIPPED_TOOLS+=("npm (root) — brew install node")
fi

echo
echo "== website/ (Node tooling: Stylelint, ESLint, Prettier) =="
if [ -f "$REPO_ROOT/website/package.json" ]; then
	if command -v npm >/dev/null 2>&1; then
		if run_install "website/ npm dependencies" "npm-ci-website" npm --prefix "$REPO_ROOT/website" ci; then
			OK_TOOLS+=("website/ npm dependencies")
			echo "ok          website/ dependencies installed"
		else
			FAILED_TOOLS+=("website/ npm dependencies — npm ci failed, see log above")
		fi
	else
		echo "advisory    npm not found — needed for website/ (brew install node)"
		SKIPPED_TOOLS+=("npm (website/) — brew install node")
	fi
fi

echo
echo "== Git hooks =="
git -C "$REPO_ROOT" config core.hooksPath .githooks
echo "ok          core.hooksPath -> .githooks (secret scan + lint + actionlint on commit, conventional-commit header check via commitlint or its bash fallback, build gate + main-push guard on push, manifest-change check on merge). Commitlint and actionlint also run blocking in CI regardless of local hook state."

echo
echo "== Summary =="
echo "ok: ${#OK_TOOLS[@]}   installed: ${#INSTALLED_TOOLS[@]}   advisory-skipped: ${#SKIPPED_TOOLS[@]}   failed: ${#FAILED_TOOLS[@]}"
if [ "${#FAILED_TOOLS[@]}" -gt 0 ]; then
	echo
	echo "Failed installs:"
	for entry in "${FAILED_TOOLS[@]}"; do
		echo "  - $entry"
	done
fi
if [ "${#SKIPPED_TOOLS[@]}" -gt 0 ] && [ "$NO_INSTALL" -ne 1 ]; then
	echo
	echo "Still missing (advisory — re-run with -y to auto-install, or install manually):"
	for entry in "${SKIPPED_TOOLS[@]}"; do
		echo "  - $entry"
	done
fi

echo
if [ "$FAIL" -ne 0 ]; then
	echo "One or more required tools are missing. See docs/ENVIRONMENT.md." >&2
	exit 1
fi
if [ "${#FAILED_TOOLS[@]}" -gt 0 ]; then
	echo "Required tools are present; some advisory installs failed — see above. Toolchain usable, not complete." >&2
	exit 0
fi
echo "Toolchain OK."
