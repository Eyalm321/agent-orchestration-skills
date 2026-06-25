# hyperpanes CLI fallback

Use the CLI when the `mcp__hyperpanes__*` tools are not connected. **The CLI only launches/composes workspaces — it cannot read or drive live panes** (that is control-API/MCP only). For orchestration you need the MCP.

hyperpanes runs **single-instance**: a second `hyperpanes …` while it's open routes its windows into the running app rather than starting a rival (an argless second launch just focuses the existing window).

## Headless worker (`hyperpanes worker`) — the live-op exception

`hyperpanes worker` is the one subcommand that is **not** launch/compose: it's a **control-API client** that drains a durable work queue, so it needs the **app already running with Allow agent control on** (it discovers `control.json` itself, or `HYPERPANES_CONTROL_FILE`). App ≥0.0.15.

```
hyperpanes worker --queue <name> [--worker <id>] [--count N] [--worktree] \
  [--retry-window <secs>] [--nack-delay <ms>] -- <cmd> [args...]
```

Loops: **claim** one task → run `<cmd>` with the task injected as env (`HP_TASK_ID`, `HP_TASK_PAYLOAD`, `HP_TASK_TITLE`, `HP_FENCING_TOKEN`, `HP_QUEUE`) → **ack** on exit 0 / **nack** on non-zero → repeat until the queue drains, then exit 0 (a pane running it auto-closes). The child runs **directly** (no shell); for `$HP_TASK_PAYLOAD` expansion wrap it: `-- sh -c 'claude -p "$HP_TASK_PAYLOAD"'`.

| Flag | Effect |
|---|---|
| `--count N` | N competing workers in one process (exits when all drain). |
| `--worktree` | run each task in a throwaway git worktree off HEAD — auto-removed on finish (commit stays on its branch); `.serena/` excluded so `git add -A` can't sweep it in. Needs cwd in a git repo. |
| `--retry-window <secs>` | keep polling after the queue empties so backoff retries get reclaimed in one run (default 0 = exit on drain). |
| `--nack-delay <ms>` | override the retry backoff on failure. |
| `--worker <id>` | worker id (shown as `claimedBy`; default `worker-<pid>`, suffixed `-1..-N` under `--count`). |

Enqueue tasks via the MCP `enqueue_task` or the control API. The MCP **`spawn_workers`** tool wraps this in one call (opens the pane for you) — see [MCP.md](MCP.md#work-queue--worker-pool).

## Locating the executable

The installer adds its folder to the **user PATH** (verified: `C:\Program Files\Hyperpanes` is on PATH here), so in a **fresh** terminal just run `hyperpanes …` — the exe is `Hyperpanes.exe` and resolves case-insensitively.

> Caveat: a shell started **before** install carries a stale PATH snapshot and won't resolve it (installer PATH edits don't reach an already-running process) — reopen the terminal, or use the full path.

You need the **explicit path** for the MCP `launch_workspace` tool — it has **no PATH fallback** and requires `HYPERPANES_BIN`. Resolve it in this order:
1. `$env:HYPERPANES_BIN` if set.
2. The installed exe (capital `H`): `C:\Program Files\Hyperpanes\Hyperpanes.exe` (verified here); per-user installs land at `%LOCALAPPDATA%\Programs\Hyperpanes\Hyperpanes.exe`.
3. If it's running, derive from the process: `(Get-Process Hyperpanes | Select-Object -First 1).Path`.
4. **Dev tree** at `C:\hyperpanes`: `npm run dev -- <args>` (forward args after `--`).

Always pass an **absolute** path to a `.json` workspace.

## Two ways to launch

**1. A workspace file:**
```
hyperpanes C:\abs\path\workspace.json
```
The path must already exist on disk and end in `.json` (case-insensitive) or it's silently ignored.

**2. Inline pane description** — each `-c` opens a pane; attribute flags bind to the most recent `-c`; `--tab`/`--window` start new scopes:
```
hyperpanes --window --name app --layout main-stack `
  -c "npm run dev" --label server --color "#e5484d" --cwd C:\app\ --shell pwsh `
  -c "tail -f logs/app.log" --label logs --font 12 `
  --tab --name tests --layout columns `
  -c "vitest" --label unit
```

