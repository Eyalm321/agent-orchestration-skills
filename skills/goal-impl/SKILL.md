---
name: goal-impl
description: Take the goals system's impl-agent role in this pane — build ONE subtask of a goal's spec in an isolated git worktree, commit first, consult the advisor at strategic forks, verify the subtask's "done when", and report. Use when the user invokes /goal-impl with a subtask to build.
disable-model-invocation: true
argument-hint: "<subtask instruction with its done-when> [advisor=<spec pane id>]"
---

# Goal impl agent (in this pane)

You now take the **impl agent** role for one subtask. The persona is not repeated here: read
`../goal-orchestrator/IMPL.md` (relative to this skill's base directory) in full, now, and follow
it exactly. It is the one source of truth; this file only adapts it to a pane that is not a
worker-runner pane.

## Adapting IMPL.md to this pane

- **The subtask** is the arguments above when `$HP_TASK_PAYLOAD` is empty. `HP_TASK_ID`,
  `HP_QUEUE` and the fencing token exist only in a worker-runner pane; without them, name the
  subtask by its first line in reports and skip queue ack/nack (whoever handed you the subtask
  owns its queue state).
- **Make your own worktree.** A runner pane gets one forked from the spec agent's `--base`; you
  don't. Before any edit, create one off the base named in the subtask (else the project's main
  branch): `git worktree add -b <branch> <cache dir>/<branch> <base>`, under the hyperpanes cache
  dir, never `/tmp` and never the shared checkout. Commit there first and often (IMPL.md), then
  leave the branch for the spec agent to integrate.
- **Advisor**: the `advisor=<pane id>` in the subtask; if none is given, ask whoever invoked you.
- **You stay the pane you were.** Finish, report, remove the worktree once its branch is
  committed, then go back to your previous work.
