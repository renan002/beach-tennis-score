#!/usr/bin/env bash
# Refuses a `Release` build that would ship Pro on sale.
#
# `PRO_ON_SALE` backs `FeatureFlags.proOnSale`. Pro is fully built but dark in
# shipped builds: the purchase surface and all three Pro gates are absent from
# `Release` because the condition is absent from `Release`. This asserts that,
# and nothing else.
#
# THIS GUARD IS MEANT TO BE DELETED. The day Pro goes on sale, `Release` gains
# the condition and this script becomes false by design — see the switch-on
# checklist in docs/pro-switch-on-checklist.md. Deleting it — this file, its
# test, and the `release-is-dark` job in ci.yml — is part of the same commit
# that flips the flag. There is deliberately no bypass flag: a permanent
# escape hatch guarding a one-time event is worse than an honest deletion,
# because it can be tripped by CI configuration nobody is reading at the time.
#
# Why a script and not only the unit test: `ProEntitlementTests` asserts the
# same wiring, but it lives in the macOS `test` job, which is expensive and
# skips its own build steps when no app files changed. This runs on ubuntu in
# seconds against any commit, so it can be a required status check in its own
# right — which is what actually blocks the merge into `main`, and that merge
# is what triggers the Xcode Cloud build that becomes a binary.
#
# Reads the checked-in `project.pbxproj`, not `project.yml`: the pbxproj is what
# Xcode archives. `project.yml` only reaches a build via `xcodegen generate`, so
# a project.yml edit that was never regenerated cannot affect the artifact, and
# one that was regenerated is visible here. Same reasoning as
# `scripts/validate-release-version.sh`.
set -euo pipefail

PBXPROJ="${1:-BeachTennisCounter/BeachTennisCounter.xcodeproj/project.pbxproj}"

# The condition whose presence in `Release` means Pro would ship on sale.
readonly FLAG="PRO_ON_SALE"

if [[ ! -f "$PBXPROJ" ]]; then
  echo "error: Xcode project not found at $PBXPROJ" >&2
  exit 1
fi

# Every XCBuildConfiguration block in the file, emitted as "<name>\t<yes|no>"
# where the second field is whether the block defines the flag.
#
# *Every* block, not just the project-level ones: a target-level configuration
# can carry its own `SWIFT_ACTIVE_COMPILATION_CONDITIONS`, and a guard that only
# read the project level would miss a flag set on the app target alone.
#
# Blocks are matched on the two-tab indent Xcode writes, the same anchor
# `validate-release-version.sh` uses.
scan() {
  awk -v flag="$FLAG" '
    /^\t\t[0-9A-F]+ \/\* .* \*\/ = \{/ { inblock = 1; isconfig = 0; found = 0; name = ""; next }
    inblock && /^\t\t\};/ {
      if (isconfig && name != "") printf "%s\t%s\n", name, (found ? "yes" : "no")
      inblock = 0
      next
    }
    inblock && /isa = XCBuildConfiguration;/ { isconfig = 1 }
    inblock && /SWIFT_ACTIVE_COMPILATION_CONDITIONS/ && $0 ~ flag { found = 1 }
    inblock && /^\t\t\tname = / {
      name = $0
      sub(/^[^=]*= */, "", name)
      sub(/;[[:space:]]*$/, "", name)
      gsub(/^"|"$/, "", name)
    }
  ' "$PBXPROJ"
}

BLOCKS="$(scan)"

if [[ -z "$BLOCKS" ]]; then
  echo "error: no XCBuildConfiguration blocks found in $PBXPROJ — the project structure changed and this guard needs updating" >&2
  exit 1
fi

# Blocks named <config name> that do (or do not) define the flag. `awk` rather
# than `grep -P`, which BSD grep does not have — this runs on a developer's Mac
# as well as on ubuntu in CI.
count_with() { # <config name> <yes|no>
  awk -F'\t' -v name="$1" -v want="$2" '$1 == name && $2 == want { n++ } END { print n + 0 }' <<< "$BLOCKS"
}

# --- The assertion that matters ---------------------------------------------

OFFENDERS="$(count_with Release yes)"

if (( OFFENDERS > 0 )); then
  echo "error: the Release configuration defines $FLAG — a shipped build would put Pro on sale." >&2
  echo "       If Pro is going on sale deliberately, this guard has done its job and should be" >&2
  echo "       deleted in the same commit that flips the flag (see the switch-on checklist in" >&2
  echo "       docs/pro-switch-on-checklist.md). Otherwise, remove $FLAG from Release." >&2
  exit 1
fi

# --- Proof that the assertion above means anything ---------------------------
#
# A walk that silently stopped matching would report zero offenders and vouch
# for nothing. Requiring `Release` to exist, and the two debug configurations to
# carry the flag, is what makes the clean result trustworthy.

if (( $(count_with Release yes) + $(count_with Release no) == 0 )); then
  echo "error: no Release configuration found in $PBXPROJ — this guard proves nothing about the configuration we ship" >&2
  exit 1
fi

for config in Debug Dev; do
  if (( $(count_with "$config" yes) == 0 )); then
    echo "error: the $config configuration does not define $FLAG. Either the flag was removed from" >&2
    echo "       the configurations that are supposed to have it, or this guard's read of the" >&2
    echo "       project file broke — in which case its verdict on Release is worthless." >&2
    exit 1
  fi
done

echo "Release does not define $FLAG — Pro would ship dark."
