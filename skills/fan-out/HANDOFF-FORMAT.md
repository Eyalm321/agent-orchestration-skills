# Per-track handoff format

Extends `/handoff` — keep its discipline: reference artifacts by path/URL instead of duplicating them, redact secrets, and include a suggested-skills section. Add the fan-out-specific sections below so a fresh agent can work its track in isolation without colliding with the others.

Write each to `.fanout/handoffs/<track>.md`. `make-worktrees.ps1` copies it into the worktree as `FANOUT-HANDOFF.md`.

## Template

```md
# Fan-Out Handoff — Track: <name>

You are **one of N parallel agents**. Work ONLY this track. Commit to your branch.
Pause at any [HITL] slice and ask the user in your pane before proceeding.

## Worktree & branch
- Worktree: <path>  (your shell already starts here)
- Branch: fanout/<name>  (commit here; never switch branches)

## Issues — do in this order
1. #12 — <title>  [AFK]
2. #15 — <title>  [HITL ← pause, ask the user]
3. #18 — <title>  [AFK]

Read each issue in the tracker for full acceptance criteria. Do NOT edit or close parent issues.

## Files you OWN
- src/auth/**, src/session.ts

**TOUCH NOTHING ELSE.** Other agents own other files; editing outside this scope causes the merge conflicts fan-out exists to avoid. If you discover you must touch a file outside scope, STOP and tell the user — it means the graph was wrong.

## Contracts
Consume (code against the stub; do NOT implement these):
- UserStore — see ../<repo>/.fanout/contracts/UserStore.md
Produce (other tracks depend on this EXACT interface — keep it stable):
- (none)

## Definition of done
- [ ] Every issue's acceptance criteria met
- [ ] Tests pass in this worktree
- [ ] `git diff --name-only` stays within owned files
- [ ] Work committed to fanout/<name>

## Reference (don't duplicate)
- Epic / master plan: <link or path>

## Suggested skills
- `/tdd` per issue; `/diagnose` if you hit a hard bug.
```

## Notes
- The kickoff prompt passed at launch is short ("read your handoff and begin"); the handoff carries the substance via `--append-system-prompt-file`, so it stays in context every turn.
- HITL slices are flagged here only — there is no auto-routing. The user monitors the panes and resolves HITL grills live.
