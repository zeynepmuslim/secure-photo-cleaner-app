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


def build_string_unit(state, value):
    return {"stringUnit": {"state": state, "value": value}}


def build_plural_variation(one_value, other_value):
    variation = {"plural": {}}
    if one_value:
        variation["plural"]["one"] = build_string_unit("translated", one_value)
    if other_value:
        variation["plural"]["other"] = build_string_unit("translated", other_value)
    return {"variations": variation}


def is_plural(row):
    """Detect plural keys by checking if en_one or en_other columns are non-empty."""
    return bool(row.get("en_one", "").strip()) or bool(row.get("en_other", "").strip())


def process_csv(csv_path):
    strings = {}

    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter=";")
        for row in reader:
            key = row.get("DEV_KEY", "").strip()
            if not key:
                continue

            entry = {"extractionState": "manual", "localizations": {}}

            if is_plural(row):
                # Plural string
                en_one = row.get("en_one", "").strip()
                en_other = row.get("en_other", "").strip()
                tr_one = row.get("tr_one", "").strip()
                tr_other = row.get("tr_other", "").strip()

                if en_one or en_other:
                    entry["localizations"]["en"] = build_plural_variation(
                        en_one, en_other
                    )
                if tr_one or tr_other:
                    entry["localizations"]["tr"] = build_plural_variation(
                        tr_one, tr_other
                    )
            else:
                # Static string
                en_value = row.get("en", "").strip()
                tr_value = row.get("tr", "").strip()

                if en_value:
                    entry["localizations"]["en"] = build_string_unit(
                        "translated", en_value
                    )
                if tr_value:
                    entry["localizations"]["tr"] = build_string_unit(
                        "translated", tr_value
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
