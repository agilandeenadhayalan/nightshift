#!/usr/bin/env bash
# Install the pinned Node runtime under the current WSL user's local data directory.
# Does not use sudo or replace system Node. The downloaded archive is checksum verified.
set -euo pipefail
node_version=24.13.0
case "$(uname -m)" in
  x86_64) node_arch=x64 ;;
  aarch64) node_arch=arm64 ;;
  *) echo 'Unsupported architecture' >&2; exit 1 ;;
esac
install_parent="${XDG_DATA_HOME:-$HOME/.local/share}/nightshift"
install_target="$install_parent/node-v$node_version-linux-$node_arch"
if [[ ! -x "$install_target/bin/node" ]]; then
  mkdir -p "$install_parent"
  archive="node-v$node_version-linux-$node_arch.tar.xz"
  download_dir="$(mktemp -d)"
  trap 'rm -f -- "$download_dir/$archive" "$download_dir/SHASUMS256.txt"; rmdir -- "$download_dir"' EXIT
  curl --fail --silent --show-error --location "https://nodejs.org/dist/v$node_version/$archive" -o "$download_dir/$archive"
  curl --fail --silent --show-error --location "https://nodejs.org/dist/v$node_version/SHASUMS256.txt" -o "$download_dir/SHASUMS256.txt"
  (cd "$download_dir"; awk -v archive="$archive" '$2 == archive {print}' SHASUMS256.txt | sha256sum --check --status)
  tar -xJf "$download_dir/$archive" -C "$install_parent"
fi
"$install_target/bin/node" --version
printf 'Add to this shell: export PATH="%s/bin:$PATH"\n' "$install_target"
