#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export DOCKER_HOST="unix://${HOME}/.orbstack/run/docker.sock"

usage() {
	echo "Usage: $0 [build|deb|clean]   # default: build" >&2
	echo "       $0 reset-cache         # wipe volume build/ccache state" >&2
	exit 1
}

format_duration() {
	local s=$1
	printf '%02d:%02d:%02d' $((s / 3600)) $(((s % 3600) / 60)) $((s % 60))
}

cmd="${1:-build}"
case "$cmd" in
	build|deb|clean|distclean)
		start_time=$(date +%s)
		rm -rf out
		mkdir -p out
		BUILD_CMD="$cmd" docker compose run --rm --build kernel-builder
		ls -lh out
		elapsed=$(( $(date +%s) - start_time ))
		echo "Build time: $(format_duration "$elapsed")"
		;;
	reset-cache)
		docker compose down --volumes --remove-orphans
		echo "Removed kernel-build volume (objects + ccache)."
		;;
	-h|--help|help) usage ;;
	*) usage ;;
esac
