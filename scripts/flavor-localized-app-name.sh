#!/bin/bash
#
# Give the flavored build its flavored name in every locale.
#
# `APP_DISPLAY_NAME` reaches `CFBundleDisplayName` in Info.plist, but a
# localized `InfoPlist.strings` outranks Info.plist on the home screen, and
# `.strings` files receive no build-setting expansion — `CopyStringsFile`
# copies them verbatim. So a project with a pt-BR `CFBundleDisplayName` shows
# the *same* name for every flavor, and only the icon tells them apart. That
# was shipped to a device before anyone noticed (#158).
#
# Rewriting the built copy keeps one source of truth for the name — the
# `APP_DISPLAY_NAME` build setting — and needs no edit when a locale is added.
# Every other translation in the file is left alone, so the dev build still
# exercises the localized HealthKit permission prompts.
#
# Runs as a post-build phase on both app targets; a no-op unless the
# configuration actually flavors the name.
set -euo pipefail

# Debug and Release are the production name, which the .strings files already
# spell correctly in each locale. Only a flavored build needs the override.
if [ "${CONFIGURATION}" != "Dev" ]; then
	exit 0
fi

resources="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

shopt -s nullglob
found=0
for strings in "${resources}"/*.lproj/InfoPlist.strings; do
	# A locale that never overrode the name has nothing to outrank Info.plist,
	# so leave it be rather than inventing a key.
	if plutil -extract CFBundleDisplayName raw "${strings}" >/dev/null 2>&1; then
		plutil -replace CFBundleDisplayName -string "${APP_DISPLAY_NAME}" "${strings}"
		found=1
	fi
done

# Silence is the failure mode this script exists to prevent: if the glob stops
# matching — a renamed resources dir, a phase that runs too early — the build
# would go on quietly shipping the production name under a dev icon.
if [ "${found}" -eq 0 ]; then
	echo "error: no localized InfoPlist.strings found under ${resources}; the Dev build would ship the production app name" >&2
	exit 1
fi
