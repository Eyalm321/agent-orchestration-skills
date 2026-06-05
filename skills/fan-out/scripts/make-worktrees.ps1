<#
.SYNOPSIS
  Create one git worktree + branch per fan-out track and drop each track's handoff in.
.DESCRIPTION
  Reads .fanout/plan.json (schema in DECOMPOSE.md). Refuses to run on a dirty tree.
  Idempotent: skips a worktree that already exists.
.EXAMPLE
  pwsh scripts/make-worktrees.ps1 -Plan .fanout/plan.json
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Plan
)
$ErrorActionPreference = 'Stop'

$plan = Get-Content -Raw -LiteralPath $Plan | ConvertFrom-Json
$repo = $plan.repo
if (-not $repo) { throw "plan.json has no 'repo'." }

# Resolve base branch (default: current HEAD of the repo).
$base = if ($plan.base) { $plan.base } else { (git -C $repo rev-parse --abbrev-ref HEAD).Trim() }

# Safety gate: clean working tree only — worktrees branch from HEAD.
$dirty = git -C $repo status --porcelain
if ($dirty) { throw "Working tree at $repo is not clean. Commit or stash before fanning out." }

foreach ($t in $plan.tracks) {
  $wt     = $t.worktree
  $branch = $t.branch
  if (Test-Path -LiteralPath $wt) {
    Write-Warning "Worktree already exists, skipping: $wt"
  } else {
    Write-Host "==> worktree $wt  (branch $branch, base $base)"
    git -C $repo worktree add -b $branch $wt $base
  }

  # Place the handoff inside the worktree so the agent (and --append-system-prompt-file) can read it.
  if ($t.handoff) {
    $src = Join-Path $repo $t.handoff
    if (Test-Path -LiteralPath $src) {
      Copy-Item -LiteralPath $src -Destination (Join-Path $wt 'FANOUT-HANDOFF.md') -Force
    } else {
      Write-Warning "Handoff not found for track '$($t.name)': $src"
    }
  }
}

Write-Host "`nAll worktrees ready. Next: open one hyperpanes pane per track — SKILL.md step 8 (open_pane with each track's claude command)."
