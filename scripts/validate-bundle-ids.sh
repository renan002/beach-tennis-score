#!/usr/bin/env bash
# Asserts that every build configuration still resolves to the bundle id it is
# supposed to. The Dev flavor derives its ids by string interpolation in
# project.yml, so a single typo there can point a Release archive at a `.dev`
# id — or point the dev flavor at production's App Group. Neither shows up in
# the unit suite: the one configuration-sensitive test asserts the *relation*
# `appGroupIdentifier == "group.\(bundleIdentifier)"`, which holds happily even
# when the bundle id itself is wrong.
#
# Reads the generated .xcodeproj rather than project.yml, so it also catches a
# project.yml edit that was never followed by `xcodegen generate`.
#
# Prints a reason to stderr and exits non-zero on any mismatch.
set -uo pipefail

# `${1-...}` rather than `${1:-...}` on purpose: an explicitly empty argument is
# a caller bug, and must not fall through to validating the real project — a
# check that silently examines something other than what it was pointed at is
# the failure this script exists to prevent.
PROJECT="${1-BeachTennisCounter/BeachTennisCounter.xcodeproj}"

if [[ -z "$PROJECT" ]]; then
  echo "error: empty project path" >&2
  exit 1
fi

if [[ ! -d "$PROJECT" ]]; then
  echo "error: Xcode project not found at $PROJECT" >&2
  exit 1
fi

# The ids the dev-flavor effort fixed. Debug stays unflavored so the production
# bundle id remains debuggable; only Dev carries the suffix.
EXPECTED=(
  "BeachTennisCounter|Debug|com.renan.beachtennis"
  "BeachTennisCounter|Dev|com.renan.beachtennis.dev"
  "BeachTennisCounter|Release|com.renan.beachtennis"
  "BeachTennisCounterWatch|Debug|com.renan.beachtennis.watchkitapp"
  "BeachTennisCounterWatch|Dev|com.renan.beachtennis.dev.watchkitapp"
  "BeachTennisCounterWatch|Release|com.renan.beachtennis.watchkitapp"
)

failures=0

DUMPS="$(mktemp -d)"
trap 'rm -rf "$DUMPS"' EXIT

# Echoes the resolved value of $3 for target $1 / configuration $2, or nothing
# at all if the setting is absent. Callers must treat empty as a failure rather
# than a pass — a renamed setting must not read as agreement.
#
# One xcodebuild invocation per target/config, cached: the dump is the slow
# part and every setting this script reads comes out of the same one.
resolve() {
  local target="$1" config="$2" setting="$3"
  local dump="$DUMPS/$target-$config"

  if [[ ! -f "$dump" ]]; then
    xcodebuild -project "$PROJECT" -target "$target" -configuration "$config" \
      -showBuildSettings CODE_SIGNING_ALLOWED=NO >"$dump" 2>/dev/null
  fi

  sed -n "s/^[[:space:]]*${setting} = //p" "$dump" | head -1
}

for row in "${EXPECTED[@]}"; do
  IFS='|' read -r target config expected <<< "$row"
  actual="$(resolve "$target" "$config" PRODUCT_BUNDLE_IDENTIFIER)"

  if [[ -z "$actual" ]]; then
    echo "error: $target/$config resolved no PRODUCT_BUNDLE_IDENTIFIER at all" >&2
    failures=$((failures + 1))
  elif [[ "$actual" != "$expected" ]]; then
    echo "error: $target/$config bundle id is '$actual', expected '$expected'" >&2
    failures=$((failures + 1))
  fi
done

# The App Group is written twice as two different expressions — the entitlement
# says `group.$(BASE_BUNDLE_ID)$(BUNDLE_ID_SUFFIX)`, the Info.plist key says
# `group.$(PRODUCT_BUNDLE_IDENTIFIER)`. Both expand at build time, so no
# settings dump can read either one; asserting they are built from the same
# parts is what proves the app is entitled to the group it goes looking for.
for config in Debug Dev Release; do
  base="$(resolve BeachTennisCounter "$config" BASE_BUNDLE_ID)"
  product="$(resolve BeachTennisCounter "$config" PRODUCT_BUNDLE_IDENTIFIER)"
  # An empty suffix is correct for Debug and Release, so it cannot be checked
  # for emptiness the way the other two are.
  suffix="$(resolve BeachTennisCounter "$config" BUNDLE_ID_SUFFIX)"

  if [[ -z "$base" ]]; then
    echo "error: $config resolved no BASE_BUNDLE_ID at all" >&2
    failures=$((failures + 1))
    continue
  fi
  [[ -z "$product" ]] && continue # already reported above

  if [[ "$product" != "${base}${suffix}" ]]; then
    echo "error: $config bundle id '$product' is not BASE_BUNDLE_ID + BUNDLE_ID_SUFFIX ('${base}${suffix}') — the App Group entitlement and Info.plist key would disagree" >&2
    failures=$((failures + 1))
  fi
done

if (( failures > 0 )); then
  echo "error: $failures bundle id check(s) failed" >&2
  exit 1
fi

echo "All bundle ids resolve as expected."
