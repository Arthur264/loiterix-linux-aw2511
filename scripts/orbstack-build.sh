#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export DOCKER_HOST="unix://${HOME}/.orbstack/run/docker.sock"
mkdir -p out

usage() {
	echo "Usage: $0 [build|deb|clean]   # default: build" >&2
	echo "       $0 reset-cache         # wipe volume build/ccache state" >&2
	exit 1
}

cmd="${1:-build}"
case "$cmd" in
	build|deb|clean|distclean)
		BUILD_CMD="$cmd" docker compose run --rm --build kernel-builder
		ls -lh out
		;;
	reset-cache)
		docker compose down --volumes --remove-orphans
		echo "Removed kernel-build volume (objects + ccache)."
		;;
	-h|--help|help) usage ;;
	*) usage ;;
esac
