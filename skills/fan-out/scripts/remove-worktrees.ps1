<#
.SYNOPSIS
  Tear down the git worktrees + branches a fan-out run created — the counterpart to make-worktrees.ps1.
.DESCRIPTION
  Reads .fanout/plan.json (schema in DECOMPOSE.md). Removes one worktree per track and prunes.
  Idempotent: skips a worktree that's already gone. Refuses to discard a dirty worktree unless -Force.
  Closing the hyperpanes panes is a separate MCP step (close_pane per paneId, agent panes only —
  never the shared tab); see CONTRACTS.md "Fan-in".
.EXAMPLE
  pwsh scripts/remove-worktrees.ps1 -Plan .fanout/plan.json
.EXAMPLE
  pwsh scripts/remove-worktrees.ps1 -Plan .fanout/plan.json -DeleteBranches
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Plan,
  [switch]$DeleteBranches,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'

$plan = Get-Content -Raw -LiteralPath $Plan | ConvertFrom-Json
$repo = $plan.repo
if (-not $repo) { throw "plan.json has no 'repo'." }

foreach ($t in $plan.tracks) {
  $wt     = $t.worktree
  $branch = $t.branch

  if (Test-Path -LiteralPath $wt) {
    # Don't silently discard uncommitted work — that's how fan-out results get lost.
    $dirty = git -C $wt status --porcelain
    if ($dirty -and -not $Force) {
      Write-Warning "Worktree has uncommitted changes, skipping (use -Force to discard): $wt"
      continue
    }
    Write-Host "==> remove worktree $wt"
    if ($Force) { git -C $repo worktree remove --force $wt }
    else        { git -C $repo worktree remove $wt }
  } else {
    Write-Warning "Worktree already gone, skipping: $wt"
  }

  if ($DeleteBranches -and $branch) {
    # -d only deletes fully-merged branches; warn (don't throw) if it isn't merged yet.
    git -C $repo branch -d $branch 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "    deleted branch $branch"
    } else {
      Write-Warning "Branch not fully merged, kept: $branch (use 'git -C $repo branch -D $branch' to force)"
    }
  }
}

git -C $repo worktree prune
Write-Host "`nWorktrees torn down. Remaining:"
git -C $repo worktree list
Write-Host "`nReminder: close each fan-out pane in hyperpanes — close_pane per paneId (agent panes only, not the shared tab). See CONTRACTS.md 'Fan-in'."
