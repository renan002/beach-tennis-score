#!/usr/bin/env bash
# Plain-bash test suite for validate-release-version.sh.
# Exercises external behavior only: exit code + stderr message per case.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-release-version.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

PROJECT_YML="$WORKDIR/project.yml"
cat > "$PROJECT_YML" <<'EOF'
settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "0.1.2"
    CURRENT_PROJECT_VERSION: "3"
EOF

# A miniature project.pbxproj with the same shape the real one has: a PBXProject
# pointing at an XCConfigurationList, which names the three configurations, each
# of which is an XCBuildConfiguration carrying the flavoring settings. Tabs are
# load-bearing — the script anchors its block matching on the two-tab indent
# Xcode writes.
#
# Note that `Dev` legitimately carries `.dev`. A guard that merely grepped the
# file for a suffix would fail every release; these fixtures pin down that it
# reads the *Release* configuration specifically.
#
# Usage: write_pbxproj <path> [release_suffix] [extra_target_bundle_id]
write_pbxproj() {
  local path="$1" release_suffix="${2-}" extra_id="${3-}"
  {
    printf '\t\t\tbuildConfigurationList = AAAA0001 /* Build configuration list for PBXProject "BeachTennisCounter" */;\n'
    printf '\t\tAAAA0001 /* Build configuration list for PBXProject "BeachTennisCounter" */ = {\n'
    printf '\t\t\tisa = XCConfigurationList;\n'
    printf '\t\t\tbuildConfigurations = (\n'
    printf '\t\t\t\tBBBB0001 /* Debug */,\n'
    printf '\t\t\t\tBBBB0002 /* Dev */,\n'
    printf '\t\t\t\tBBBB0003 /* Release */,\n'
    printf '\t\t\t);\n'
    printf '\t\t};\n'
    printf '\t\tBBBB0001 /* Debug */ = {\n'
    printf '\t\t\tisa = XCBuildConfiguration;\n'
    printf '\t\t\tbuildSettings = {\n'
    printf '\t\t\t\tBASE_BUNDLE_ID = com.renan.beachtennis;\n'
    printf '\t\t\t\tBUNDLE_ID_SUFFIX = "";\n'
    printf '\t\t\t};\n'
    printf '\t\t};\n'
    printf '\t\tBBBB0002 /* Dev */ = {\n'
    printf '\t\t\tisa = XCBuildConfiguration;\n'
    printf '\t\t\tbuildSettings = {\n'
    printf '\t\t\t\tBASE_BUNDLE_ID = com.renan.beachtennis;\n'
    printf '\t\t\t\tBUNDLE_ID_SUFFIX = .dev;\n'
    printf '\t\t\t};\n'
    printf '\t\t};\n'
    printf '\t\tBBBB0003 /* Release */ = {\n'
    printf '\t\t\tisa = XCBuildConfiguration;\n'
    printf '\t\t\tbuildSettings = {\n'
    printf '\t\t\t\tBASE_BUNDLE_ID = com.renan.beachtennis;\n'
    if [[ -n "$release_suffix" ]]; then
      printf '\t\t\t\tBUNDLE_ID_SUFFIX = %s;\n' "$release_suffix"
    else
      printf '\t\t\t\tBUNDLE_ID_SUFFIX = "";\n'
    fi
    printf '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)";\n'
    printf '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX).watchkitapp";\n'
    printf '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.renan.beachtennis.tests;\n'
    if [[ -n "$extra_id" ]]; then
      printf '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = %s;\n' "$extra_id"
    fi
    printf '\t\t\t};\n'
    printf '\t\t};\n'
  } > "$path"
}

PBXPROJ="$WORKDIR/project.pbxproj"
write_pbxproj "$PBXPROJ"

# A bare "remote" repo standing in for origin, so tests never touch the network.
REMOTE_DIR="$WORKDIR/remote.git"
git init --bare -q "$REMOTE_DIR"

SEED_DIR="$WORKDIR/seed"
git init -q "$SEED_DIR"
git -C "$SEED_DIR" config user.email test@example.com
git -C "$SEED_DIR" config user.name test
git -C "$SEED_DIR" commit -q --allow-empty -m "seed"
git -C "$SEED_DIR" branch release/0.5.0
git -C "$SEED_DIR" tag 0.4.0
git -C "$SEED_DIR" push -q "$REMOTE_DIR" main 2>/dev/null || git -C "$SEED_DIR" push -q "$REMOTE_DIR" master 2>/dev/null
git -C "$SEED_DIR" push -q "$REMOTE_DIR" release/0.5.0
git -C "$SEED_DIR" push -q "$REMOTE_DIR" 0.4.0

