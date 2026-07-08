---
name: cmux-issue
description: "Launch a Linear issue as an autonomous cmux session: create a git worktree via `cw`, start Claude with bypassPermissions, and drive it until a draft PR is open. Use when the user says to launch/open/spin up a cmux session for a Linear issue (e.g. ABC-123), 'implement this issue in cmux', or dispatch one or more issues to worktrees."
allowed-tools: Bash, Write, mcp__claude_ai_Linear__get_issue
---

# cmux-issue

Turn one or more Linear issues into autonomous cmux sessions. For each issue you
create a git worktree (via `cw`, the cmux-native worktree manager), open a cmux
workspace named after the issue's branch, and launch Claude Code inside it with
a self-contained prompt that implements the issue and **proceeds all the way to
a draft PR** without stopping.

Issues: $ARGUMENTS

## You are a dispatcher, not an implementer

**HARD RULE:** Do NOT explore, grep, glob, or read the target codebase. Do NOT
design the implementation. Your only jobs are: (1) read the Linear ticket, (2)
write a prompt file, (3) run `cw add`. The worktree agent does all exploration
and implementation.

The one exception is reading the **Linear ticket** — you must fetch it to get
the branch name and the spec to embed. That is reading the ticket, not the code.

## Steps (per issue)

### 1. Fetch the ticket

Run `mcp__claude_ai_Linear__get_issue` for the identifier (e.g. `ABC-123`).
Capture from the result:
- `gitBranchName` — this is the worktree branch (e.g. `abc-123`). Use it
  verbatim; `cw` maps `/` → `-` for the directory name.
- `title`, `url`, `description`, and any `parentId` / related-issue links.

If an argument is not a Linear identifier (no ticket), fall back to treating it
as a plain task: pick a short kebab-case branch name and use the task text as
the spec. Ask the user only if you cannot form a prompt at all.

### 2. Write the prompt file

Write a self-contained prompt to the **scratchpad** (absolute path, since the
new workspace shell will `cat` it), e.g.
`<scratchpad>/cmux-issue-<branch>.txt`. Use RELATIVE paths inside the prompt —
each worktree has its own root. The prompt MUST contain:

- The issue identifier, title, and URL, and an instruction to run Linear
  `get_issue <ID>` for the authoritative spec (the agent has the Linear MCP).
- The **full issue description** inlined (paste the `description` verbatim) so
  the agent works even without Linear access. Preserve the file paths / line
  refs / decisions from the ticket.
- These standing instructions, adapted to the issue:

  ```
  You are working autonomously in a git worktree on branch <gitBranchName>,
  implementing <ID>. Permissions are bypassed — do NOT stop to ask; proceed
  end to end.

  1. Implement the change following the repo's conventions and CLAUDE.md.
     Never edit generated files.
  2. Build and run the relevant tests until green (state the exact commands
     for this repo/area).
  3. Commit on branch <gitBranchName> with a clear message. End the commit
     message with:
     Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  4. Push the branch: git push -u origin HEAD
  5. Open a DRAFT PR: gh pr create --draft --base main
     - Title: concise, <=72 chars.
     - Body: summary + key changes + testing, and a link to <issue URL>.
       (Branch name matches the Linear gitBranchName, so Linear auto-links
       the PR — do not add a closing keyword.) End the body with:
       🤖 Generated with [Claude Code](https://claude.com/claude-code)
  6. Report the PR URL and a one-line status as your final message.

  If tests cannot pass or you hit a genuine blocker, still open the draft PR
  with a "⚠️ blocked" note in the body explaining what's incomplete, then
  report the blocker.
  ```

### 3. Launch the cmux session

Run `cw` from inside the target repo (it infers the project from the cwd).
Always pass `--no-focus` — never steal focus, even for the last/only session.
The user stays where they are and opens a session themselves when ready.

```bash
SP=<scratchpad>
cw add <gitBranchName> --no-focus \
  --cmd "claude --permission-mode=bypassPermissions \"\$(cat $SP/cmux-issue-<branch>.txt)\""
```

Notes:
- `cw add <branch>` creates the worktree at `~/ws/<project>__worktrees/<branch>`
  (branching off current HEAD if the branch doesn't exist) and a cmux workspace
  named `<branch>`. It prints `worktree:` and `workspace:<ref>`.
- The `\"\$(cat ...)\"` is evaluated by the new workspace's shell, so the prompt
  file must exist before this runs (write it in step 2).
- `--permission-mode=bypassPermissions` is required — the session runs
  unattended, so it must not block on permission prompts.
- If not inside the repo, pass `<project>/<branch>` or `--project <name>` to
  `cw add`.

### 4. Verify

Confirm each session actually launched Claude with its prompt:

```bash
cmux read-screen --workspace <workspace-ref> --lines 25
```

## Report

Print a table: issue ID → branch/worktree path → cmux workspace ref → status
(launched/working). Then note:
- The sessions run autonomously to a **draft PR**; the user can watch a session
  with `cmux workspace select <ref>`.
- If several issues touch shared code (same epic/parent), warn that their
  branches may conflict on merge.

## Related skills

- `cmux-cli` — full cmux command reference and socket/focus safety rules.
- `worktree` / `workmux` — the tmux-based dispatcher equivalent; `cw` is the
  cmux-native (no-tmux) counterpart used here.
