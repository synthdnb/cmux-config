#!/bin/bash
set -euo pipefail

# Installs cw into ~/.local/bin.
#
# cmux-autogroup (and its com.cmux.autogroup launchd agent) and
# cmux-session-cleanup were retired: dispatch moved to Rex via the
# rex-dispatch / rex-cleanup skills in personal-agent-config. Re-running this
# script does not remove previously installed copies; see "Retired" in
# README.md for the one-time manual cleanup.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -a SUMMARY=()

# link_file <repo-relative-src> <abs-dest>
link_file() {
  local rel_src="$1"
  local dest="$2"
  local src="$REPO_DIR/$rel_src"

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "ok (linked): $dest"
    SUMMARY+=("ok (linked): $dest")
    return
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local bak="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$bak"
    echo "backed up $dest -> $bak"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "linked: $dest -> $src"
  SUMMARY+=("linked: $dest")
}

link_file bin/cw "$HOME/.local/bin/cw"

echo
echo "Summary:"
for line in "${SUMMARY[@]}"; do
  echo "  $line"
done
