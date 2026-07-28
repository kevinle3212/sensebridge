#!/usr/bin/env bash
#
# open-xcode.sh — open the SenseBridge Xcode project.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Xcode inherits the environment of whatever launched it, so loading .env here
# means build settings like BUNDLE_ID_PREFIX reach the GUI build too, not just
# command-line xcodebuild.
# shellcheck source=scripts/env.sh
. "$REPO_ROOT/scripts/env.sh"

open "$REPO_ROOT/app/SenseBridge.xcodeproj"
