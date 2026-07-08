# cmux-config

Home project for my cmux customization work.

## What's set up

These files are versioned in this repo and symlinked/copied into place by
`./install.sh`:

- **Sidebar auto-grouping** — `~/.local/bin/cmux-autogroup`, run by the launchd
  agent `com.cmux.autogroup` (`~/Library/LaunchAgents/`). Groups cmux
  workspaces into native sidebar groups by root project under `~/ws`;
  worktree sessions (`~/ws/<project>__worktrees/<branch>`) roll up under their
  parent project. State/log: `~/.local/state/cmux-autogroup/`.
- **`cw`** — `~/.local/bin/cw`. workmux-style helper managing git worktrees +
  cmux sessions: `cw add|open|rm|merge|ls|path <branch>`, project inferred
  from cwd or `<project>/<branch>`. `CW_DEFAULT_CMD` / `--cmd` starts an agent
  in new sessions.
- **`projects` custom sidebar** — `~/.config/cmux/sidebars/projects.swift`.
  Alternative left-sidebar view grouping sessions by project (not selected;
  native groups + autogroup daemon is the active setup).

## Layout

```
cmux-config/
  install.sh                                 # idempotent installer
  bin/cw                                     # -> ~/.local/bin/cw
  bin/cmux-autogroup                         # -> ~/.local/bin/cmux-autogroup
  launchd/com.cmux.autogroup.plist  # -> ~/Library/LaunchAgents/
  sidebars/projects.swift                    # -> ~/.config/cmux/sidebars/projects.swift
```

## Install

```
./install.sh
```

Idempotent — safe to re-run; backs up anything it replaces with timestamped
`.bak.<YYYYmmddHHMMSS>` files. The launchd plist is copied (not symlinked),
since launchd mistrusts symlinked agent plists; everything else is symlinked.

**Requirement:** the autogroup daemon runs outside cmux, so cmux's control
socket must allow it: set `automation.socketControlMode` to `"automation"` in
`~/.config/cmux/cmux.json` and restart cmux — the socket server reads the mode
only at app startup (the default `cmuxOnly` rejects any process not spawned
inside cmux with `Broken pipe`). `cmux capabilities | grep access_mode` shows
the live mode; the installer warns when it's wrong.

## Worktree layout

```
~/ws/<project>                     # main checkout
~/ws/<project>__worktrees/<branch> # cw / workmux worktrees
```
