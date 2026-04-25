#!/bin/sh
set -eu

usage() {
	cat <<'EOF'
Usage: ./download_alpine.sh [alpine|debian|ubuntu] [rootfs_dir]

Examples:
  ./download_alpine.sh alpine
  ./download_alpine.sh debian
  ./download_alpine.sh ubuntu ubuntu_rootfs

Environment overrides:
  ALPINE_VERSION (default: 3.20.0)
  DEBIAN_SUITE   (default: bookworm)
  UBUNTU_VERSION (default: 24.04, resolves latest available point release)
  UBUNTU_ARCH    (default: amd64)
EOF
}

fetch_text() {
	url="$1"

	if command -v wget >/dev/null 2>&1; then
		wget -qO- "$url"
	elif command -v curl >/dev/null 2>&1; then
		curl -fsSL "$url"
	else
		echo "Error: neither wget nor curl is available." >&2
		exit 1
	fi
}

download_file() {
	url="$1"
	output="$2"

	if command -v wget >/dev/null 2>&1; then
		wget -O "$output" "$url"
	elif command -v curl >/dev/null 2>&1; then
		curl -L "$url" -o "$output"
	else
		echo "Error: neither wget nor curl is available." >&2
		exit 1
	fi
}

resolve_ubuntu_tarball() {
	release="$1"
	arch="$2"
	release_url="https://cdimage.ubuntu.com/ubuntu-base/releases/${release}/release/"
	tar_name="$(
		fetch_text "$release_url" \
			| grep -oE "ubuntu-base-[0-9.]+-base-${arch}\\.tar\\.gz" \
			| sort -uV \
			| tail -n1 || true
	)"

	if [ -z "$tar_name" ]; then
		echo "Error: could not find an ubuntu-base tarball at ${release_url}" >&2
		exit 1
	fi

	printf '%s\n' "$tar_name"
}

DISTRO="${1:-alpine}"
CUSTOM_ROOTFS_DIR="${2:-}"

case "$DISTRO" in
	-h|--help|help)
		usage
		exit 0
		;;
	alpine)
		ALPINE_VERSION="${ALPINE_VERSION:-3.20.0}"
		ALPINE_MAJOR_MINOR="${ALPINE_VERSION%.*}"
		ROOTFS_DIR="alpine_rootfs"
		ROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_MAJOR_MINOR}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}-x86_64.tar.gz"
		TAR_FILE="alpine-minirootfs-${ALPINE_VERSION}.tar.gz"
		DISTRO_LABEL="Alpine Linux ${ALPINE_VERSION}"
		;;
	debian)
		DEBIAN_SUITE="${DEBIAN_SUITE:-bookworm}"
		ROOTFS_DIR="debian_rootfs"
		ROOTFS_URL="https://raw.githubusercontent.com/debuerreotype/docker-debian-artifacts/dist-amd64/${DEBIAN_SUITE}/rootfs.tar.xz"
		TAR_FILE="debian-${DEBIAN_SUITE}-rootfs.tar.xz"
		DISTRO_LABEL="Debian ${DEBIAN_SUITE}"
		;;
	ubuntu)
		UBUNTU_VERSION="${UBUNTU_VERSION:-24.04}"
		UBUNTU_ARCH="${UBUNTU_ARCH:-amd64}"
		ROOTFS_DIR="ubuntu_rootfs"
		UBUNTU_TAR_NAME="$(resolve_ubuntu_tarball "$UBUNTU_VERSION" "$UBUNTU_ARCH")"
		ROOTFS_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/${UBUNTU_TAR_NAME}"
		TAR_FILE="$UBUNTU_TAR_NAME"
		DISTRO_LABEL="Ubuntu Base ${UBUNTU_VERSION} (${UBUNTU_TAR_NAME})"
		;;
	*)
		echo "Error: unsupported distro '$DISTRO'." >&2
		usage >&2
		exit 1
		;;
esac

if [ -n "$CUSTOM_ROOTFS_DIR" ]; then
	ROOTFS_DIR="$CUSTOM_ROOTFS_DIR"
fi

echo "[*] Creating directory $ROOTFS_DIR..."
mkdir -p "$ROOTFS_DIR"

echo "[*] Downloading ${DISTRO_LABEL} rootfs..."
download_file "$ROOTFS_URL" "$TAR_FILE"

echo "[*] Extracting rootfs..."
tar -xf "$TAR_FILE" -C "$ROOTFS_DIR"

echo "[*] Cleaning up tarball..."
rm -f "$TAR_FILE"

echo "[+] Done! Your rootfs is ready at: ./$ROOTFS_DIR"
echo "You can now test your container using:"
echo "sudo python test_container.py ./$ROOTFS_DIR"
