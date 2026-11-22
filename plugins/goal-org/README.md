# goal-org

The goals system's agent skills, packaged as one Claude Code plugin. A goal agent wears it with
`claude --plugin-dir <dir>`:

- `skills/goal-orchestrator/` holds the personas. `SKILL.md` is the per-project goals orchestrator,
  `SPEC.md` the per-goal spec agent and `IMPL.md` the per-subtask impl agent. Each agent gets its
  persona with `--append-system-prompt-file`.
- `skills/goal-spec/` and `skills/goal-impl/` are user-invoked skills (`/goal-spec`, `/goal-impl`)
  that let a pane the goals system did not start take the spec or impl role. Each `SKILL.md` is a
  thin adapter that reads `../goal-orchestrator/SPEC.md` or `IMPL.md`: those two files stay the one
  source of truth for the persona text, because `hyperpanes launch-profile` and
  `--append-system-prompt-file` still load them directly.
- `skills/use-hyperpanes/` covers driving hyperpanes panes (MCP, control API, CLI). The personas
  depend on it.

## Where the text lives

The skill folders here are symlinks to the repo's own `skills/goal-orchestrator/`,
`skills/goal-spec/`, `skills/goal-impl/` and `skills/use-hyperpanes/`. Those stay the only copy you
edit. `plugin.json` and this README are the plugin's own files.

`scripts/build-goal-org.sh <out-dir>` writes the plugin as plain files with the symlinks resolved.
That output is the pristine tree an app bundles. hyperpanes ships it byte for byte in
`resources/claude/goal-org/`, and its `scripts/check-persona-sync.sh` CI check fails when the
bundled copy differs from this repo's `main`.
