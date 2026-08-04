#!/usr/bin/env bash
#
# website-container.sh — run website/ inside the Node 24 image from
# .devcontainer/devcontainer.json, without going through VS Code's Dev
# Containers UI.
#
# Usage: scripts/website-container.sh <command>
#
#   bind     bind-mount this checkout, npm install, drop into a shell
#   volume   clone into a named Docker volume (persists across runs,
#            faster I/O than a bind mount), npm install, drop into a shell
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

IMAGE=mcr.microsoft.com/devcontainers/javascript-node:24
VOLUME=sensebridge-src

usage() {
	cat <<-'EOF'
		Usage: scripts/website-container.sh <command>

		  bind     bind-mount this checkout, npm install, drop into a shell
		  volume   clone into a named Docker volume, npm install, drop into a shell
	EOF
}

cmd_bind() {
	docker run -it --rm \
		-v "$REPO_ROOT":/workspaces/sensebridge \
		-w /workspaces/sensebridge/website \
		"$IMAGE" \
		bash -lc "npm install && exec bash"
}

cmd_volume() {
	local repo_url
	repo_url="$(git config --get remote.origin.url)"
	docker volume create "$VOLUME" >/dev/null
	docker run -it --rm \
		-v "$VOLUME":/workspaces/sensebridge \
		-w /workspaces/sensebridge \
		"$IMAGE" \
		bash -lc '[ -d .git ] || git clone "'"$repo_url"'" .; cd website && npm install && exec bash'
}

case "${1:-}" in
	bind) cmd_bind ;;
	volume) cmd_volume ;;
	*)
		usage >&2
		exit 1
		;;
esac
