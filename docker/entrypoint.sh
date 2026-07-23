#!/bin/sh
set -eu

# Sync host tree into a case-sensitive volume (APFS collapses xt_DSCP.c / xt_dscp.c),
# keep prior build objects + ccache, then build.

SRC=/build/src
KERNEL=$SRC/src

sync_tree() {
	mkdir -p "$SRC" /build/ccache /out
	# Packaging trees hold excluded *.o; drop them so rsync --delete isn't blocked.
	rm -rf "$KERNEL/debian" "$KERNEL/usr"
	rsync -a --delete \
		--exclude-from=/rsync-excludes \
		/host/ "$SRC/"
	# Submodule git dirs: sync without --delete so local module state can linger.
	mkdir -p "$SRC/.git/modules"
	rsync -a /host/.git/modules/ "$SRC/.git/modules/"
}

# After rsync from APFS, only one spelling of each collision remains — restore both from git.
restore_case_collisions() {
	git -C "$1" ls-files | awk '{
		k = tolower($0)
		if (k in s) { print s[k]; print $0 } else s[k] = $0
	}' | while IFS= read -r p; do
		[ -n "$p" ] || continue
		rm -f "$1/$p"
		git -C "$1" checkout-index -f -- "$p"
	done
}

prepare_patches() {
	# Host .pc may claim patches applied while APFS dropped colliding files.
	cd "$SRC"
	rm -rf .pc
	dpkg-source --before-build .
	test -f "$KERNEL/arch/arm64/configs/radxa.config"
	test -f "$KERNEL/arch/arm64/configs/radxa_custom.config"
}

collect_artifacts() {
	find /build "$SRC" -maxdepth 1 -type f \( \
		-name 'linux-*.deb' -o -name 'linux-*.changes' -o -name 'linux-*.buildinfo' \
	\) -exec cp -a {} /out/ \;
	ls -lh /out
	ccache -s 2>/dev/null || true
}

sync_tree
restore_case_collisions "$KERNEL"
prepare_patches

cd "$SRC"
rm -f /build/linux-*.deb /build/linux-*.changes /build/linux-*.buildinfo \
	./linux-*.deb ./linux-*.changes ./linux-*.buildinfo 2>/dev/null || true

make "${BUILD_CMD:-build}"
collect_artifacts
