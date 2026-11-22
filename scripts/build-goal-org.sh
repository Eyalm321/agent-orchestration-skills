#!/usr/bin/env bash
# Write the goal-org plugin as plain files (symlinks resolved): the pristine tree an app bundles.
#
#   scripts/build-goal-org.sh <out-dir>
#
# <out-dir> is replaced. The result holds .claude-plugin/plugin.json, README.md and
# skills/{goal-orchestrator,goal-spec,goal-impl,use-hyperpanes}/, each file byte-identical to its source in this repo.
set -euo pipefail

out="${1:?usage: build-goal-org.sh <out-dir>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$root/plugins/goal-org"

rm -rf "$out"
mkdir -p "$out"
# -L follows the skill symlinks, so the output carries the files, not links back into this repo.
cp -RL "$src/." "$out/"
find "$out" -type l -print -quit | grep -q . && { echo "build-goal-org: a symlink survived in $out" >&2; exit 1; }
echo "goal-org plugin written to $out"
