#!/usr/bin/env bash
#
# new-audit.sh — generate a timestamped audit report from the shared template.
#
# Usage:
#   audits/scripts/new-audit.sh <type> "<short title>"
#
# <type> must be one of the category directories under audits/. The report is
# written to audits/<type>/<UTC-timestamp>-<slug>.md with git metadata
# prefilled.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUDITS_DIR="$REPO_ROOT/audits"
TEMPLATE="$AUDITS_DIR/templates/audit-template.md"

VALID_TYPES="general accessibility safety-framing privacy security performance model-license documentation testing dependencies"

usage() {
	echo "Usage: audits/scripts/new-audit.sh <type> \"<short title>\"" >&2
	echo "  <type> one of: $VALID_TYPES" >&2
	exit 1
}

[ "$#" -ge 1 ] || usage
TYPE="$1"
TITLE_RAW="${2:-Untitled audit}"

# Validate type against the known category directories.
case " $VALID_TYPES " in
	*" $TYPE "*) : ;;
	*)
		echo "error: unknown audit type '$TYPE'" >&2
		usage
		;;
esac

[ -f "$TEMPLATE" ] || {
	echo "error: template not found at $TEMPLATE" >&2
	exit 1
}

# Collect metadata (tolerant of detached HEAD / shallow clones).
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FILE_STAMP="$(date -u +%Y%m%d-%H%M%S)"
BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
AUTHOR="$(git -C "$REPO_ROOT" config user.name 2>/dev/null || echo unknown)"

# Build a filesystem-safe slug from the title.
SLUG="$(printf '%s' "$TITLE_RAW" \
	| tr '[:upper:]' '[:lower:]' \
	| sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
[ -n "$SLUG" ] || SLUG="audit"
TITLE="$(printf '%s' "$TITLE_RAW" | sed 's/[&|]/ /g')"

OUT_DIR="$AUDITS_DIR/$TYPE"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/$FILE_STAMP-$SLUG.md"

# Substitute the template placeholders. Values are pre-sanitized above.
sed \
	-e "s|{{TITLE}}|$TITLE|g" \
	-e "s|{{TYPE}}|$TYPE|g" \
	-e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
	-e "s|{{BRANCH}}|$BRANCH|g" \
	-e "s|{{COMMIT}}|$COMMIT|g" \
	-e "s|{{AUTHOR}}|$AUTHOR|g" \
	"$TEMPLATE" >"$OUT"

echo "Created $OUT"
