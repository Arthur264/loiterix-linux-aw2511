FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
	PATH="/usr/lib/ccache:${PATH}" \
	CCACHE_DIR=/build/ccache \
	CCACHE_MAXSIZE=20G \
	CCACHE_COMPILERCHECK=content

RUN dpkg --add-architecture arm64 \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		bc bison build-essential ca-certificates ccache cpio \
		crossbuild-essential-arm64 debhelper devscripts \
		device-tree-compiler dh-exec dwarves fakeroot flex git \
		kmod libelf-dev libncurses-dev libssl-dev libyaml-dev \
		lintian python3 quilt rsync xz-utils zstd \
		binfmt-support qemu-user-static \
	&& for c in gcc g++ cc c++ as; do \
		ln -sf /usr/bin/ccache "/usr/lib/ccache/aarch64-linux-gnu-$c"; \
	done \
	&& rm -rf /var/lib/apt/lists/*

COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/rsync-excludes /rsync-excludes
RUN chmod +x /entrypoint.sh

WORKDIR /build/src
ENTRYPOINT ["/entrypoint.sh"]
