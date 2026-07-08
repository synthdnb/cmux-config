# cmux-config

Home project for my cmux customization work.

## What's set up (lives outside this repo)

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

## Worktree layout

```
~/ws/<project>                     # main checkout
~/ws/<project>__worktrees/<branch> # cw / workmux worktrees
```
