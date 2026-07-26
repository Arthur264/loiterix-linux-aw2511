#!/bin/sh
set -eu

# Host (macOS APFS) → case-sensitive /build volume, then build with ccache + kept objects.

HOST=/host
ROOT=/build/src
KERNEL=$ROOT/src
OUT=/out

mkdir -p "$ROOT" /build/ccache "$OUT"

# --- sync ---------------------------------------------------------------
# Drop packaging leftovers that contain excluded *.o (blocks rsync --delete).
# Keep usr/ source (Kconfig); only remove installed header subdirs.
rm -rf "$KERNEL/debian"
rm -rf "$KERNEL/usr/include"/*/

rsync -a --delete --exclude-from=/rsync-excludes "$HOST/" "$ROOT/"
mkdir -p "$ROOT/.git/modules"
rsync -a "$HOST/.git/modules/" "$ROOT/.git/modules/"

# --- APFS case collisions (e.g. xt_DSCP.c / xt_dscp.c) -------------------
git -C "$KERNEL" ls-files | awk '{
	k = tolower($0)
	if (k in seen) { print seen[k]; print $0 } else seen[k] = $0
}' | while IFS= read -r path; do
	[ -n "$path" ] || continue
	rm -f "$KERNEL/$path"
	git -C "$KERNEL" checkout-index -f -- "$path"
done

# --- debian patches (radxa*.config) -------------------------------------
cd "$ROOT"
rm -rf .pc
dpkg-source --before-build .
test -f "$KERNEL/arch/arm64/configs/radxa.config"
test -f "$KERNEL/arch/arm64/configs/radxa_custom.config"

# --- build --------------------------------------------------------------
rm -f /build/linux-*.deb /build/linux-*.changes /build/linux-*.buildinfo \
	./linux-*.deb ./linux-*.changes ./linux-*.buildinfo 2>/dev/null || true

make "${BUILD_CMD:-build}"

# --- artifacts ----------------------------------------------------------
find /build "$ROOT" -maxdepth 1 -type f \( \
	-name 'linux-*.deb' -o -name 'linux-*.changes' -o -name 'linux-*.buildinfo' \
\) -exec cp -a {} "$OUT"/ \;

ls -lh "$OUT"
ccache -s 2>/dev/null || true
