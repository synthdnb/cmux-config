---
name: cmux-dispatch
description: "Launch a Linear issue as an autonomous cmux session: create a git worktree via `cw`, start Claude with bypassPermissions, and drive it until a draft PR is open. Use when the user says to launch/open/spin up a cmux session for a Linear issue (e.g. ABC-123), 'implement this issue in cmux', or dispatch one or more issues to worktrees."
allowed-tools: Bash, Write
---

# cmux-dispatch

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

Use the `linear` CLI (never Linear MCP tools):

```bash
linear issue view ABC-123 --json --no-comments --no-pager
linear api 'query { issue(id: "ABC-123") { branchName title url description parent { identifier url } children { nodes { identifier title state { type } } } } }'
```

Capture from the result:
- `branchName` — this is the worktree branch (e.g. `abc-123`). Use it
  verbatim; `cw` maps `/` → `-` for the directory name.
- `title`, `url`, `description`.
- `parent` and `children` — these route umbrella vs sub-issue (step 1a).

If an argument is not a Linear identifier (no ticket), fall back to treating it
as a plain task: pick a short kebab-case branch name and use the task text as
the spec. Ask the user only if you cannot form a prompt at all.

### 1a. Umbrella issues: dispatch the children instead

Issues follow the `file-issue` skill's conventions: an **umbrella**
issue is a Korean, human-facing summary; its **sub-issues** are
self-contained English specs written to be fed to agents.

- If the issue has `children`, it is an umbrella — never launch a session
  for the umbrella itself (its body is a Korean summary, not a spec).
  Dispatch its children instead: run steps 2–4 once per child whose state
  type is `backlog` or `unstarted` (i.e. Todo), and report started or
  completed children as skipped. If that would launch more than 4
  sessions, list the children and confirm with the user first.
- If the issue has a `parent`, it is a sub-issue — proceed normally, and
  pass the parent's identifier/URL into the prompt as context-only (see
  step 2).

### 2. Write the prompt file

Write a self-contained prompt to the **scratchpad** (absolute path, since the
new workspace shell will `cat` it), e.g.
`<scratchpad>/cmux-dispatch-<branch>.txt`. Use RELATIVE paths inside the prompt —
each worktree has its own root. The prompt MUST contain:

- The issue identifier, title, and URL, and an instruction to run
  `linear issue view <ID>` for the authoritative spec (the `linear` CLI —
  never Linear MCP tools, which are deny-listed).
- The **full issue description** inlined (paste the `description` verbatim) so
  the agent works even without Linear access. Preserve the file paths / line
  refs / decisions from the ticket.
- If the description starts with a `## 요약` section (Korean TL;DR for
  coworkers, per the `file-issue` conventions), paste it verbatim
  anyway, but add this line to the prompt: "The `## 요약` section is a
  Korean summary for coworkers; the English sections below it are the
  authoritative spec. Work and write in English."
- If the issue has a parent umbrella, one context line: `Parent
  (umbrella): <ID> <URL> — Korean human-facing summary; context only,
  this sub-issue's spec is authoritative.`
- These standing instructions, adapted to the issue:

  ```
  You are working autonomously in a git worktree on branch <branchName>,
  implementing <ID>. Permissions are bypassed — do NOT stop to ask; proceed
  end to end.

  1. Implement the change following the repo's conventions and CLAUDE.md.
     Never edit generated files.
  2. Build and run the relevant tests until green (state the exact commands
     for this repo/area). If the spec has an "Acceptance criteria"
     section, verify every item before opening the PR.
  3. Commit on branch <branchName> with a clear message. (Claude Code
     appends its own accurate attribution trailer — do not add one.)
  4. Push the branch: git push -u origin HEAD
  5. Run the code-review skill on your changes: /code-review high --fix
     Commit and push any fixes it applies. (/code-review is an
     Anthropic-managed skill and its syntax may change — if that exact
     invocation errors, check the skill's current usage and run the
     closest equivalent at high effort with fixes applied; don't skip
     the review.)
  6. Open a DRAFT PR: gh pr create --draft --base main
     - Title: concise, <=72 chars, English.
     - Body: start with a `## 요약` section — a 1–2 sentence Korean TL;DR
       of the change for coworkers scanning the PR (same convention as
       `file-issue` sub-issues). Compose the summary in English first,
       then rewrite it as natural Korean (자연스러운 한국어로 재작성) —
       never literal sentence-by-sentence translation.
     - After 요약, the rest of the body in English: summary + key changes
       + testing, and a link to <issue URL>. (Branch name matches the
       Linear branchName, so Linear auto-links the PR — do not add a
       closing keyword.) End the body with:
       🤖 Generated with [Claude Code](https://claude.com/claude-code)
  7. Report the PR URL and a one-line status as your final message.

  If tests cannot pass or you hit a genuine blocker, still open the draft PR
  with a "⚠️ blocked" note in the body explaining what's incomplete, then
  report the blocker.

  Write everything you produce (code, commits, PR title/body) in English —
  the one exception is the PR body's `## 요약` section, which is Korean.
  If you comment on the Linear issue, match the language already used in
  that thread.
  ```

### 3. Launch the cmux session

Run `cw` from inside the target repo (it infers the project from the cwd).
Always pass `--no-focus` — never steal focus, even for the last/only session.
The user stays where they are and opens a session themselves when ready.

```bash
SP=<scratchpad>
cw add <branchName> --no-focus \
  --cmd "claude --permission-mode=bypassPermissions \"\$(cat $SP/cmux-dispatch-<branch>.txt)\""
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
- When an umbrella's children were dispatched, name the umbrella, list any
  children skipped (already started/completed), and note the umbrella
  closes only when all sub-issues close.

## Related skills

- `file-issue` — composes the umbrella/sub-issue structure these
  sessions consume (Korean umbrella for humans, English sub-issues for
  agents).
- `cmux-cli` — full cmux command reference and socket/focus safety rules.
- `worktree` / `workmux` — the tmux-based dispatcher equivalent; `cw` is the
  cmux-native (no-tmux) counterpart used here.
