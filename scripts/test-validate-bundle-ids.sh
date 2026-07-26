#!/usr/bin/env bash
# Plain-bash test suite for validate-bundle-ids.sh.
# Exercises external behavior only: exit code + stderr message per case.
#
# Each case writes a minimal project.yml into a scratch directory and runs
# `xcodegen generate` over it, so the validator is pointed at a real generated
# .xcodeproj rather than a hand-faked one — the same expansion machinery it
# reads in anger. Fixtures declare no sources; nothing here is ever compiled.
#
# Requires xcodegen and xcodebuild. Not wired into CI: CI runs the validator
# against the real project, developers run this against the validator.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/validate-bundle-ids.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required to build the fixtures" >&2
  exit 2
fi

pass=0
fail=0

# Generates a fixture project from the project.yml passed on stdin and echoes
# the path to the resulting .xcodeproj.
fixture() {
  local name="$1"
  local dir="$WORKDIR/$name"
  mkdir -p "$dir"
  cat > "$dir/project.yml"
  (cd "$dir" && xcodegen generate --quiet) >/dev/null 2>&1
  echo "$dir/Fixture.xcodeproj"
}

assert_accepts() {
  local desc="$1" project="$2"
  local out status
  out="$("$VALIDATE" "$project" 2>&1)"
  status=$?
  if [[ $status -eq 0 ]]; then
    echo "ok   - $desc"
    pass=$((pass + 1))
  else
    echo "FAIL - $desc (exit=$status output=$out)"
    fail=$((fail + 1))
  fi
}

# Rejects with a message matching $3, so a case cannot pass by failing for an
# unrelated reason.
assert_rejects() {
  local desc="$1" project="$2" pattern="$3"
  local out status
  out="$("$VALIDATE" "$project" 2>&1)"
  status=$?
  if [[ $status -ne 0 && "$out" == *"$pattern"* ]]; then
    echo "ok   - $desc"
    pass=$((pass + 1))
  else
    echo "FAIL - $desc (exit=$status output=$out)"
    fail=$((fail + 1))
  fi
}

# --- A correct project is accepted ------------------------------------------

correct="$(fixture correct <<'EOF'
name: Fixture
options:
  bundleIdPrefix: com.renan.beachtennis
  defaultConfig: Debug
configs:
  Debug: debug
  Dev: debug
  Release: release
settings:
  base:
    BASE_BUNDLE_ID: com.renan.beachtennis
    BUNDLE_ID_SUFFIX: ""
  configs:
    Dev:
      BUNDLE_ID_SUFFIX: .dev
targets:
  BeachTennisCounter:
    type: application
    platform: iOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)
  BeachTennisCounterWatch:
    type: application
    platform: watchOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX).watchkitapp
EOF
)"
assert_accepts "accepts a correctly flavored project" "$correct"

# --- A wrong Dev suffix is caught -------------------------------------------

wrong_dev="$(fixture wrong-dev <<'EOF'
name: Fixture
options:
  bundleIdPrefix: com.renan.beachtennis
  defaultConfig: Debug
configs:
  Debug: debug
  Dev: debug
  Release: release
settings:
  base:
    BASE_BUNDLE_ID: com.renan.beachtennis
    BUNDLE_ID_SUFFIX: ""
  configs:
    Dev:
      BUNDLE_ID_SUFFIX: .development
targets:
  BeachTennisCounter:
    type: application
    platform: iOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)
  BeachTennisCounterWatch:
    type: application
    platform: watchOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX).watchkitapp
EOF
)"
assert_rejects "rejects a Dev bundle id that is not .dev" "$wrong_dev" \
  "BeachTennisCounter/Dev bundle id is 'com.renan.beachtennis.development'"

# --- The Dev suffix leaking into Debug and Release is caught ----------------
# This is the contamination case: a suffix set on `base` rather than under the
# `Dev` config points every configuration, including Release, at the dev id.

leaked="$(fixture leaked-suffix <<'EOF'
name: Fixture
options:
  bundleIdPrefix: com.renan.beachtennis
  defaultConfig: Debug
configs:
  Debug: debug
  Dev: debug
  Release: release
settings:
  base:
    BASE_BUNDLE_ID: com.renan.beachtennis
    BUNDLE_ID_SUFFIX: .dev
targets:
  BeachTennisCounter:
    type: application
    platform: iOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)
  BeachTennisCounterWatch:
    type: application
    platform: watchOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX).watchkitapp
EOF
)"
assert_rejects "rejects the Dev suffix leaking into Release" "$leaked" \
  "BeachTennisCounter/Release bundle id is 'com.renan.beachtennis.dev'"

# --- A broken BASE + SUFFIX relation is caught ------------------------------
# Every literal id here is correct, so the golden table alone would pass. Only
# the relational check notices that PRODUCT_BUNDLE_IDENTIFIER is no longer
# built from BASE_BUNDLE_ID — which is what makes the entitlement's
# `group.$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)` and the Info.plist's
# `group.$(PRODUCT_BUNDLE_IDENTIFIER)` resolve to different groups.

broken_relation="$(fixture broken-relation <<'EOF'
name: Fixture
options:
  bundleIdPrefix: com.renan.beachtennis
  defaultConfig: Debug
configs:
  Debug: debug
  Dev: debug
  Release: release
settings:
  base:
    BASE_BUNDLE_ID: com.renan.somethingelse
    BUNDLE_ID_SUFFIX: ""
  configs:
    Dev:
      BUNDLE_ID_SUFFIX: .dev
targets:
  BeachTennisCounter:
    type: application
    platform: iOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.renan.beachtennis
      configs:
        Dev:
          PRODUCT_BUNDLE_IDENTIFIER: com.renan.beachtennis.dev
  BeachTennisCounterWatch:
    type: application
    platform: watchOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.renan.beachtennis.watchkitapp
      configs:
        Dev:
          PRODUCT_BUNDLE_IDENTIFIER: com.renan.beachtennis.dev.watchkitapp
EOF
)"
assert_rejects "rejects a bundle id no longer built from BASE_BUNDLE_ID" \
  "$broken_relation" "is not BASE_BUNDLE_ID + BUNDLE_ID_SUFFIX"

# --- A renamed target fails loudly rather than passing silently -------------
# The guard against the worst failure mode for an assertion script: checking
# nothing and reporting success.

renamed="$(fixture renamed-target <<'EOF'
name: Fixture
options:
  bundleIdPrefix: com.renan.beachtennis
  defaultConfig: Debug
configs:
  Debug: debug
  Dev: debug
  Release: release
settings:
  base:
    BASE_BUNDLE_ID: com.renan.beachtennis
    BUNDLE_ID_SUFFIX: ""
  configs:
    Dev:
      BUNDLE_ID_SUFFIX: .dev
targets:
  BeachTennisApp:
    type: application
    platform: iOS
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)
EOF
)"
assert_rejects "fails loudly when a target no longer exists" "$renamed" \
  "resolved no PRODUCT_BUNDLE_IDENTIFIER at all"

# --- A missing project is an error, not a pass ------------------------------

assert_rejects "rejects a project path that does not exist" \
  "$WORKDIR/nope.xcodeproj" "Xcode project not found"

# An explicitly empty argument must not fall through to the default path and
# validate the real project — that would report success for a project the
# caller never asked about.
assert_rejects "rejects an empty project path instead of defaulting" \
  "" "empty project path"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
