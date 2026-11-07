#!/bin/bash
# Fails the build when an NSLocalizedString key is badly formed or missing from Localization/translations.csv.
# Runs as the "Localization check" build phase of the Purgio target, before Sources.
# Usage: Scripts/localization-check.sh   (from anywhere; paths resolve from the repo root)

set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

CSV="Localization/translations.csv"

# Keys used only by #Preview code that has no CSV row yet. Previews show the raw key; that's fine.
# Remove a key from here once it gets a CSV row. Never allowlist a key shown in the shipping UI.
ALLOWLIST=(
  filterCards.delete           # MonthStatItemView previews
  monthReview.noResultsMessage # EmptyStateView previews
  monthReview.noResultsTitle   # EmptyStateView previews
  similarPhotos.gotIt          # DynamicGlassButton previews
)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# file:line:key for every literal key, including calls split over several lines.
find Purgio StorageAnalysisWidget -name '*.swift' -type f -print0 \
  | xargs -0 perl -0777 -ne '
      while (/NSLocalizedString\(\s*"((?:[^"\\]|\\.)*)"/g) {
        my $key = $1; my $pos = $-[0];
        my $line = (substr($_, 0, $pos) =~ tr/\n//) + 1;
        print "$ARGV:$line:$key\n";
      }' > "$TMP/uses.txt"

tail -n +2 "$CSV" | cut -d';' -f1 | sed '/^$/d' | sort -u > "$TMP/csv.txt"
printf '%s\n' "${ALLOWLIST[@]}" | sort -u > "$TMP/allow.txt"

errors=0
while IFS= read -r use; do
  file="${use%%:*}"; rest="${use#*:}"; line="${rest%%:*}"; key="${rest#*:}"
  # Interpolated keys can't be checked statically.
  if [[ "$key" == *'\('* ]]; then continue; fi
  if ! [[ "$key" =~ ^[a-zA-Z]+(\.[a-zA-Z0-9]+)+$ ]]; then
    echo "$ROOT/$file:$line: error: Localization key \"$key\" isn't a dotted route (<screen>.<camelCaseKey>)."
    errors=$((errors + 1)); continue
  fi
  if ! grep -qxF "$key" "$TMP/csv.txt" && ! grep -qxF "$key" "$TMP/allow.txt"; then
    echo "$ROOT/$file:$line: error: Localization key \"$key\" is missing from $CSV. Add a row with en and tr values."
    errors=$((errors + 1))
  fi
done < "$TMP/uses.txt"

if [ "$errors" -gt 0 ]; then
  echo "error: $errors localization problem(s). See CLAUDE.md → Localization."
  exit 1
fi
echo "Localization check passed ($(cut -d: -f3- "$TMP/uses.txt" | sort -u | wc -l | tr -d ' ') keys)."
