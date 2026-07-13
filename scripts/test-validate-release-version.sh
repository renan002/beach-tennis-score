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
  local desc="$1" version="$2"
  local out status
  out="$("$VALIDATE" "$version" "$PROJECT_YML" 2>&1)"
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
  local desc="$1" version="$2" expected_pattern="$3"
  local out status
  out="$("$VALIDATE" "$version" "$PROJECT_YML" 2>&1)"
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

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
