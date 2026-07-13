#!/usr/bin/env bash
# Validates a release version against the current MARKETING_VERSION and
# existing branches/tags. Prints the validated version to stdout on success;
# prints a reason to stderr and exits non-zero on any failure.
set -euo pipefail

usage() {
  echo "Usage: $0 <version> [project_yml_path]" >&2
  exit 2
}

VERSION="${1:-}"
PROJECT_YML="${2:-BeachTennisCounter/project.yml}"
REMOTE="${RELEASE_VALIDATE_REMOTE:-origin}"

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

if git ls-remote --exit-code --heads "$REMOTE" "refs/heads/release/$VERSION" >/dev/null 2>&1; then
  echo "error: branch 'release/$VERSION' already exists on remote '$REMOTE'" >&2
  exit 1
fi

if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/$VERSION" >/dev/null 2>&1; then
  echo "error: tag '$VERSION' already exists on remote '$REMOTE'" >&2
  exit 1
fi

echo "$VERSION"
