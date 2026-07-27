#!/usr/bin/env bash
# Plain-bash test suite for validate-release-is-dark.sh.
# Exercises external behavior only: exit code + message per case.
#
# Deleted along with the guard it covers on the day Pro goes on sale.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-release-is-dark.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# A miniature project.pbxproj with the shape the real one has: XCBuildConfiguration
# blocks carrying `SWIFT_ACTIVE_COMPILATION_CONDITIONS` and a trailing `name = …`.
# Tabs are load-bearing — the guard anchors on the two-tab indent Xcode writes.
#
# `debug_conditions` / `dev_conditions` / `release_conditions` are the values of
# that setting; an empty string omits the key entirely, which is how `Release`
# looks today (a compilation condition is present or it is not).
#
# Usage: write_pbxproj <path> <debug> <dev> <release> [target_release]
write_pbxproj() {
  local path="$1" debug="$2" dev="$3" release="$4" target_release="${5-}"
  emit_config() { # <uuid> <name> <conditions>
    printf '\t\t%s /* %s */ = {\n' "$1" "$2"
    printf '\t\t\tisa = XCBuildConfiguration;\n'
    printf '\t\t\tbuildSettings = {\n'
    printf '\t\t\t\tBASE_BUNDLE_ID = com.renan.beachtennis;\n'
    [[ -n "$3" ]] && printf '\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "%s";\n' "$3"
    printf '\t\t\t};\n'
    printf '\t\t\tname = %s;\n' "$2"
    printf '\t\t};\n'
  }
  {
    emit_config AAAA0001 Debug "$debug"
    emit_config AAAA0002 Dev "$dev"
    emit_config AAAA0003 Release "$release"
    # Target-level configurations. Real ones do not set compilation conditions,
    # so these are empty unless a case deliberately plants one.
    emit_config BBBB0001 Debug ""
    emit_config BBBB0002 Dev ""
    emit_config BBBB0003 Release "$target_release"
  } > "$path"
}

readonly ON="DEBUG PRO_ON_SALE"

GOOD="$WORKDIR/good.pbxproj"
write_pbxproj "$GOOD" "$ON" "$ON" ""

pass=0
fail=0

assert_accepts() {
  local desc="$1" pbxproj="$2"
  local out status
  out="$("$VALIDATE" "$pbxproj" 2>&1)"
  status=$?
  if [[ $status -eq 0 ]]; then
    echo "ok   - $desc"
    pass=$((pass + 1))
  else
    echo "FAIL - $desc (exit=$status output=$out)"
    fail=$((fail + 1))
  fi
}

assert_rejects() {
  local desc="$1" expected_pattern="$2" pbxproj="$3"
  local out status
  out="$("$VALIDATE" "$pbxproj" 2>&1)"
  status=$?
  if [[ $status -ne 0 && "$out" =~ $expected_pattern ]]; then
    echo "ok   - $desc"
    pass=$((pass + 1))
  else
    echo "FAIL - $desc (exit=$status output=$out)"
    fail=$((fail + 1))
  fi
}

# --- The baseline: today's project ------------------------------------------

assert_accepts "Release without the flag is accepted" "$GOOD"

# The real project file, so the fixtures above cannot drift into agreeing with
# each other while disagreeing with what ships. This is the case that fails on
# the day the flag is flipped — deliberately, and it is the signal to delete
# this guard rather than to work around it.
REAL="$SCRIPT_DIR/../BeachTennisCounter/BeachTennisCounter.xcodeproj/project.pbxproj"
assert_accepts "the checked-in project ships dark" "$REAL"

# --- The assertion that matters ---------------------------------------------

ON_PBX="$WORKDIR/release-on.pbxproj"
write_pbxproj "$ON_PBX" "$ON" "$ON" "PRO_ON_SALE"
assert_rejects "Release defining the flag is rejected" \
  "Release configuration defines PRO_ON_SALE" "$ON_PBX"

# The guard reads *every* build configuration block, not just the project-level
# ones: a flag set on the app target alone would ship just as surely, and a
# guard that only walked the project level would wave it through.
TARGET_PBX="$WORKDIR/target-release-on.pbxproj"
write_pbxproj "$TARGET_PBX" "$ON" "$ON" "" "PRO_ON_SALE"
assert_rejects "the flag set on a target-level Release config is rejected" \
  "Release configuration defines PRO_ON_SALE" "$TARGET_PBX"

# Substring, not word: a condition list is space-separated, and the flag can sit
# anywhere in it.
MIDDLE_PBX="$WORKDIR/middle.pbxproj"
write_pbxproj "$MIDDLE_PBX" "$ON" "$ON" "SOMETHING PRO_ON_SALE ELSE"
assert_rejects "the flag among other Release conditions is rejected" \
  "Release configuration defines PRO_ON_SALE" "$MIDDLE_PBX"

# Release may legitimately gain unrelated conditions. The guard is about the
# flag, not about Release being condition-free.
OTHER_PBX="$WORKDIR/other.pbxproj"
write_pbxproj "$OTHER_PBX" "$ON" "$ON" "SOME_OTHER_CONDITION"
assert_accepts "an unrelated Release condition is accepted" "$OTHER_PBX"

# --- Proof that a clean verdict means something ------------------------------
#
# A guard that stopped matching would report no offenders and vouch for nothing.
# These are the cases that keep a pass honest.

for config in Debug Dev; do
  MISSING="$WORKDIR/no-$config.pbxproj"
  if [[ "$config" == Debug ]]; then
    write_pbxproj "$MISSING" "DEBUG" "$ON" ""
  else
    write_pbxproj "$MISSING" "$ON" "DEBUG" ""
  fi
  assert_rejects "the flag missing from $config is rejected" \
    "the $config configuration does not define PRO_ON_SALE" "$MISSING"
done

NO_RELEASE="$WORKDIR/no-release.pbxproj"
write_pbxproj "$NO_RELEASE" "$ON" "$ON" ""
grep -v 'name = Release;' "$NO_RELEASE" > "$NO_RELEASE.tmp" && mv "$NO_RELEASE.tmp" "$NO_RELEASE"
assert_rejects "a project with no Release configuration is rejected" \
  "no Release configuration found" "$NO_RELEASE"

EMPTY="$WORKDIR/empty.pbxproj"
: > "$EMPTY"
assert_rejects "an unrecognisable project structure is rejected" \
  "no XCBuildConfiguration blocks found" "$EMPTY"

assert_rejects "a missing Xcode project is rejected" \
  "Xcode project not found" "$WORKDIR/nope.pbxproj"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
