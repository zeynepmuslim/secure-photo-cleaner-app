#!/bin/bash
# Fails the build when Swift sources use an API that CLAUDE.md forbids (see "Forbidden APIs").
# Runs as the "Forbidden API check" build phase of the Purgio target, before Sources.
# Usage: Scripts/forbidden-api-check.sh   (from anywhere; paths resolve from the repo root)

set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

# pattern|message
RULES=(
  'UIScreen\.main|UIScreen.main is forbidden: use view.window?.bounds, view.bounds or traitCollection.displayScale.'
  '\.keyWindow\b|keyWindow is forbidden: use view.window (or self.window in a view).'
  'isKeyWindow|Key-window lookups are forbidden: use view.window (or self.window in a view).'
  'UIApplication\.shared\.windows|UIApplication.shared.windows is forbidden: use view.window.'
  'UIApplication\.shared\.connectedScenes|Walking connectedScenes for a window is forbidden: use view.window / view.window?.windowScene.'
  'UIGraphicsBeginImageContext|UIGraphicsBeginImageContext is forbidden: use UIGraphicsImageRenderer.'
  'PHPickerViewController|PHPickerViewController does not expand limited access: use PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:).'
  'String\(localized:|String(localized:) is forbidden: use NSLocalizedString("<screen>.<key>", comment:) with a key in Localization/translations.csv.'
  'userInterfaceIdiom|userInterfaceIdiom is forbidden: branch on traitCollection size classes or view bounds instead.'
  '\binterfaceOrientation\b|interfaceOrientation is forbidden: use view bounds / windowScene.effectiveGeometry.'
)

SOURCES=$(find Purgio StorageAnalysisWidget -name '*.swift' -type f)
violations=0

for rule in "${RULES[@]}"; do
  pattern="${rule%%|*}"
  message="${rule#*|}"
  # -n line numbers, -H file names, -E extended regex; drop comment-only lines.
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    file="${hit%%:*}"; rest="${hit#*:}"; line="${rest%%:*}"; code="${rest#*:}"
    if [[ "$code" =~ ^[[:space:]]*// ]]; then continue; fi
    echo "$ROOT/$file:$line: error: $message"
    violations=$((violations + 1))
  done < <(grep -nHE "$pattern" $SOURCES || true)
done

# UIRequiresFullScreen letterboxes the app on the iPhone Duo's inner display.
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  file="${hit%%:*}"; rest="${hit#*:}"; line="${rest%%:*}"
  echo "$ROOT/$file:$line: error: UIRequiresFullScreen is forbidden: it letterboxes the app on the iPhone Duo. Screens must lay out at any size."
  violations=$((violations + 1))
done < <(grep -rnH 'UIRequiresFullScreen' Purgio.xcodeproj/project.pbxproj Purgio/Application/Info.plist StorageAnalysisWidget/Info.plist 2>/dev/null || true)

if [ "$violations" -gt 0 ]; then
  echo "error: $violations forbidden API use(s) found. See CLAUDE.md → Forbidden APIs."
  exit 1
fi
echo "Forbidden API check passed."
