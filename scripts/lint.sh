#!/usr/bin/env bash
#
# lint.sh — run SwiftFormat + SwiftLint before committing.
#
# Mirrors the project-detection in .github/workflows/ci.yml: no-ops with a
# clear message until a Swift package or Xcode project exists under app/.
# Keep the detection logic in sync with ci.yml if it changes.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if compgen -G "Package.swift" >/dev/null || compgen -G "app/Package.swift" >/dev/null; then
	KIND=spm
elif compgen -G "app/*.xcodeproj" >/dev/null || compgen -G "app/*.xcworkspace" >/dev/null; then
	KIND=xcode
else
	KIND=none
fi

if [ "$KIND" = none ]; then
	echo "No Swift package or Xcode project found under app/ yet — skipping lint."
	exit 0
fi

for tool in swiftformat swiftlint; do
	command -v "$tool" >/dev/null 2>&1 || {
		echo "error: $tool not found (brew install $tool). See docs/ENVIRONMENT.md." >&2
		exit 1
	}
done

echo "== SwiftFormat (lint mode) =="
swiftformat --lint app

echo "== SwiftLint (strict) =="
swiftlint lint --strict app
