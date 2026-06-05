# hyperpanes Control API — direct HTTP/WS

Use this tier when the `mcp__hyperpanes__*` tools aren't connected **but the app is running with "Allow agent control" on**. It's the loopback server the MCP wraps, so it recovers the full read/drive/orchestrate surface the CLI lacks. Every MCP tool maps 1:1 to a call here (see the mapping table).

## Discovery + auth

Read `control.json` (re-read per operation — port & token are **ephemeral**, regenerated each launch; the file is absent while control is off):
- Windows: `%APPDATA%\hyperpanes\control.json` · macOS: `~/Library/Application Support/hyperpanes/control.json` · Linux: `$XDG_CONFIG_HOME/hyperpanes/control.json`. Override via `HYPERPANES_CONTROL_FILE` / `HYPERPANES_USER_DATA`.

```json
{ "port": 51734, "token": "<64-hex>", "pid": 12345, "version": "1.2.3",
  "events": "ws://127.0.0.1:51734/events?token=<token>" }
```
- Base URL: `http://127.0.0.1:{port}` (use `127.0.0.1`, not `localhost`). Header: `Authorization: Bearer {token}`. `Content-Type: application/json` on bodies (cap 1 MB).
- A stale token → **401** (`{"error":"unauthorized"}`); re-read `control.json`. Unmatched path → **404**.

## Endpoints

| Method · Path | Body | Success | Notable codes |
|---|---|---|---|
| `GET /health` *(no auth)* | — | `{ok,app,pid,version,allowInput}` | — |
| `GET /state` | — | `{windows:[{windowId,activeTabId,tabs:[{id,title,layout,panes:[{id,sessionUid,label,color,command,args,cwd,shell,status,exitCode,activity,meta}]}]}]}` (scope-filtered) | 401 |
| `GET /panes/:id/output` | query: `tail,strip,since,mode=screen,waitForIdle,settleMs,timeoutMs` | `{paneId,status,output,cursor,since?,truncated?,mode?,awaitingInput?,waited?,settled?,timedOut?}` | 404 no pane · 403 out of scope |
| `POST /panes/:id/input` | `{data, submit?, submitDelayMs?, owner?}` **or** `{keys:[…], owner?}` | `{ok}` / `{ok,keys}` | **403 input not allowed** · 400 bad body/`unknown key(s)` · 423 `pane locked` · 404 |
| `GET /panes/:id/messages` | query: `after=N` | `{paneId,messages:[{seq,to,from,body,ts}],dropped,latestSeq}` | 404/403 |
| `POST /panes/:id/messages` | `{from?, body}` | `{ok,seq}` | 400 · 404/403 |
| `POST /panes/:id/lock` | `{owner, ttlMs?}` (ttl default 30000) | `{ok,owner,expiresAt}` | 423 `held` · 400 |
| `DELETE /panes/:id/lock` | `{owner}` | `{ok}` | 423 `not the lock holder` |
| `POST /tokens` | `{scope:{windowIds?,tabIds?,paneIds?}, ttlMs?}` | `{ok,token,scope,expiresAt,port,events}` | 400 · 403 escalation |
| `POST /command` | `{type, paneId?, tabId?, windowId?, …}` | `{ok,result}` | 400 · 403 scope · 404 window · **504 renderer wedged** · **500 store threw** |

**`/command` is the catch-all for every structural mutation** — open/close/focus/restart/rename/recolor pane, set layout, set meta — selected by the `type` string (the server forwards `type` opaquely to the renderer; the literals come from the MCP layer, e.g. `newPane`, `closePane`, `focusPane`, `restartPane`, `renamePane`, `recolorPane`, `setLayout`, `setMeta`). After a `newPane`, the pane is briefly absent from `/state` (debounced publish) — **poll `/state` (~75 ms, ~3 s cap) until it appears** before driving it.

## MCP tool → HTTP

| MCP tool | HTTP |
|---|---|
| `control_status` | `GET /health` (+ read control.json) |
| `list_panes` / `whoami` | `GET /state` |
| `read_pane` | `GET /panes/:id/output?…` |
| `send_input` / `send_keys` | `POST /panes/:id/input` (`data`/`keys` body) |
| `prompt_pane` | `POST /input {submit:true}` **then** polled `GET /output?waitForIdle&since` (compose client-side) |
| `open_pane` | `POST /command {type:"newPane",…}` **then** `/state` poll |
| `close/focus/restart/rename/recolor_pane`, `set_layout`, `set_meta` | `POST /command {type:…}` |
| `mint_token` | `POST /tokens` |
| `lock_pane` / `unlock_pane` | `POST` / `DELETE /panes/:id/lock` |
| `send_message` / `read_messages` | `POST` / `GET /panes/:id/messages` |
| `send_to_parent` / `broadcast_subtree` | `GET /state` (resolve `meta.parent` / subtree) **then** N× `POST …/messages` |

## /events WebSocket

Connect `ws://127.0.0.1:{port}/events?token={token}` (token in query; `Bearer` header also accepted). Server auths before handshake (bad token → 401 + socket destroyed), sends a `hello` frame, and **filters pane frames to the token's scope**. Frame types:
```
{type:"hello",pid,version}
{type:"output",sessionUid,paneId|null,data}      // pty delta
{type:"exit",sessionUid,paneId|null,code}
{type:"activity",paneId,activity:"busy"|"idle"|"exited"}   // the "agent went idle" signal
{type:"message",to,from,seq,body}
{type:"state"}                                    // structure changed → re-fetch /state (coalesced ~100ms)
```
`output`/`exit` may carry `paneId:null` before the pane is in the read model — resolve via `sessionUid` against a `/state`-built map.

## Gating (server-side)

- **`allowInput` toggle** (default off): **only** `POST /panes/:id/input` is gated → **403 `input not allowed`** (checked before body parse). Reads, commands, messages, locks, tokens are not input-gated. Disambiguate via `GET /health`'s `allowInput`.
- **Token scope:** a scoped token sees only its panes (`/state` filtered; out-of-scope pane routes → **403 `pane out of scope`**). `/tokens` cannot escalate beyond the minter. The master token in `control.json` is unscoped and never expires.
- **Advisory lock:** input to a pane locked by another `owner` → **423**; pass the matching `owner` in the input body to write through.

## Footguns
- **Submit ≠ newline.** A bare `\n` types but doesn't submit (conpty). Send `{data, submit:true}` — the server fires a **separate** `\r` after `submitDelayMs`. With `keys`, send `"enter"` explicitly (keys aren't newline-normalized).
- **Carry `cursor` → `since`** for delta reads; `truncated:true` = cursor fell off the buffer, re-baseline. `waitForIdle` won't settle on the stale pre-prompt screen when `since` is set.
- **Re-read `control.json` per op** (ephemeral port/token). `GET /health` is unauthenticated (local-only fingerprint).
- **`/command` failure codes are distinct:** 504 (renderer wedged) vs 500 (store threw) vs 404 (no window) — don't treat them as one generic error.
