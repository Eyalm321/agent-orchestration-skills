---
name: use-hyperpanes
description: Drive the hyperpanes terminal-workspace app — spawn, arrange, read, and drive tiled terminal panes, and orchestrate multi-agent pane orgs — preferring the hyperpanes MCP and falling back to the `hyperpanes` CLI for launch when the MCP isn't connected. Use when the user wants to open or launch a hyperpanes workspace, tile/spawn/label/color terminal panes, read or drive a pane, run or converse with an agent inside a pane, orchestrate a manager→worker pane tree, or mentions hyperpanes, panes, or a terminal workspace.
---

# Use Hyperpanes

[hyperpanes](https://github.com/Eyalm321/hyperpanes) is an agent-first tiling-terminal app: one window of labeled, color-framed terminal panes. Each pane can run a command/agent; an MCP lets you spawn, read, and drive panes and wire up a manager→worker agent org.

## Routing — MCP → Control API → CLI

Try the tiers in order; each is a fallback when the one above isn't available.

1. **MCP** (`mcp__hyperpanes__*` tools) — preferred. Two levels: **compose & launch** (`list_layouts`, `validate_workspace`, `build_workspace`, `launch_workspace` — no running app; `launch_workspace` needs `HYPERPANES_BIN`) and **live control** (read/drive/orchestrate — needs the **app running** with Preferences → General → **"Allow agent control"** on). **Call `control_status` first** for live work — it reports `available`, `appAllowsInput`, and the bridge `inputGate`.
2. **Control API** (direct HTTP/WS) — if the `mcp__hyperpanes__*` tools aren't connected **but the app is running with control enabled**, drive the loopback API yourself: read `control.json` for `{port, token}`, then `http://127.0.0.1:{port}` with `Authorization: Bearer {token}` (and `ws://…/events` for the stream). Recovers the full read/drive/orchestrate surface — every MCP tool maps 1:1 to an endpoint. See [API.md](API.md).
3. **CLI** (`hyperpanes …`) — last resort / no running app. ⚠️ **Launch & compose only** — it cannot read or drive live panes. See [CLI.md](CLI.md).

References: MCP tools → **[MCP.md](MCP.md)** · raw HTTP/WS → **[API.md](API.md)** · CLI grammar + `workspace.json` → **[CLI.md](CLI.md)**.

## Workflows

These use MCP tool names. On the Control-API tier each maps 1:1 to an HTTP call — see the mapping table in [API.md](API.md).

### A. Launch a workspace
- MCP: build a spec → `validate_workspace {spec}` → `launch_workspace {spec}` (default `mode:"file"` is **lossless**; `mode:"cli"` is **lossy** — check `droppedFields`). Or `build_workspace {spec, path}` to write a reusable `.json`.
- CLI: `hyperpanes <abs\path\workspace.json>` or inline `-c "cmd" --label … --layout …` (see [CLI.md](CLI.md)). Single-instance: a second invocation routes windows into the running app.

### B. Open & arrange panes (live)
- `open_pane {command?, args?, label?, cwd?, shell?, color?, meta?, env?, windowId?}` → returns `paneId`. Pass `args` (string array) for **verbatim argv** with no shell re-parse. **Put the agent's first prompt as the LAST arg** so it runs turn 1 on startup: `command:"claude", args:["--append-system-prompt-file","persona.md","--model","opus","<first prompt>"]`. **Don't** launch claude bare then type the first prompt in — that hits the cold-start Enter-swallow `prompt_pane` exists to recover from. Full claude grammar: `/use-claude`.
- **Project auto-tint — usually leave `label`/`color` unset.** When a pane's shell enters a git repo (via `cwd` at launch or a later `cd`), hyperpanes tints it from that project: a frame **color** hashed from the repo path (stable per repo, distinct across repos) and the repo/folder **name** as the title. Color always wins; the title only replaces a *default* label (`shell`/`pane N`), so **passing a `label` suppresses the project title**. Set `label`/`color` on `open_pane` only to deliberately override the tint.
- Arrange/edit: `set_layout {layout, tabId?}`, `focus_pane`, `close_pane`, `restart_pane`, `rename_pane`, `recolor_pane`, `set_meta`. Inventory: `list_panes`.

### C. Read a pane
- `read_pane {paneId, mode?, tail?, strip?, since?, waitForIdle?}`. Use `mode:"screen"` for a clean TUI transcript (no overdraw/spinner spam); `waitForIdle:true` to block until output-quiet; reuse the returned `cursor` as `since` for delta reads. Or subscribe to the resource `hyperpanes://pane/{paneId}/output`.

### D. Drive a TUI agent in a pane ⚠️
Typing into a live shell is **triple-gated** — see [MCP.md](MCP.md#send_input-safety). All of: app "Allow agent control → input" on, `HYPERPANES_ALLOW_INPUT=1` in the MCP env, and `confirm:true` per call.
- One call per turn: `prompt_pane {paneId, text, confirm:true}` → types, submits, waits for settle, returns the rendered `reply` + `awaitingInput`. This drives **turn 2+** of a conversation with an interactive `claude`/`aider`/`codex` pane — **seed turn 1 via the launch args** (Workflow B), not here.
- Lower level: `send_input {paneId, data, submit:true, confirm:true}` (pass `data` **without** a trailing newline — `submit` sends a separate Enter). `send_keys {paneId, keys:["enter"], confirm:true}` to clear a first-run trust dialog or answer menus.

### E. Orchestrate an agent org
Hierarchy is **data**: set `meta.parent` on each child (reserved meta keys: `role`/`parent`/`agentType`/`task`).

**Delegate, don't relay.** To make agents talk to each other, don't sit in the middle prompting A → B → A. Spawn the worker, hand it a scoped token + the peer's `paneId`, and let it drive the peer directly.

**Orchestrator vs child — who calls what.** You (the orchestrator) have the MCP → use `open_pane`/`prompt_pane`. A spawned child **inherits the same user-scoped hyperpanes MCP**, so tell it to drive peers via its *own* `mcp__hyperpanes__prompt_pane` — the `HYPERPANES_CONTROL_TOKEN`/`PORT` you injected via `open_pane env` **auto-scopes** its MCP to its subtree (no master token, no hand-written HTTP). Only if the child's MCP hasn't connected yet (npx cold-start) is the raw control API via that same token the instant fallback (on Windows the child issues these as **PowerShell** `Invoke-RestMethod`, not bash) — see [API.md](API.md).
- `mint_token {paneIds?|tabIds?|windowIds?, ttlMs?}` → a subtree-scoped token (no escalation). Hand it to a child via `open_pane env:{HYPERPANES_CONTROL_TOKEN, HYPERPANES_CONTROL_PORT}` (use the returned `hint`); the child reaches only its subtree and never sees the master token.
- Message bus (preferred for MCP-capable workers — structured, no screen-scraping): `send_message {to, body}`, `send_to_parent {body}`, `broadcast_subtree {body, root?}`, `read_messages {paneId, after?}`. Run workers in an inbox-poll loop so they pick messages up unprompted.
- `lock_pane {paneId, owner, ttlMs?}` / `unlock_pane` — advisory write lock; pass the same `owner` to input calls while held. `whoami {paneId?}` — a manager-in-a-pane learns its own identity (needs `HYPERPANES_PANE_ID`).

## Footguns (first-use — full lists in the reference files)
- A trailing `\n` in one write is read as a **bracketed paste**, not Enter — always `submit:true` (or use `prompt_pane`).
- `read_pane mode` is `raw|screen` (default `raw`); `tail`/`strip`/`since`/`waitForIdle` are **separate params**, not modes.
