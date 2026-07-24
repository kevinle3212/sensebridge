#!/usr/bin/env bash
#
# open-xcode.sh — open the SenseBridge Xcode project.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
open "$REPO_ROOT/app/SenseBridge.xcodeproj"