## Flag grammar

| Flag | Value | Scope / binding |
|---|---|---|
| `--window` | — | New window; resets tab+pane scope. |
| `--tab` | — | New tab in current window (auto-creates a window). |
| `-c`, `--command <cmd>` | yes | New pane in current tab (auto-creates window+tab). Becomes "current pane"; clears header scope. |
| `-l`, `--label <name>` | yes | Most recent `-c` pane (else ignored). Default label = first word of the command. |
| `--color <hex>` | yes | Most recent `-c` pane. |
| `--font <px>` | int | Most recent `-c` pane (ignored if non-numeric). |
| `--cwd <dir>` | yes | After a `-c` → that pane; **before any `-c` → launch-wide default**. |
| `--shell <shell>` | yes | Same per-pane / launch-wide-default rule as `--cwd`. |
| `--layout <id>` | yes | Current tab's layout; **before a tab exists it's pending → applies to the next tab**. |
| `--name <name>` | yes | Titles the current scope: window (right after `--window`), tab (right after `--tab`), else (before any structural flag) the **workspace name**. A `-c` clears header scope. |

Layout ids: `auto · single · columns · rows · grid · main-stack` (default `auto` → 1 pane=single, 2–3=columns, 4+=grid; `rows`/`main-stack` are manual-only). The parser does **not** validate `--layout`; an unknown id is normalized to `auto` by the app.

**Precedence:** if any `-c` yields a pane, an inline launch is built and a **positional `.json` is ignored** — don't mix them. No `--help`/`--version`; unknown flags are silently ignored; a missing value at end-of-args reads `undefined` (no error). Empty windows/tabs (a `--window`/`--tab` with no `-c`) are pruned.

## workspace.json schema (as the app parses it)

```
WorkspaceFile { name?, layout?, panes?, groups?, active?, windows? }
WindowSpec    { title?, active?, bounds?, groups[] }          // bounds: x,y,width,height,maximized,fullscreen
GroupSpec     { title?, layout?, panes[], sizes?, mainFraction?, focused?, zoomed? }   // a tab
PaneSpec      { label?, subtitle?, color?, command?, args?, cwd?, shell?, fontSize?, meta? }
Layout        = auto | single | columns | rows | grid | main-stack
```

Nesting precedence: `windows[]` (windows with empty `groups` dropped) → else `groups[]` (one window of tabs, honoring `active`) → else `panes[]` (one window/tab using top-level `layout`/`name`). The loader needs ≥1 of `panes`/`groups`/`windows`, else returns null. Bad values fall back defensively (validation is in the renderer, not the parser):

- `layout` not in the 6 ids → `auto`.
- `sizes` applied only if it's an array, `length === panes.length`, all finite `>0`, **and** `layout !== 'auto'` — else equal split. Normalized to sum 1.
- `mainFraction` (main-stack only) clamped to `[0.05, 0.95]`, default `0.6`.
- `focused`/`zoomed` used only if an integer in `[0, n)`.
- `fontSize` clamped to `[6, 40]`, default `13`.
- `args` must be a string array (non-strings filtered; empty → omitted) for direct no-shell spawn.
- Window `bounds.maximized` is **ignored at launch** (opens normal-sized); `fullscreen:true` **is** honored.

**Relative `cwd` base differs by source:** a `.json` file resolves relative `cwd` against **the file's own directory**; inline `-c` flags resolve against the **launch cwd**. Prefer absolute `cwd` to avoid surprises.

## Dev-vs-packaged offset (testing footgun)

The parser does `argv.slice(1)` (drops one leading element) — correct for the packaged `hyperpanes.exe`. In dev (`npm run dev -- …`) Electron's argv has an extra leading `.`, which is harmless (skipped) but means dev arg positions are offset by one. Flags still parse; just be aware when testing CLI behavior in the dev tree.
