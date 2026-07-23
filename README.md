# linux-aw2511

[![Release](https://github.com/radxa-pkg/linux-aw2511/actions/workflows/release.yaml/badge.svg)](https://github.com/radxa-pkg/linux-aw2511/actions/workflows/release.yaml)

## Build

### OrbStack (macOS)

1. Install [OrbStack](https://orbstack.dev/) and start it.
2. From the repo root:

```sh
./scripts/orbstack-build.sh           # make build → ./out/
./scripts/orbstack-build.sh deb       # make deb
./scripts/orbstack-build.sh reset-cache  # wipe objects + ccache volume
```

Syncs into a case-sensitive Docker volume (APFS collapses `xt_DSCP.c` /
`xt_dscp.c`), keeps in-tree objects across runs, and uses `ccache` under
`/build/ccache` on that volume.

### Dev container

1. `git clone --recurse-submodules https://github.com/radxa-pkg/linux-aw2511.git`
2. Open in [`devcontainer`](https://code.visualstudio.com/docs/devcontainers/containers)
3. `make deb`

