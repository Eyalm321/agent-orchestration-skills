# claude CLI — flag reference

From `claude --help` (v2.1.x). `claude [options] [command] [prompt]`. Defaults to an **interactive** session; `-p/--print` is non-interactive.

## Identity & context
| Flag | Notes |
|---|---|
| `--append-system-prompt <p>` | Append to the default system prompt (keep Claude Code behavior). |
| `--append-system-prompt-file <path>` | File variant — use for long/multi-line personas. |
| `--system-prompt <p>` / `--system-prompt-file <path>` | **Replace** the system prompt entirely. |
| `--agents '<json>'` | Inline custom agents: `{"reviewer":{"description":"…","prompt":"…"}}`. |
| `--agent <name>` | Use a named agent for the session (overrides the `agent` setting). |
| `--add-dir <dirs...>` | Extra directories tools may access (also CLAUDE.md dirs under `--bare`). |

## Model, effort, budget
| Flag | Values |
|---|---|
| `--model <m>` | alias (`opus`,`sonnet`,`haiku`) or full id (`claude-opus-4-8`). |
| `--effort <level>` | `low, medium, high, xhigh, max`. |
| `--fallback-model <m,…>` | with `-p`; try each when primary is overloaded. |
| `--max-budget-usd <n>` | with `-p`; cap API spend. |

## Mode & output (headless)
| Flag | Values / notes |
|---|---|
| `-p, --print` | Print response and exit. Skips the workspace-trust dialog — only in trusted dirs. |
| `--output-format <f>` | `text` (default), `json`, `stream-json` (with `-p`). |
| `--input-format <f>` | `text` (default), `stream-json` (with `-p`). |
| `--include-partial-messages` | partial chunks (with `--print` + `--output-format=stream-json`). |
| `--include-hook-events` | hook lifecycle events (with `stream-json`). |
| `--replay-user-messages` | echo stdin user messages back on stdout (stream-json in+out). |
| `--json-schema '<schema>'` | validate structured output against a JSON Schema. |

## Permissions & tools
| Flag | Values |
|---|---|
| `--permission-mode <m>` | `default, plan, acceptEdits, dontAsk, auto, bypassPermissions`. |
| `--allowedTools` / `--disallowedTools <t…>` | e.g. `"Bash(git *) Edit"`. |
| `--tools <t…>` | restrict the built-in set (`""`=none, `default`=all, or names). |
| `--dangerously-skip-permissions` | bypass all checks (sandboxes only). |
| `--allow-dangerously-skip-permissions` | make bypass available without enabling it. |

## Session
| Flag | Notes |
|---|---|
| `--session-id <uuid>` · `-n/--name <name>` | fixed id / display name. |
| `-r/--resume [id]` · `-c/--continue` | resume by id/picker / continue most recent in cwd. |
| `--fork-session` | on resume, create a new id instead of reusing. |
| `--no-session-persistence` | don't save (with `-p`); not resumable. |
| `--from-pr [n/url]` | resume a session linked to a PR. |

## Isolation, MCP, config
| Flag | Notes |
|---|---|
| `--bare` | Minimal mode: skip hooks, LSP, plugin sync, attribution, auto-memory, prefetches, keychain, CLAUDE.md discovery. Sets `CLAUDE_CODE_SIMPLE=1`; auth strictly `ANTHROPIC_API_KEY`/`apiKeyHelper`. Provide context explicitly. |
| `--exclude-dynamic-system-prompt-sections` | move cwd/env/git/memory out of the system prompt → better cross-run cache reuse. |
| `-w/--worktree [name]` · `--tmux` | new git worktree for the session; tmux needs `--worktree`. |
| `--mcp-config <c…>` · `--strict-mcp-config` | load MCP servers from JSON files/strings; ignore others. |
| `--settings <file-or-json>` · `--setting-sources <user,project,local>` | extra settings / which sources to load. |
| `--plugin-dir <path>` · `--plugin-url <url>` | load a plugin for this session only. |
| `--betas <…>` | beta headers (API-key users). |

## Subcommands
`claude <cmd>`: `agents` (manage background agents) · `auth` · `mcp` (manage MCP servers) · `plugin|plugins` · `project` · `setup-token` (long-lived token) · `ultrareview [target]` (cloud multi-agent review) · `update|upgrade` · `doctor` · `install [target]` · `auto-mode`.
