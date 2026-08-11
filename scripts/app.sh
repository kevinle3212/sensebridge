#!/usr/bin/env bash
#
# app.sh — one entry point for building, testing, and installing the iOS app.
#
# Every one of these was previously a copy-paste block: the simulator build in
# .githooks/pre-push (which now calls `app.sh build`) and the device
# build/install recipe in CLAUDE.md's "Hand it back testable" section.
#
# .github/workflows/ci.yml is the deliberate exception — it still inlines its
# own simulator build and local-package test loop, because the CI job is the
# thing this file is supposed to mirror, not the other way round. Keep the
# project detection below in sync with ci.yml's `detect` step when it changes.
#
# Usage: scripts/app.sh <command>
#
#   build          simulator build (no code signing)
#   test           simulator build + test
#   package-test   test every local package under app/Packages/*
#   device-build   build for the attached iPhone (signed)
#   install        device-build, then install onto the attached iPhone
#   clean          delete the scheme's build products
#
# The device commands need the phone unlocked and trusted — otherwise the
# developer disk image never mounts and the failure reads as a build error.
#
# Deliberately bash-3.2 compatible (no `mapfile`), since that is what
# /bin/bash still is on macOS.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Xcode build settings such as BUNDLE_ID_PREFIX come from .env, the same way
# scripts/open-xcode.sh feeds them to the GUI build.
# shellcheck source=scripts/env.sh
. "$REPO_ROOT/scripts/env.sh"

SCHEME=SenseBridge
SIMULATOR_DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=latest'

# Set by resolve_project; the `-project <path>` / `-workspace <path>` pair
# every xcodebuild invocation below needs.
PROJECT_FLAG=""
PROJECT_PATH=""

usage() {
	cat <<-'EOF'
		Usage: scripts/app.sh <command>

		  build          simulator build (no code signing)
		  test           simulator build + test
		  package-test   test every local package under app/Packages/*
		  device-build   build for the attached iPhone (signed)
		  install        device-build, then install onto the attached iPhone
		  clean          delete the scheme's build products
	EOF
}

# Locates the Xcode project under app/, or exits 0 when there is none — the
# same no-op-until-scaffolded behavior scripts/lint.sh and ci.yml have.
resolve_project() {
	PROJECT_PATH="$(find app -maxdepth 1 \( -name '*.xcworkspace' -o -name '*.xcodeproj' \) -print -quit)"
	if [ -z "$PROJECT_PATH" ]; then
		echo "app.sh: no Xcode project found under app/ — skipping."
		exit 0
	fi
	if [ "${PROJECT_PATH##*.}" = "xcworkspace" ]; then
		PROJECT_FLAG=-workspace
	else
		PROJECT_FLAG=-project
	fi
}

# Echoes the UDID of the first attached iPhone. Matched by shape rather than by
# column: device names contain spaces, so positional awk fields silently return
# the wrong token.
resolve_device() {
	local udid
	udid="$(xcrun devicectl list devices | awk '/iPhone/ && \
		match($0, /[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/) \
		{print substr($0, RSTART, RLENGTH); exit}')"
	if [ -z "$udid" ]; then
		echo "app.sh: no iPhone attached — connect one, unlock it, and trust this Mac." >&2
		exit 1
	fi
	printf '%s\n' "$udid"
}

# Echoes the directory holding the .app that a build for $1 produces.
built_products_dir() {
	xcodebuild "$PROJECT_FLAG" "$PROJECT_PATH" -scheme "$SCHEME" \
		-destination "$1" -showBuildSettings |
		awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $2; exit}'
}

cmd_build() {
	resolve_project
	xcodebuild build "$PROJECT_FLAG" "$PROJECT_PATH" -scheme "$SCHEME" \
		-destination "$SIMULATOR_DESTINATION" CODE_SIGNING_ALLOWED=NO
}

cmd_test() {
	resolve_project
	xcodebuild build test "$PROJECT_FLAG" "$PROJECT_PATH" -scheme "$SCHEME" \
		-destination "$SIMULATOR_DESTINATION" CODE_SIGNING_ALLOWED=NO
}

cmd_package_test() {
	shopt -s nullglob
	local manifest dir name found=0
	for manifest in app/Packages/*/Package.swift; do
		found=1
		dir="$(dirname "$manifest")"
		name="$(basename "$dir")"
		echo "== $dir =="
		(cd "$dir" && xcodebuild test -scheme "$name" -destination 'platform=macOS')
	done
	if [ "$found" = 0 ]; then
		echo "app.sh: no local packages under app/Packages/ — nothing to test."
	fi
}

# Both device commands pass -allowProvisioningUpdates. The project signs
# automatically, but xcodebuild treats automatic signing as *disabled* unless
# this flag is present: with no matching profile already on disk it refuses to
# fetch one and fails with "No profiles for '<bundle id>' were found", which
# reads like a project misconfiguration rather than a missing flag. Xcode's GUI
# passes it implicitly, so the same project builds there and not here. Simulator
# builds above do not need it — they set CODE_SIGNING_ALLOWED=NO instead.
cmd_device_build() {
	resolve_project
	local device
	device="$(resolve_device)"
	xcodebuild build "$PROJECT_FLAG" "$PROJECT_PATH" -scheme "$SCHEME" \
		-destination "platform=iOS,id=$device" -allowProvisioningUpdates
}

cmd_install() {
	resolve_project
	local device products
	device="$(resolve_device)"
	xcodebuild build "$PROJECT_FLAG" "$PROJECT_PATH" -scheme "$SCHEME" \
		-destination "platform=iOS,id=$device" -allowProvisioningUpdates
	products="$(built_products_dir "platform=iOS,id=$device")"
	xcrun devicectl device install app --device "$device" "$products/$SCHEME.app"
	# Clears the Stop-hook gate in .claude/hooks/require-device-install.sh, which
	# blocks a turn from reporting done while app/ Swift changes have never
	# reached the phone. Stamped here, after the install command has succeeded,
	# so a failed install cannot satisfy the gate. tmp/ is gitignored.
	mkdir -p "$REPO_ROOT/tmp" && touch "$REPO_ROOT/tmp/.last-app-install"
}

cmd_clean() {
	resolve_project
	xcodebuild clean "$PROJECT_FLAG" "$PROJECT_PATH" -scheme "$SCHEME"
}

case "${1:-}" in
	build) cmd_build ;;
	test) cmd_test ;;
	package-test) cmd_package_test ;;
	device-build) cmd_device_build ;;
	install) cmd_install ;;
	clean) cmd_clean ;;
	*)
		usage >&2
		exit 1
		;;
esac
