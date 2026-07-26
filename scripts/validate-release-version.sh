#!/usr/bin/env bash
# Validates a release version against the current MARKETING_VERSION and
# existing branches/tags. Prints the validated version to stdout on success;
# prints a reason to stderr and exits non-zero on any failure.
set -euo pipefail

usage() {
  echo "Usage: $0 <version> [project_yml_path] [pbxproj_path]" >&2
  exit 2
}

VERSION="${1:-}"
PROJECT_YML="${2:-BeachTennisCounter/project.yml}"
PBXPROJ="${3:-$(dirname "$PROJECT_YML")/BeachTennisCounter.xcodeproj/project.pbxproj}"
REMOTE="${RELEASE_VALIDATE_REMOTE:-origin}"

# The one bundle id that may ever be released. The `Dev` flavor builds
# `com.renan.beachtennis.dev`; shipping that to the App Store would be a
# different app entirely.
readonly RELEASE_BUNDLE_ID="com.renan.beachtennis"

[[ -n "$VERSION" ]] || usage

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: '$VERSION' is not a valid semver version (expected x.y.z)" >&2
  exit 1
fi

if [[ ! -f "$PROJECT_YML" ]]; then
  echo "error: project file not found at $PROJECT_YML" >&2
  exit 1
fi

CURRENT_VERSION="$(grep -E '^\s*MARKETING_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/^[^"]*"([^"]*)".*/\1/')"

if [[ -z "$CURRENT_VERSION" ]]; then
  echo "error: could not read MARKETING_VERSION from $PROJECT_YML" >&2
  exit 1
fi

IFS='.' read -r cur_major cur_minor cur_patch <<< "$CURRENT_VERSION"
IFS='.' read -r new_major new_minor new_patch <<< "$VERSION"

is_greater=false
if (( new_major > cur_major )); then
  is_greater=true
elif (( new_major == cur_major && new_minor > cur_minor )); then
  is_greater=true
elif (( new_major == cur_major && new_minor == cur_minor && new_patch > cur_patch )); then
  is_greater=true
fi

if [[ "$is_greater" != true ]]; then
  echo "error: '$VERSION' is not greater than current MARKETING_VERSION '$CURRENT_VERSION'" >&2
  exit 1
fi

# --- Release bundle id -------------------------------------------------------
#
# Guards against releasing a flavored build. This inspects `project.pbxproj`,
# not `project.yml`, deliberately: the checked-in Xcode project is what Xcode
# archives, so it is what the shipped artifact's bundle id actually comes from.
# `project.yml` only reaches a build by way of `xcodegen generate`, which
# rewrites the pbxproj — so a project.yml edit that has not been regenerated
# cannot affect the artifact, and one that has been regenerated is visible here.
# Checking project.yml instead would restate an intention; this resolves what
# will be built.
#
# There is no archive and no `xcodebuild -showBuildSettings` available at this
# point — release-cut runs on ubuntu with no Xcode — so resolving the setting
# out of the project file is as close to the artifact as this stage can get.

if [[ ! -f "$PBXPROJ" ]]; then
  echo "error: Xcode project not found at $PBXPROJ" >&2
  exit 1
fi

# Reads one build setting out of a specific XCBuildConfiguration block.
# Values are emitted quoted or bare depending on content, so strip both.
pbxproj_setting() {
  local config_uuid="$1" setting="$2"
  awk -v uuid="$config_uuid" -v key="$setting" '
    $0 ~ "^\t\t" uuid " /\\*" { inblock = 1; next }
    inblock && /^\t\t};/      { exit }
    inblock && $1 == key && $2 == "=" {
      value = $0
      sub(/^[^=]*= */, "", value)
      sub(/;[[:space:]]*$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$PBXPROJ"
}

# `|| true` so a no-match grep under `set -e -o pipefail` reaches the explicit
# check below instead of killing the script with no diagnostic.
PROJECT_CONFIG_LIST="$(grep -oE 'buildConfigurationList = [0-9A-F]+ /\* Build configuration list for PBXProject' "$PBXPROJ" | head -1 | awk '{print $3}' || true)"

if [[ -z "$PROJECT_CONFIG_LIST" ]]; then
  echo "error: could not locate the PBXProject build configuration list in $PBXPROJ; the project structure changed and this guard needs updating" >&2
  exit 1
fi

RELEASE_CONFIG_UUID="$(awk -v uuid="$PROJECT_CONFIG_LIST" '
  $0 ~ "^\t\t" uuid " /\\*" { inblock = 1; next }
  inblock && /^\t\t};/       { exit }
  inblock && /\/\* Release \*\/,/ { print $1; exit }
' "$PBXPROJ")"

if [[ -z "$RELEASE_CONFIG_UUID" ]]; then
  echo "error: no project-level Release build configuration found in $PBXPROJ" >&2
  exit 1
fi

BASE_BUNDLE_ID="$(pbxproj_setting "$RELEASE_CONFIG_UUID" BASE_BUNDLE_ID)"
BUNDLE_ID_SUFFIX="$(pbxproj_setting "$RELEASE_CONFIG_UUID" BUNDLE_ID_SUFFIX)"

if [[ -z "$BASE_BUNDLE_ID" ]]; then
  echo "error: BASE_BUNDLE_ID is not set in the Release configuration of $PBXPROJ; the flavoring settings moved and this guard needs updating" >&2
  exit 1
fi

RESOLVED_BUNDLE_ID="${BASE_BUNDLE_ID}${BUNDLE_ID_SUFFIX}"

if [[ "$RESOLVED_BUNDLE_ID" != "$RELEASE_BUNDLE_ID" ]]; then
  echo "error: Release configuration builds bundle id '$RESOLVED_BUNDLE_ID', expected '$RELEASE_BUNDLE_ID' — refusing to cut a release from a flavored build" >&2
  exit 1
fi

# The composition above only holds if the app targets still derive their id from
# those two settings. A target that hardcodes its own id would sail past the
# check. `com.renan.beachtennis.tests` is the unit-test bundle, which never ships.
UNEXPECTED_IDS="$(grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;' "$PBXPROJ" \
  | sed -E 's/PRODUCT_BUNDLE_IDENTIFIER = //; s/;$//; s/^"|"$//g' \
  | sort -u \
  | grep -vE '^\$\(BASE_BUNDLE_ID\)\$\(BUNDLE_ID_SUFFIX\)' \
  | grep -vxF "$RELEASE_BUNDLE_ID.tests" || true)"

if [[ -n "$UNEXPECTED_IDS" ]]; then
  echo "error: these targets do not derive their bundle id from BASE_BUNDLE_ID/BUNDLE_ID_SUFFIX, so the Release check above cannot vouch for them:" >&2
  echo "$UNEXPECTED_IDS" | sed 's/^/  /' >&2
  exit 1
fi

if git ls-remote --exit-code --heads "$REMOTE" "refs/heads/release/$VERSION" >/dev/null 2>&1; then
  echo "error: branch 'release/$VERSION' already exists on remote '$REMOTE'" >&2
  exit 1
fi

if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/$VERSION" >/dev/null 2>&1; then
  echo "error: tag '$VERSION' already exists on remote '$REMOTE'" >&2
  exit 1
fi

echo "$VERSION"
