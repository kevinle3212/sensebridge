#!/usr/bin/env bash
#
# check-links.sh — every relative Markdown link in the repo resolves.
#
# Run locally with `npm run check:links`; .github/workflows/ci.yml's
# docs-links job runs this same script, which is why the failure output is
# GitHub's `::error file=` annotation format.
#
# Skips **/skills/* — skill and template content (e.g. the vendored bmad-*
# skills) intentionally contains placeholder links ({{path}}, ./filename.ext)
# that are examples, not real navigable docs.
#
# Also skips gitignored files and links to gitignored targets (GAPS.md,
# sessions/, deprecated/planning/, security/THREAT-MODEL.md, NOTES.local.md,
# node_modules/, ...): those are intentionally local-only and never reach the
# CI checkout, so their absence there isn't a broken link. Skipping the files
# themselves is what makes a local run match CI's — a clean checkout simply has
# no node_modules/*/README.md to walk into.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

fail=0
while IFS= read -r -d '' file; do
	if git check-ignore -q "$file" 2>/dev/null; then
		continue
	fi
	while read -r link; do
		case "$link" in
			http* | mailto:* | //*) continue ;;
		esac
		target="$(dirname "$file")/$link"
		if [ ! -e "$target" ] && ! git check-ignore -q "$target" 2>/dev/null; then
			echo "::error file=$file::broken relative link -> $link"
			fail=1
		elif [ -e "$target" ]; then
			# The target exists — but a link that climbs out of the checkout
			# resolves against whatever happens to sit beside it, so it can pass
			# here and fail in CI, where the neighbour is absent. Only checked
			# for existing targets: a missing one is already reported above, and
			# `cd` into its parent would fail and misreport every gitignored
			# path as an escape. Normalizing rather than pattern-matching `../`
			# keeps a `../` in the middle of an otherwise-inside path legal.
			normalized="$(cd "$(dirname "$target")" && pwd -P)/$(basename "$target")"
			case "$normalized" in
				"$REPO_ROOT"/*) ;;
				*)
					echo "::error file=$file::relative link escapes the repository -> $link"
					fail=1
					;;
			esac
		fi
	done < <(grep -oE '\]\(([^)#]+)' "$file" | sed -E 's/^\]\(//')
done < <(find . -path ./.git -prune -o -path '*/skills/*' -prune -o -name '*.md' -print0)

exit $fail
