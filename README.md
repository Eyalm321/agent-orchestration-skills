# Agent Orchestration Skills

Three composable [Claude Code](https://docs.claude.com/en/docs/claude-code) skills for spawning and orchestrating **parallel Claude agents** — across a plain terminal, the [hyperpanes](https://github.com/Eyalm321/hyperpanes) tiling-terminal app, and a dependency-aware fan-out over issues.

They form a layered trio, each composing the one below:

| Skill | Owns |
|---|---|
| **[use-claude](skills/use-claude/SKILL.md)** | Launch a `claude` CLI agent — identity via `--append-system-prompt`, task via the prompt arg, model/effort/permission-mode, interactive or headless. |
| **[use-hyperpanes](skills/use-hyperpanes/SKILL.md)** | Drive the hyperpanes app + MCP — spawn/read/drive tiled panes and orchestrate a manager→worker pane org. Routing: **MCP → control API → CLI**. |
| **[fan-out](skills/fan-out/SKILL.md)** | Decompose ready issues into the **maximum number of independent parallel tracks** (one git worktree + one hyperpanes pane each), then monitor and fan-in. |

**Composition boundary:** `use-claude` owns *claude-level identity* (persona + task + flags); the substrates own *org-level identity* (`meta.parent`/`mint_token` in hyperpanes, handoff/worktree in fan-out). Each composes the layer below rather than re-documenting it.

## Install

Copy the skills into your Claude Code skills directory:

```bash
cp -r skills/* ~/.claude/skills/
```

```powershell
# Windows PowerShell
Copy-Item skills\* "$env:USERPROFILE\.claude\skills\" -Recurse -Force
```

Or, once pushed to GitHub, via the [skills CLI](https://skills.sh):

```bash
npx skills@latest add <your-github-user>/<repo>
```

## Requirements

- **Claude Code** — the `claude` CLI on `PATH`.
- **use-hyperpanes / fan-out** — the [hyperpanes](https://github.com/Eyalm321/hyperpanes) app + its [MCP](https://github.com/Eyalm321/hyperpanes-mcp) (user-scoped), with Preferences → General → **"Allow agent control"** enabled.

## What's in each skill

- **use-claude** — `SKILL.md` + `FLAGS.md` (full `claude` CLI flag catalog).
- **use-hyperpanes** — `SKILL.md` + `MCP.md` (tool catalog) + `API.md` (raw HTTP/WS control API) + `CLI.md` (`workspace.json` + flags).
- **fan-out** — `SKILL.md` + `DECOMPOSE.md` (the components → min-chain-cover graph algorithm) + `HANDOFF-FORMAT.md` + `CONTRACTS.md` + `scripts/make-worktrees.ps1`.

## License

MIT — see [LICENSE](LICENSE).
