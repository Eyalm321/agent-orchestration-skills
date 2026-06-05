---
name: use-claude
description: Launch the `claude` command-line tool as a sub-agent — give it an identity with `--append-system-prompt`, a task via the prompt argument, and choose model/effort/permission-mode, interactive or headless `-p`. Use when spawning, opening, or scripting a `claude` CLI process (in a shell, a hyperpanes pane, a fan-out worktree, or standalone), giving a launched agent a persona/system prompt, or passing a prompt plus flags to `claude` on the command line. This is the CLI, not the Claude API/SDK (use claude-api for that).
---

# Use Claude (CLI)

Spawn a `claude` process with a clear split: **identity** (who it is — a system prompt) and **task** (what to do now — the prompt argument). Substrate-agnostic — the same invocation works in a raw shell, a [hyperpanes](../use-hyperpanes/SKILL.md) pane (`open_pane`), or a `/fan-out` worktree.

```
claude  <identity flags>  <model/effort>  <permission flags>  "<task prompt>"
```

## Identity (who the agent is)
- **`--append-system-prompt "<persona>"`** — append to Claude Code's default system prompt. **The default choice**: keeps all built-in behavior and *adds* a persona/role/constraints.
- **`--append-system-prompt-file <path>`** — same, but read the persona from a file. **Use for anything long or multi-line** — it sidesteps the quoting footgun below.
- `--system-prompt "<...>"` / `--system-prompt-file <path>` — **replace** the system prompt entirely (rare; you lose Claude Code's default identity).
- `--agents '<json>'` (inline `{"name":{"description","prompt"}}`) or `--agent <name>` — named-agent personas.

## Task (what it does now)
- The **positional prompt** seeds the work: `claude "Start on your assigned track; pause at HITL."`
- Interactive (default) opens a session pre-seeded with it. Headless `-p`/`--print` runs it and exits.

## Model & effort
- `--model <opus|sonnet|haiku | claude-opus-4-8>` · `--effort <low|medium|high|xhigh|max>`.
- `--fallback-model <m>` (with `-p`) retries another model when the primary is overloaded.

## Mode
- **Interactive** (default) — a live session you (or a parent) watch/drive. Best for supervised or TUI-driven agents.
- **Headless** — `-p` + `--output-format <text|json|stream-json>`; add `--max-budget-usd <n>` to cap spend. Best for autonomous one-shots whose result you parse. `--json-schema '<schema>'` validates structured output.

## Permissions
- `--permission-mode <default|plan|acceptEdits|dontAsk|auto|bypassPermissions>` — `plan` to make it present a plan first; `bypassPermissions` only in trusted sandboxes.
- `--allowedTools` / `--disallowedTools` (e.g. `"Bash(git *) Edit"`), `--tools` to restrict the built-in set, `--add-dir <dirs...>` for extra tool-access roots.

## ⚠️ The quoting footgun (most-bitten)
A long `--append-system-prompt "...with spaces and \"quotes\"..."` gets **mangled when a launcher re-parses it through a shell**. Two safe ways:
1. **`--append-system-prompt-file <path>`** — write the persona to a file, pass the path. Cleanest for anything non-trivial.
2. **Verbatim argv (no shell re-parse)** — pass each token as its own array element:
   - hyperpanes: `open_pane {command:"claude", args:["--append-system-prompt","<persona>","--model","opus","<task>"]}`
   - PowerShell: `& claude @('--append-system-prompt', $persona, '--model','opus', $task)`

## Recipes
- **Identity-scoped interactive worker:** `claude --model opus --effort high --append-system-prompt-file persona.md "Begin; pause at any [HITL] slice to ask me."`
- **Headless one-shot:** `claude -p --model sonnet --output-format json --append-system-prompt "You are a release-notes writer." "Summarize the diff on this branch."`
- **Clean/reproducible sub-agent:** add **`--bare`** — skips hooks/LSP/plugins/auto-memory/CLAUDE.md discovery and reads auth strictly from `ANTHROPIC_API_KEY`/`apiKeyHelper`. Provide context explicitly (`--append-system-prompt[-file]`, `--add-dir`, `--mcp-config`, `--agents`). Faster, isolated, deterministic.
- **Own worktree:** `-w/--worktree [name]` creates a git worktree for the session (Claude Code-native; `--tmux` adds a tmux session).

Full flag catalog (sessions, MCP/config, output streaming, subcommands): **[FLAGS.md](FLAGS.md)**.

## Composes with
- One claude **per hyperpanes pane** → `/use-hyperpanes` (`open_pane` with `command:"claude", args:[…]`).
- One claude **per fan-out track** → `/fan-out` (launches each track's handoff as a claude).
