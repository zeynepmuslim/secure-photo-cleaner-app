# Developer Localization Guide

All translations live in a single CSV file:

```
Localization/translations.csv
```

When you build the project in Xcode, a build script automatically converts this CSV into `Localizable.xcstrings` — no manual steps needed.

---

## Fixing a Translation

1. Open `Localization/translations.csv`
2. Find the key you want to fix (use the `DEV_KEY` column)
3. Edit the value in your language's column (`en`, `tr`, etc.)
4. Open a pull request

That's it. Xcode handles the rest on build.

---

## Adding a New Language

### 1. Register the language in Xcode

Open the project in Xcode, go to **Project → Info → Localizations**, click **"+"**, and select the language you want to add (e.g. Arabic). This adds the language code to `knownRegions` in the project file.

### 2. Add columns to the CSV

Add a static column for the new language, and plural columns if needed:

```
DEV_KEY;en;tr;ar;en_one;en_other;tr_one;tr_other;ar_one;ar_other
common.cancel;Cancel;İptal;إلغاء;;;;;;
```

Languages are **auto-detected** from the CSV headers — no script changes needed.

For languages with complex plural rules (like Arabic), you can use all 6 CLDR categories:

```
DEV_KEY;...;ar_zero;ar_one;ar_two;ar_few;ar_many;ar_other
```

Supported categories: `zero`, `one`, `two`, `few`, `many`, `other`.

### 3. Test in Simulator

In Xcode: **Edit Scheme → Options → App Language** → select your new language, then run.

---

## CSV Format

The file uses **semicolons (`;`)** as delimiters.

```
DEV_KEY;en;tr;ar;en_one;en_other;tr_one;tr_other;ar_one;ar_other
common.cancel;Cancel;İptal;إلغاء;;;;;;
deleteBin.photoCount;;;;;%lld photo;%lld photos;%lld fotoğraf;%lld fotoğraf;%lld صورة;%lld صور
```

- Bare column names (`en`, `tr`, `ar`) → static translations
- `{lang}_{category}` columns → plural forms (leave static columns empty for plural rows)

---

## Rules

- Don't change the `DEV_KEY` column
- Keep the same number of `%@`, `%d`, `%lld` format specifiers as the English version
- If variable order differs in your language, use positional specifiers (`%1$@`, `%2$d`):
  ```
  EN: "You reviewed all %1$d photos in %2$@."
  TR: "%2$@'da tüm %1$d fotoğrafı incelediniz."
  ```
  `%1$d` = first argument (number), `%2$@` = second argument (text). The number after `%` sets which argument to use, so the order in the sentence can change freely.
- For plural rows, static language columns stay empty — only fill the `_{category}` columns
