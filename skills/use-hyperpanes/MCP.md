# hyperpanes MCP — tool reference

Server `hyperpanes-mcp` over stdio. Tool results are JSON; failures set `isError:true` and usually embed `{ok:false,error}`. Optional params are marked `?`; **no tool applies zod defaults** — "default" below means applied in code or server-side.

## Availability

- **Compose/launch** tools work with no running app. `launch_workspace` needs a launcher (`launcher` arg or `HYPERPANES_BIN`) — **no PATH fallback**.
- **Live-control** tools need the app running with **Allow agent control** on; they locate it via `control.json`. Always `control_status` first.

## Compose & launch

| Tool | Params | Returns / notes |
|---|---|---|
| `list_layouts` | — | `{layouts:[{id,label,description}]}`. ids: `auto, single, columns, rows, grid, main-stack`. |
| `validate_workspace` | `spec` (req) | `{valid:true,summary:{windows,tabs,panes}}` or `{valid:false,errors[]}` (failure is **not** an MCP error). Schema is `.strict()` — unknown keys rejected; ≥1 pane required. |
| `build_workspace` | `spec` (req), `path?` | `{ok,workspace,summary,writtenTo,cli}`. `cli` = `{command,lossless:true}` or `{lossless:false,jsonOnlyFields[]}`. Writes the `.json` if `path` given. |
| `launch_workspace` | `spec?`, `path?`, `launcher?`, `mode?`(`file`\|`cli`, default `file`) | Spawns the app **detached**. `mode:"file"` (default) writes a temp json → **lossless**. `mode:"cli"` compiles flags → **lossy**, dropped fields in `droppedFields`. Needs `path` or `spec`, and a launcher. |

**Lossy CLI fields** (dropped by `mode:"cli"`): window bounds, window active-tab index, tab split sizes, main-stack fraction, focused pane index, maximized pane index, pane subtitle, pane metadata, pane `args` (verbatim argv), command-less panes. Prefer the default `file` mode unless you specifically want a CLI command.

## Inspect (running app)

| Tool | Params | Returns |
|---|---|---|
| `control_status` | — | `{available, port, pid, version, appAllowsInput, windows, panes, inputGate:{optIn,allowlist}}` or `{available:false, reason, controlFile, inputGate}`. **Call first.** |
| `list_panes` | — | `{panes:[{paneId,label,subtitle?,status,activity,exitCode,command,args?,cwd,shell,color,meta?,windowId,tabId,tabTitle,layout,activeTab,outputResource}]}`. `status`=`running|exited`; `activity`=`busy|idle|exited`. |
| `read_pane` | `paneId`(req), `mode?`(`raw`\|`screen`, default `raw`), `tail?`(int>0), `strip?`(bool), `since?`(byte cursor), `waitForIdle?`(bool), `settleMs?`(default 600), `timeoutMs?`(default 30000) | `{ok, paneId, status, output, stripped?, cursor, waited?, settled?, timedOut?, mode?, awaitingInput?}`. `screen`=rendered cell grid (clean); reuse `cursor` as `since` for deltas; `truncated:true` = cursor fell off the buffer. Read-only (not input-gated). |
| `read_messages` | `paneId`(req), `after?`(seq cursor) | `{ok,paneId,messages,dropped,latestSeq}`. `dropped` = evicted by the per-pane cap. |
| `whoami` | `paneId?` (default `$HYPERPANES_PANE_ID`) | `{ok,paneId,role?,parent?,agentType?,task?,meta,windowId,tabId,tabTitle}`. Errors if no pane id resolvable. |

## Drive (running app; structural, not input-gated)

