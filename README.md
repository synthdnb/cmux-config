# cmux-config

Personal cmux customizations: `cw`, a worktree/session helper, installed with
one script.

## What's set up

This file is versioned in this repo and symlinked into place by
`./install.sh`:

- **`cw`** — `~/.local/bin/cw`. workmux-style helper managing git worktrees +
  cmux sessions: `cw add|open|rm|merge|ls|path <branch>`, project inferred
  from cwd or `<project>/<branch>`. `CW_DEFAULT_CMD` / `--cmd` starts an agent
  in new sessions.

The dispatch pipeline now lives in the `personal-agent-config` repo as the
Rex-based `rex-dispatch` / `dispatch-coordinate` / `rex-cleanup` skills.

## Configuration

`CMUX_WS_ROOT` overrides the default `~/ws` workspace root for `cw`, which
reads it live from your shell environment.

## Layout

```
cmux-config/
  install.sh                                 # idempotent installer
  bin/cw                                     # -> ~/.local/bin/cw
```

## Install

```
./install.sh
```

Idempotent — safe to re-run; backs up anything it replaces with timestamped
`.bak.<YYYYmmddHHMMSS>` files.

## Worktree layout

```
~/ws/<project>                     # main checkout
~/ws/<project>__worktrees/<branch> # cw / workmux worktrees
```

## Retired

`cmux-autogroup` (the sidebar auto-grouping daemon and its
`com.cmux.autogroup` launchd agent) and `cmux-session-cleanup` (the tab-bar
session teardown) were removed; dispatch moved to Rex. `./install.sh` no
longer installs them and does not remove copies a previous version installed.
One-time manual cleanup on an existing machine:

```
launchctl bootout gui/$UID/com.cmux.autogroup
rm ~/Library/LaunchAgents/com.cmux.autogroup.plist
rm ~/.local/bin/cmux-autogroup ~/.local/bin/cmux-session-cleanup
rm -r ~/.local/state/cmux-autogroup
```

Then remove the `session-cleanup` action and its tab-bar button from
`~/.config/cmux/cmux.json`.
