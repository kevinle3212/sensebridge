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
#   device-test    build + test on the attached iPhone (signed, arm64, real ARKit)
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
		  device-test    build + test on the attached iPhone (signed, arm64)
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

# The test suite on real hardware. `cmd_test` above runs the same scheme in the
# Simulator, which CLAUDE.md is explicit does not count for this app: ARKit,
# LiDAR depth, Apple Intelligence, haptics, and the camera all produce nothing
# there, and only the device destination exercises signing and arm64.
#
# It names one failure that xcodebuild reports badly. When the app installs but
# will not launch, the cause appears only as "The application could not be
# launched because the Developer App Certificate is not trusted" inside an
# IDELaunchReport line, followed by a bare "** TEST FAILED **" — which reads as
# a broken test suite rather than a device-trust problem. So it is matched and
# pointed at the fix.
#
# Deliberately worded as a suggestion, not a diagnosis. It was seen once on
# 2026-08-19 and did not recur on the next run with nothing changed in between,
# so the trust tap is a thing to try rather than a known cause. Asserting more
# than that would send someone into Settings for a state that may already be
# fine.
cmd_device_test() {
	resolve_project
	local device log status
	device="$(resolve_device)"
	log="$(mktemp -t sensebridge-device-test)"
	# `tee` so the failure scan below sees the same bytes the user does, and
	# ${PIPESTATUS[0]} so xcodebuild's status survives the pipe — a plain `|`
	# would report tee's exit code and turn every failure into a pass.
	set +e
	xcodebuild build test "$PROJECT_FLAG" "$PROJECT_PATH" -scheme "$SCHEME" \
		-destination "platform=iOS,id=$device" -allowProvisioningUpdates 2>&1 |
		tee "$log"
	status=${PIPESTATUS[0]}
	set -e
	if [ "$status" -ne 0 ]; then
		if grep -q 'Developer App Certificate is not trusted' "$log"; then
			echo >&2
			echo "app.sh: the app installed but could not launch — xcodebuild reports the" >&2
			echo "        developer certificate as untrusted. Try re-running first: this" >&2
			echo "        has cleared on its own. If it persists, trust the certificate on" >&2
			echo "        the phone under Settings → General → VPN & Device Management." >&2
			echo "        See docs/ENVIRONMENT.md." >&2
		elif grep -q 'test runner failed to initialize for UI testing' "$log"; then
			# Reported by xcodebuild as "Authentication canceled. Canceled by
			# user." with nobody having cancelled anything — the phone locked
			# itself and the runner could not attach. CLAUDE.md calls out saying
			# this rather than reporting a bare failure, which is exactly what
			# the raw output does.
			echo >&2
			echo "app.sh: the UI test runner could not start on the device. The usual" >&2
			echo "        cause is a locked phone — unlock it, keep it awake, and run" >&2
			echo "        this again. \"Authentication canceled\" in the output above" >&2
			echo "        does not mean anyone cancelled anything." >&2
		fi
	fi
	rm -f "$log"
	return "$status"
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
	device-test) cmd_device_test ;;
	install) cmd_install ;;
	clean) cmd_clean ;;
	*)
		usage >&2
		exit 1
		;;
esac
