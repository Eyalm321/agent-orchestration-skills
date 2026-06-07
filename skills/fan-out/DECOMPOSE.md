# Decompose — graph + tracks

The whole point: **maximise the number of agents that can safely work at once.** "Safely" has two axes — no logical dependency between parallel work, and no two parallel agents editing the same file.

## Edge types (they are NOT the same thing)

- **Logical edge** `A → B` (directed): B's `Blocked-by` lists A. B cannot start before A. These form a DAG.
- **File/resource edge** `A — B` (undirected co-location): A and B touch the same file/module. No inherent order, but they **must not** run in different worktrees or they collide at merge. Resolve by putting them in the **same track** (one agent does both, in sequence).

## Finding file/resource edges

`/to-issues` deliberately omits file paths, so infer them:

1. For each issue, read its acceptance criteria and use the `Explore` subagent to find the files/modules it will most likely touch.
2. Build a `file → [issues]` map. Any file touched by 2+ issues creates a co-location edge between them.
3. A "god file" everyone touches collapses parallelism. If you see one, **warn the user** and suggest splitting it (a deepening opportunity → `/improve-codebase-architecture`) or accept reduced width.

## The algorithm

1. **Co-locate**: union issues joined by any file/resource edge (union-find). Each union becomes a **super-node** one agent owns.
2. **Lift logical edges** onto super-nodes: a `Blocked-by` between issues in different super-nodes becomes an edge between super-nodes. (An edge inside a super-node is just sequencing for that one agent.)
3. **Components**: connected components of the super-node graph are fully independent → free, zero-coordination parallelism.
4. **Min-chain-cover within each component** (Dilworth): partition the component's super-nodes into the fewest chains. The number of chains = the component's **width**. Each chain → one **track** → one agent (runs its super-nodes/issues in topological order).
5. **Max agents = Σ component widths.**
6. **Cross-track edges**: any lifted logical edge whose endpoints land in different tracks is a cross-edge → handle via [CONTRACTS.md](CONTRACTS.md) (contract-stub by default, wave/sync if un-freezable).

## Epic reconciliation (hybrid)

`Parent`/epic is a **prior**, the graph is the **truth**:
- Default: keep an epic's issues together as one track.
- **Split** an epic when its issues form ≥2 independent chains (internal width > 1) — more agents.
- **Merge** two tiny independent epics onto one agent when each is a trivial chain, to balance load and stay under the soft cap.

## plan.json schema

```json
{
  "repo": "C:\\path\\to\\repo",
  "base": "main",
  "tracks": [
    {
      "name": "auth",
      "branch": "fanout/auth",
      "worktree": "C:\\path\\to\\repo.fanout\\auth",
      "model": "opus",
      "effort": "high",
      "handoff": ".fanout/handoffs/auth.md",
      "issues": ["#12", "#15", "#18"],
      "hitl": ["#15"],
      "consumes": ["UserStore"],
      "produces": []
    }
  ],
  "contracts": [
    {
      "name": "UserStore",
      "producer": "data",
      "consumers": ["auth"],
      "mode": "contract",
      "file": ".fanout/contracts/UserStore.md"
    }
  ]
}
```

`model`/`effort` default to the run-wide uniform values and differ only when the user overrides a track at the checkpoint. (No per-track `color` — hyperpanes tints each pane automatically from its worktree's git project; see SKILL.md step 8.) `mode` is `contract` or `wave`.
