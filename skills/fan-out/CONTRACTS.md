# Cross-edge contracts + fan-in

A **cross-edge** is a logical dependency whose two ends land in different tracks (track B needs something track A produces). Left unmanaged, B idles until A is done — which defeats the fan-out. Two tactics:

- **Contract-stub (default).** Freeze the shared interface up front. B codes against a stub *now*, in parallel; the real wiring happens at fan-in. Keeps every agent busy and forces a clean seam.
- **Wave/sync (fallback).** Only when the boundary genuinely can't be pinned yet (exploratory work, unknown shape). B's handoff says "block until `fanout/A` lands, then merge and continue." Safe but serial — use sparingly.

A contract is just an `interface` in the `/improve-codebase-architecture` sense: **everything a caller must know** — types, invariants, error modes, ordering — not only the signature.

## Contract doc template

Write to `.fanout/contracts/<name>.md`:

```md
# Contract: UserStore
Producer: data (branch fanout/data)
Consumers: auth
Mode: contract            # or: wave

## Interface
getUser(id: string): Promise<User | null>
saveUser(u: User): Promise<void>

## Invariants
- getUser returns null for an unknown id (does not throw)
- saveUser is idempotent on user.id

## Error modes
- throws StoreUnavailable on connection failure

## Stub
Consumers code against this signature. A throwaway stub returning canned data
lives at <path> until fan-in swaps it for the real implementation.
```

The **producer** track owns the real implementation and must not drift from this interface. The **consumer** track treats it as frozen; if it needs a change, that's a checkpoint with the user, not a unilateral edit.

## Fan-in

Run after the tracks finish (a deliberate, supervised step — not automated):

1. **Order.** Merge branches in dependency order — producers before consumers. A topological sort of the contract graph gives the order.
2. **Swap stubs.** For each contract, replace the consumer's stub with the producer's real implementation.
3. **Integration tests.** Run the full suite across the merged result — the contracts were promises; this is where they're verified.
4. **Resolve.** Fix any conflict or contract-drift surfaced. If a producer broke its frozen interface, that's the root cause — fix the producer, re-run.
5. **Clean up — tear every track down.** Once a track's branch is merged, leave no worktree or pane behind:
   - **Close its pane.** `close_pane { paneId }` for that track's pane id — find it via `list_panes` (match the `meta.task`/`role:"fanout-track"` you set at launch). Close the **agent panes by id only — never the shared tab**: the tracks run in the user's existing/active tab, and there is no `close_tab`.
   - **Remove its worktree.** `pwsh scripts/remove-worktrees.ps1 -Plan .fanout/plan.json` (idempotent counterpart to `make-worktrees.ps1`: `git worktree remove` per track + prune; skips a dirty worktree unless `-Force`). Add `-DeleteBranches` to also `git branch -d fanout/<track>` for the merged branches, or do `git worktree remove <path>` by hand.
   - Then delete the `.fanout/` run dir if you don't want to keep the record.

   Do it per track as each merges, or all at once at the end — but **fan-in isn't done until every fan-out worktree is removed and every fan-out pane is closed.**

If integration tests fail in a way that needs real debugging, hand off to `/diagnose`.
