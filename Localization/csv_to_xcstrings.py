#!/usr/bin/env python3
"""
Convert translations.csv to Localizable.xcstrings (Xcode String Catalog format).

Usage:
    python3 csv_to_xcstrings.py [--csv translations.csv] [--output Localizable.xcstrings]
"""

import argparse
import csv
import json
import os
import sys


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert translations CSV to Xcode .xcstrings JSON format."
    )
    parser.add_argument(
        "--csv",
        default="translations.csv",
        help="Path to the input CSV file (default: translations.csv)",
    )
    parser.add_argument(
        "--output",
        default="Localizable.xcstrings",
        help="Path to the output .xcstrings file (default: Localizable.xcstrings)",
    )
    return parser.parse_args()


PLURAL_CATEGORIES = ("zero", "one", "two", "few", "many", "other")


def detect_languages(headers):
    """Auto-detect language codes from CSV headers.

    Bare columns (not DEV_KEY) are static language columns.
    Columns like {lang}_{category} where category is a CLDR plural form
    also contribute their language code.
    """
    languages = set()
    for header in headers:
        if header == "DEV_KEY":
            continue
        # Check if this is a plural column like "en_one", "ar_few", etc.
        parts = header.rsplit("_", 1)
        if len(parts) == 2 and parts[1] in PLURAL_CATEGORIES:
            languages.add(parts[0])
        else:
            languages.add(header)
    return sorted(languages)


def build_string_unit(state, value):
    return {"stringUnit": {"state": state, "value": value}}


def build_plural_variation(category_values):
    """Build plural variation from a dict of {category: value}."""
    variation = {"plural": {}}
    for category in PLURAL_CATEGORIES:
        value = category_values.get(category)
        if value:
            variation["plural"][category] = build_string_unit("translated", value)
    return {"variations": variation}


def is_plural(row, languages):
    """Detect plural keys by checking if any language has non-empty _one or _other columns."""
    for lang in languages:
        if bool(row.get(f"{lang}_one", "").strip()) or bool(
            row.get(f"{lang}_other", "").strip()
        ):
            return True
    return False


def process_csv(csv_path):
    strings = {}

    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter=";")
        languages = detect_languages(reader.fieldnames)

        for row in reader:
            key = row.get("DEV_KEY", "").strip()
            if not key:
                continue

            entry = {"extractionState": "manual", "localizations": {}}

            if is_plural(row, languages):
                for lang in languages:
                    category_values = {}
                    for category in PLURAL_CATEGORIES:
                        val = row.get(f"{lang}_{category}", "").strip()
                        if val:
                            category_values[category] = val
                    if category_values:
                        entry["localizations"][lang] = build_plural_variation(
                            category_values
                        )
            else:
                for lang in languages:
                    value = row.get(lang, "").strip()
                    if value:
                        entry["localizations"][lang] = build_string_unit(
                            "translated", value
                        )

            strings[key] = entry

    return strings


def main():
    args = parse_args()

    csv_path = args.csv
    output_path = args.output

    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found: {csv_path}", file=sys.stderr)
        sys.exit(1)

    strings = process_csv(csv_path)

    # Sort keys alphabetically
    sorted_strings = dict(sorted(strings.items()))

    xcstrings = {
        "sourceLanguage": "en",
        "strings": sorted_strings,
        "version": "1.1",
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(xcstrings, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Generated {output_path} with {len(sorted_strings)} keys.")


if __name__ == "__main__":
    main()
