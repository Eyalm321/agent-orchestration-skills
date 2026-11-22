---
name: goal-spec
description: Take the goals system's spec-agent role in this pane — turn ONE goal into a concrete spec, fan it out to impl-agent worker panes over the goal's work queue, advise them, integrate, verify acceptance, and report to the orchestrator. Use when the user invokes /goal-spec with a goal to own.
disable-model-invocation: true
argument-hint: "<goal intent + acceptance> [queue=<name>] [parent=<orchestrator pane id>]"
---

# Goal spec agent (in this pane)

You now take the **spec agent** role for one goal. The persona is not repeated here: read
`../goal-orchestrator/SPEC.md` (relative to this skill's base directory) in full, now, and follow
it exactly. It is the one source of truth; this file only adapts it to a pane that did not start
as a spec agent.

## Adapting SPEC.md to this pane

- **The goal** comes from the arguments above. When the orchestrator started you it also sent the
  intent, acceptance, parent pane id and queue name; take whichever is given and infer the rest:
  - **Acceptance** missing: state the tightest reasonable check in your spec and go on.
  - **Queue** missing: use a project-qualified name (`<project>-<goal id>`). Queue names are global
    across projects, so a bare `g1` collides.
  - **Parent** missing: report to whoever invoked you (the user, or the pane that messaged you) in
    your replies instead of `send_to_parent`.
- **Your env may lack the goal variables** (`HP_GOAL_IMPL_MODEL`, `HP_GOAL_ACCOUNTS`,
  `HP_GOAL_PROJECT_NAME`, …) that a pane the orchestrator started carries. Use their defaults
  from SPEC.md, and the project name from `list_projects` for the pane's cwd.
- **Start workers with `hyperpanes launch-profile --tier worker`** (SPEC.md section 2). It brings
  the goal-org plugin, `IMPL.md` and the MCP config itself, so nothing from your own launch has to
  be threaded through. Use the long form only when the app has no `launch-profile` subcommand.
- **You stay the pane you were.** Finish the goal, report, then go back to your previous work. Do
  not close your own pane.