export RELEASE_VALIDATE_REMOTE="$REMOTE_DIR"

pass=0
fail=0

assert_accepts() {
  local desc="$1" version="$2" pbxproj="${3-$PBXPROJ}"
  local out status
  out="$("$VALIDATE" "$version" "$PROJECT_YML" "$pbxproj" 2>&1)"
  status=$?
  if [[ $status -eq 0 && "$out" == "$version" ]]; then
    echo "ok   - $desc"
    pass=$((pass + 1))
  else
    echo "FAIL - $desc (exit=$status output=$out)"
    fail=$((fail + 1))
  fi
}

assert_rejects() {
  local desc="$1" version="$2" expected_pattern="$3" pbxproj="${4-$PBXPROJ}"
  local out status
  out="$("$VALIDATE" "$version" "$PROJECT_YML" "$pbxproj" 2>&1)"
  status=$?
  if [[ $status -ne 0 && "$out" =~ $expected_pattern ]]; then
    echo "ok   - $desc"
    pass=$((pass + 1))
  else
    echo "FAIL - $desc (exit=$status output=$out)"
    fail=$((fail + 1))
  fi
}

assert_accepts "valid version strictly greater than current is accepted" "0.2.0"
assert_accepts "major bump is accepted" "1.0.0"

assert_rejects "missing patch segment is rejected" "1.2" "not a valid semver"
assert_rejects "non-numeric input is rejected" "abc" "not a valid semver"
assert_rejects "too many segments is rejected" "1.2.0.1" "not a valid semver"
assert_rejects "equal to current version is rejected" "0.1.2" "not greater than"
assert_rejects "less than current version is rejected" "0.1.1" "not greater than"
assert_rejects "colliding branch is rejected" "0.5.0" "branch 'release/0.5.0' already exists"
assert_rejects "colliding tag is rejected" "0.4.0" "tag '0.4.0' already exists"

# --- Release bundle id guard -------------------------------------------------
# The accepting cases above already prove the baseline: a project whose Dev
# configuration carries `.dev` still cuts fine, because the guard reads Release.

FLAVORED_PBX="$WORKDIR/flavored.pbxproj"
write_pbxproj "$FLAVORED_PBX" ".dev"
assert_rejects "flavored Release bundle id is rejected" "0.2.0" \
  "builds bundle id 'com.renan.beachtennis.dev'" "$FLAVORED_PBX"

HARDCODED_PBX="$WORKDIR/hardcoded.pbxproj"
write_pbxproj "$HARDCODED_PBX" "" "com.renan.beachtennis.staging"
assert_rejects "a target hardcoding its own bundle id is rejected" "0.2.0" \
  "do not derive their bundle id" "$HARDCODED_PBX"

MISSING_PBX="$WORKDIR/missing.pbxproj"
assert_rejects "a missing Xcode project is rejected" "0.2.0" \
  "Xcode project not found" "$MISSING_PBX"

# Structural drift must fail loudly rather than silently vouching for nothing:
# if the guard can no longer find what it walks, it has stopped being a guard.
NO_LIST_PBX="$WORKDIR/no-list.pbxproj"
write_pbxproj "$NO_LIST_PBX"
grep -v 'Build configuration list for PBXProject' "$WORKDIR/no-list.pbxproj" > "$NO_LIST_PBX.tmp"
mv "$NO_LIST_PBX.tmp" "$NO_LIST_PBX"
assert_rejects "an unrecognisable project structure is rejected" "0.2.0" \
  "could not locate the PBXProject build configuration list" "$NO_LIST_PBX"

NO_SETTING_PBX="$WORKDIR/no-setting.pbxproj"
write_pbxproj "$NO_SETTING_PBX"
grep -v 'BASE_BUNDLE_ID' "$WORKDIR/no-setting.pbxproj" > "$NO_SETTING_PBX.tmp"
mv "$NO_SETTING_PBX.tmp" "$NO_SETTING_PBX"
assert_rejects "a Release config missing BASE_BUNDLE_ID is rejected" "0.2.0" \
  "BASE_BUNDLE_ID is not set" "$NO_SETTING_PBX"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