| Tool | Params | Notes |
|---|---|---|
| `open_pane` | `command?`, `args?`(string[]), `label?`, `cwd?`, `shell?`, `color?`, `meta?`(record<string,string>), `env?`(record<string,string>), `windowId?`(default first window) | `{ok,windowId,paneId,ready}`. `command` alone → shell-parsed; `command`+`args` → **direct no-shell spawn, verbatim argv** (each array element is one arg, do not pre-quote). `env` hands a scoped token to a child. Reserved `meta` keys: `role/parent/agentType/task`. |
| `set_layout` | `layout`(req, the 6 ids), `tabId?`(default first window's active tab) | `{ok,tabId,layout}`. |
| `focus_pane` / `close_pane` / `restart_pane` | `paneId`(req) | `{ok,paneId,action}`. close terminates the shell; restart kills + respawns. |
| `rename_pane` | `paneId`(req), `label`(req), `subtitle?` (`""` clears) | live rename. |
| `recolor_pane` | `paneId`(req), `color`(req, any CSS color) | live recolor. |
| `set_meta` | `paneId`(req), `meta`(req, record<string, string\|null>) | merge: string sets, `null` deletes, untouched keys kept. Returns the app-echoed merged meta. |

## Send input (TRIPLE-GATED — see safety below) {#send_input-safety}

All three **type into a live shell**. Each needs `confirm:true` and the gates below.

| Tool | Params | Notes |
|---|---|---|
| `send_input` | `paneId`(req), `data`(req), `submit?`(bool), `submitDelayMs?`(default ~40), `confirm?`, `owner?` | `submit:true` writes `data` (no trailing `\n`!) then a **separate** Enter after the delay. A trailing `\n` alone is read as bracketed paste, not Enter. |
| `send_keys` | `paneId`(req), `keys`(req, string[]), `confirm?`, `owner?` | Named keys: `enter, escape, tab, shift+tab, up/down/left/right, home/end, pageup/pagedown, backspace, delete, space, ctrl+<letter>`. For menus, y/n & trust prompts, cancelling. |
| `prompt_pane` | `paneId`(req), `text`(req), `confirm?`, `owner?`, `settleMs?`(600), `timeoutMs?`(30000), `tail?` | **One full TUI turn**: type → submit → wait for settle → return `{ok,settled,timedOut,awaitingInput,cursor,recovered?,reply}` (`reply` = rendered screen). Has a one-shot cold-start self-heal (`recovered:true`) for a swallowed first Enter. |

**The gates** (checked in order; first failure short-circuits, returns `{ok:false,refused:true,reason}` as a *normal* result):
1. **Bridge opt-in** — `HYPERPANES_ALLOW_INPUT` must be `1`/`true`/`yes` in the MCP server env.
2. **Per-call** — `confirm:true`.
3. **Allowlist** (only if `HYPERPANES_INPUT_ALLOWLIST` set) — pane id or label must be listed.
4. **App-side (cannot be bypassed)** — even past 1–3, the app returns **403** unless its "Allow agent control → input" toggle is on. (Also: 423 = locked by another owner, 404 = no pane, 400 = bad key.)

`control_status` surfaces gates 1 & 4 (`inputGate.optIn`, `appAllowsInput`) so a refusal is always explainable.

## Orchestrate an agent org

Hierarchy is data (`meta.parent`); the bus is hierarchy-agnostic; tokens scope reach.

| Tool | Params | Notes |
|---|---|---|
| `send_message` | `to`(req paneId), `body`(req), `from?`(default `$HYPERPANES_PANE_ID`\|`orchestrator`) | `{ok,to,from,seq}`. At-least-once durable inbox. |
| `send_to_parent` | `body`(req), `from?` | resolves target from this pane's `meta.parent`; errors if unset. |
| `broadcast_subtree` | `body`(req), `root?`(default `$HYPERPANES_PANE_ID`), `from?` | messages every pane whose `meta.parent` chain leads to `root` (excludes root). |
| `mint_token` | `windowIds?`, `tabIds?`, `paneIds?`, `ttlMs?` | `{ok,token,scope,expiresAt,port,events,hint}`. Pass via `open_pane env`. No escalation. |
| `lock_pane` / `unlock_pane` | `paneId`(req), `owner`(req), `ttlMs?`(default 30000) | advisory write lock; hold the same `owner` on input calls. Re-lock as owner to renew. |

**Driving a TUI agent — two patterns:**
- **Structured bus (preferred if the worker also has the hyperpanes MCP):** converse over `send_message`/`send_to_parent`/`read_messages`. Run the worker with an inbox-poll loop ("listening agent").
- **TUI scrape (any agent, incl. an interactive `claude`):** `prompt_pane`; use `send_keys(["enter"])` to clear the first-run trust dialog; watch `awaitingInput` to tell "blocked on a prompt" from "done".

## Resources (subscribable)

| URI | MIME | Content |
|---|---|---|
| `hyperpanes://pane/{paneId}/output` | text/plain | scrollback on read, deltas on subscribe |
| `hyperpanes://pane/{paneId}/messages` | application/json | durable inbox on read, live deliveries on subscribe |

An `activity` event (busy⇄idle⇄exited) fires `resources/list_changed` — the headline "agent went idle" orchestration signal.

## Env vars

`HYPERPANES_BIN` (launcher for `launch_workspace`; no PATH fallback) · `HYPERPANES_LAUNCH_ARGS` (leading launcher args) · `HYPERPANES_CONTROL_FILE` / `HYPERPANES_USER_DATA` (override control.json location) · `HYPERPANES_CONTROL_TOKEN` + `HYPERPANES_CONTROL_PORT` (scoped child token; **takes precedence over control.json**) · `HYPERPANES_PANE_ID` (enables `whoami`/hierarchy defaults) · `HYPERPANES_ALLOW_INPUT` · `HYPERPANES_INPUT_ALLOWLIST`.

**control.json discovery order:** scoped-token env → `HYPERPANES_CONTROL_FILE` → `HYPERPANES_USER_DATA`/control.json → platform default (`%APPDATA%\hyperpanes\control.json` on Windows). Missing file → "Start hyperpanes and enable Allow agent control".

## Footguns
- `mode:"cli"` silently drops fields — default to `file`; check `droppedFields` if you use `cli`.
- `command`+`args` for verbatim argv; `command` alone gets shell-reparsed (spaces/quotes mangled).
- `submit:true` + no trailing newline; lone `\n` = bracketed paste.
- `activity` is a heuristic, not "done". `awaitingInput` (from `prompt_pane`/`read_pane`) is the better "blocked on prompt" signal.
- Gate refusals are `{ok:false,refused:true}` (not MCP errors); app-side 403 *throws* (`isError:true`).
- Scoped child token + port → child reads no control.json, reaches only its subtree.
- Fresh client per call → a restarted app (new port/token) is picked up automatically; a stale token → `/state` 401.
