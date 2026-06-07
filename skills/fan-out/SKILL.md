---
name: fan-out
description: Dispatch a set of ready issues to multiple parallel Claude Code agents — one git worktree and one hyperpanes pane per track. Reads ready-for-afk issues from the project issue tracker, builds a dependency graph (Blocked-by + file overlap), decomposes it into the maximum number of independent tracks, emits one Matt-style /handoff per track, and launches them as tiled hyperpanes panes it can then monitor and coordinate. Use when the user wants to parallelize issues or epics across agents, fan work out to multiple agents, run several agents at once, or invokes /fan-out. Dispatch-only: never creates or edits issues.
disable-model-invocation: true
argument-hint: "<epic ref | label | issue numbers> (defaults to all ready-for-afk issues)"
---

# Fan Out

Turn a set of ready issues into the **maximum number of independent parallel agents** — each in its own git worktree, each driven by a self-contained `/handoff`, each running in a tiled **hyperpanes** pane you can watch and steer. This skill **dispatches** — it never creates or edits issues. Materialise work with `/to-issues` first.

Composes `/handoff` (one per track), `/use-hyperpanes` (launch + monitor the panes), `/use-claude` (the per-track claude invocation), and reuses the issue-tracker config from `/setup-matt-pocock-skills`.

## Preconditions

- [ ] Tracker config known (run `/setup-matt-pocock-skills` if not).
- [ ] Inside a git repo with a **clean working tree** (worktrees branch from HEAD).
- [ ] hyperpanes reachable for launch — `/use-hyperpanes` routes **MCP → control-API → launch-the-app**, so this degrades gracefully on its own.

## Process

### 1. Ingest
Resolve the arg (epic ref / label / issue numbers); default to all `ready-for-afk` issues. For each, read `Blocked-by`, `Parent` (epic), and the `HITL`/`AFK` tag. **Do not modify any issue.**

### 2. Build the dependency graph — see [DECOMPOSE.md](DECOMPOSE.md)
- **Logical edges** (directed): read straight from `Blocked-by`.
- **File/resource edges** (co-location): `/to-issues` strips file paths, so scan the codebase for which files each issue will touch. Two issues touching the same file **cannot** run in parallel worktrees (merge conflict) → co-locate them in one track.
- If `Blocked-by`/`Parent`/`HITL` metadata is missing (hand-filed issues), lean harder on the file scan and flag the gaps for the checkpoint.

### 3. Decompose into tracks — see [DECOMPOSE.md](DECOMPOSE.md)
Connected components → min-chain-cover within each. **Max agents = sum of component widths.** Epic (`Parent`) is the default grouping, but the graph overrides it: split a wide epic across agents, merge tiny independent epics for balance. If width exceeds the soft cap (~6), warn and propose a grouping.

### 4. Freeze cross-edge contracts — see [CONTRACTS.md](CONTRACTS.md)
For every logical edge that crosses between tracks, freeze the shared interface as a **stub** the consumer codes against in parallel. If a boundary can't be pinned yet, mark that edge **wave/sync** instead.

### 5. Checkpoint — MANDATORY GATE
Show the user and get explicit approval **before** creating worktrees or launching anything:
- the merged graph (logical + file edges) and the proposed tracks
- each cross-edge: **contract** or **wave/sync**
- worktree path + branch per track (hyperpanes auto-titles each pane by its worktree folder and gives it a distinct frame color — see step 8)
- model + effort per track (uniform default; let them override per track)
- which issues are **HITL** — the agent will pause and ask in its pane

Do not proceed until the user confirms.

### 6. Emit handoffs — see [HANDOFF-FORMAT.md](HANDOFF-FORMAT.md)
Write one handoff per track to `.fanout/handoffs/<track>.md`, the contracts to `.fanout/contracts/<name>.md`, and the manifest to `.fanout/plan.json` (schema in DECOMPOSE.md). Recommend the user gitignore `.fanout/`.

### 7. Create worktrees
`pwsh scripts/make-worktrees.ps1 -Plan .fanout/plan.json` — one worktree + branch (`fanout/<track>`) per track; copies each handoff in as `FANOUT-HANDOFF.md`.

### 8. Launch into hyperpanes — composes `/use-hyperpanes` + `/use-claude`
Open one pane per track via the hyperpanes MCP `open_pane` (or the control-API / launch-the-app fallback `/use-hyperpanes` routes for you):

`open_pane { command:"claude", args:["--model",<m>,"--effort",<l>,"--append-system-prompt-file","FANOUT-HANDOFF.md","<kickoff>"], cwd:"<worktree>", meta:{ parent:"fanout-<run>", role:"fanout-track", task:"<track>" } }`

- **No `label`/`color`** — hyperpanes tints each pane from its worktree's git project: a frame color hashed from the worktree path (stable, distinct per track) and the worktree folder name (the track name) as the title, applied automatically once claude's shell starts in `cwd`. Passing a `label` would *suppress* the auto-title (the project name only replaces a default label).
- **Verbatim `args`** (not a shell string) avoids the quoting footgun — see `/use-claude`. `cwd` starts claude in the worktree so `--append-system-prompt-file FANOUT-HANDOFF.md` resolves (and triggers the project tint above).
- Then `set_layout {layout:"grid"}` to tile the tracks in one window. Optionally `mint_token {paneIds:[…]}` per track for recursive sub-orchestration (hand it to the pane via `open_pane env`).
- `<kickoff>` = `Read FANOUT-HANDOFF.md (also in your system prompt) and begin. Work your issues in order, commit to this branch, and pause at any [HITL] slice to ask me in your pane.`

**Then monitor — don't walk away.** `list_panes`/`activity` shows which tracks are busy/idle/exited; `read_pane` inspects any track; answer HITL grills in-pane (`prompt_pane`/`send_keys`). This live drive-and-watch is the whole reason fan-out targets hyperpanes rather than blind terminal tabs.

### 9. Fan-in (separate step) — see [CONTRACTS.md](CONTRACTS.md)
Wait for every track to go `idle`/`exited` (watch `list_panes` activity, or the `activity` event). Then merge branches in dependency order → swap each contract stub for the real implementation → run integration tests → resolve conflicts. Only then `close_pane` each track and `git worktree remove` its worktree.
