#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AGENT_LABEL="com.cmux.autogroup"
PLIST_DEST="$HOME/Library/LaunchAgents/${AGENT_LABEL}.plist"
PLIST_SRC="$REPO_DIR/launchd/${AGENT_LABEL}.plist"

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
link_file bin/cmux-autogroup "$HOME/.local/bin/cmux-autogroup"
link_file skills/cmux-issue "$HOME/.claude/skills/cmux-issue"

# Plist is rendered from a template (with the local $HOME substituted in) and
# copied, not symlinked -- launchd mistrusts symlinked agent plists.
agent_loaded() {
  launchctl print "gui/$UID/${AGENT_LABEL}" >/dev/null 2>&1
}

render_plist() {
  sed "s|__HOME__|$HOME|g" "$PLIST_SRC"
}

plist_state="ok (current)"
if [ -e "$PLIST_DEST" ]; then
  if diff -q <(render_plist) "$PLIST_DEST" >/dev/null 2>&1; then
    echo "ok (current): $PLIST_DEST"
  else
    bak="${PLIST_DEST}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$PLIST_DEST" "$bak"
    echo "backed up $PLIST_DEST -> $bak"
    render_plist > "$PLIST_DEST"
    echo "copied: $PLIST_DEST"
    plist_state="copied (updated): $PLIST_DEST"
    if agent_loaded; then
      launchctl bootout "gui/$UID/${AGENT_LABEL}" >/dev/null 2>&1 || true
      launchctl bootstrap "gui/$UID" "$PLIST_DEST"
      echo "reloaded: ${AGENT_LABEL}"
    fi
  fi
else
  mkdir -p "$(dirname "$PLIST_DEST")"
  render_plist > "$PLIST_DEST"
  echo "copied: $PLIST_DEST"
  plist_state="copied: $PLIST_DEST"
fi
[ "$plist_state" = "ok (current)" ] && plist_state="ok (current): $PLIST_DEST"
SUMMARY+=("$plist_state")

mkdir -p "$HOME/.local/state/cmux-autogroup"

if ! agent_loaded; then
  if launchctl bootstrap "gui/$UID" "$PLIST_DEST" 2>/dev/null; then
    echo "bootstrapped: ${AGENT_LABEL}"
    SUMMARY+=("bootstrapped: ${AGENT_LABEL}")
  else
    echo "warning: could not bootstrap ${AGENT_LABEL} (no GUI session? SSH?)"
    SUMMARY+=("warning: ${AGENT_LABEL} not loaded")
  fi
else
  SUMMARY+=("ok (loaded): ${AGENT_LABEL}")
fi

# Best-effort cmux socket check.
CMUX_BIN=""
if command -v cmux >/dev/null 2>&1; then
  CMUX_BIN="cmux"
elif [ -x /Applications/cmux.app/Contents/Resources/bin/cmux ]; then
  CMUX_BIN=/Applications/cmux.app/Contents/Resources/bin/cmux
fi

if [ -n "$CMUX_BIN" ]; then
  # The autogroup daemon talks to the cmux socket from launchd (outside cmux),
  # which requires automation.socketControlMode "automation" in cmux.json.
  # The socket server reads the mode only at app startup.
  mode="$("$CMUX_BIN" capabilities 2>/dev/null | sed -n 's/.*"access_mode" *: *"\([^"]*\)".*/\1/p')"
  if [ -n "$mode" ] && [ "$mode" != "automation" ] && [ "$mode" != "allowAll" ] && [ "$mode" != "password" ]; then
    echo "warning: cmux socket access_mode is '$mode' — the autogroup daemon will be rejected."
    echo "         Set automation.socketControlMode to \"automation\" in ~/.config/cmux/cmux.json"
    echo "         and restart cmux (the mode is read only at app startup)."
    SUMMARY+=("warning: socket access_mode '$mode' blocks the daemon")
  fi
else
  echo "note: cmux not on PATH, skipping socket access_mode check"
  SUMMARY+=("skipped: socket access_mode check (cmux not found)")
fi

echo
echo "Summary:"
for line in "${SUMMARY[@]}"; do
  echo "  $line"
done
