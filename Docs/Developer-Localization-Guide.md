# Fixing Translations

Want to fix a translation in your language? You only need to edit one file.

## How It Works

All translations live in a single CSV file:

```
Localization/translations.csv
```

When you build the project in Xcode, a build script automatically converts this CSV into `Localizable.xcstrings` — no manual steps needed.

## Steps

1. Open `Localization/translations.csv`
2. Find the key you want to fix (use the `DEV_KEY` column)
3. Edit the value in your language's column (`en`, `tr`, etc.)
4. Open a pull request

That's it. Xcode handles the rest on build.

## CSV Format

The file uses **semicolons (`;`)** as delimiters:

```
DEV_KEY;en;tr;en_one;en_other;tr_one;tr_other
common.cancel;Cancel;İptal;;;;
```

- `en`, `tr` : static translations
- `en_one`, `en_other`, `tr_one`, `tr_other` : plural forms (leave static columns empty for these)

## Rules

- Don't change the `DEV_KEY` column
- Keep the same number of `%@`, `%d`, `%lld` format specifiers as the English version
- If variable order differs in your language, use positional specifiers (`%1$@`, `%2$d`):
  ```
  EN: "You reviewed all %1$d photos in %2$@."
  TR: "%2$@'da tüm %1$d fotoğrafı incelediniz."
  ```
  `%1$d` = first argument (number), `%2$@` = second argument (text). The number after `%` sets which argument to use, so the order in the sentence can change freely.
- For plural rows, `en`/`tr` columns stay empty — only fill the `_one`/`_other` columns
