# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Purgio is a native iOS photo-cleanup app (UIKit-first, Swift 5 language mode) that works fully offline: no networking layer, no third-party SDKs, no analytics. The user swipes through their library month by month. Swipe left marks for deletion, right keeps, and up puts the item in a "Will Be Stored" album. There are no Swift packages or dependencies.

## Build

- Xcode project `Purgio.xcodeproj`, schemes `Purgio` (app) and `StorageAnalysisWidgetExtension`. There is **no test target** and no linter config.
- `xcode-select` may point at CommandLineTools. If so, set `DEVELOPER_DIR` to the installed Xcode:
  ```sh
  DEVELOPER_DIR=/Applications/<Xcode>.app/Contents/Developer \
    xcodebuild -project Purgio.xcodeproj -scheme Purgio \
    -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
  ```
- The project uses **file-system synchronized groups** (objectVersion 77). New `.swift` files under `Purgio/` or `StorageAnalysisWidget/` join their target automatically, so the pbxproj doesn't need editing for sources.
- Deployment targets: app **iOS 15.0**, widget extension iOS 18.0. Supporting old devices is a deliberate product goal. Guard newer APIs with `#available`: iOS 16.2 for Live Activities, iOS 26 for the Liquid Glass UI (top gradients, glass buttons, tab bar layout).

## Localization

- The source of truth is `Localization/translations.csv` (semicolon-delimited, `DEV_KEY;en;tr;en_one;en_other;...`). **Never edit `Localizable.xcstrings` by hand.** The "Generate Localizable.xcstrings" build phase runs `Localization/csv_to_xcstrings.py` and overwrites the root `Localizable.xcstrings`. To regenerate it manually:
  `python3 Localization/csv_to_xcstrings.py --csv Localization/translations.csv --output Localizable.xcstrings`
- That script phase runs *after* the Resources phase, so a CSV edit may only show up on the next build.
- Each file declares a `private enum Strings` with `NSLocalizedString("<screen>.<key>", comment:)`. Shared strings live in `CommonStrings` (`Purgio/Others/Constants.swift`). Plurals use `{lang}_one`/`{lang}_other` columns. Details are in `Docs/Developer-Localization-Guide.md`.

## Architecture

**Navigation.** `SceneDelegate` builds the UI in code. The storyboards are only launch and legacy. `MainTabBarController` has four tabs: Home (`HomeViewController`), Photos and Videos (the same `MonthsListViewController(mediaType:)` with `.image` and `.video`), and Settings. `MainTabBarController` owns one global `FloatingBinButton`. Screens drive it through the `FloatingBinButtonController` protocol (`tabBarController as? FloatingBinButtonController`) and never own a bin button themselves.

**Review flow.** MonthsList → `MonthFilterCardsViewController` (per-month filters) → either `MonthReviewViewController` (the swipe deck), `SimilarPhotosViewController`, or `ProcessingLoadingViewController`. `ProcessingLoadingViewController` runs the slow filters (large files, eyes closed) and then pushes `MonthReviewViewController` with pre-computed assets. `MonthReviewViewController` is split across `+DataLoading`, `+Swipe`, `+UI`, `+Video`, `+Helpers` and `+UndoHistory` extensions. It runs in filter mode when `preSortedAssets`/`preComputedAssets` are set.

**Month keys** are `"yyyy-MM"` strings from `DateFormatterManager.monthKey(from:)`. Progress is stored per media type under keys like `photo_2024-01` or `video_2024-01`.

**Services** (`Purgio/Services`):
- `PhotoLibraryService.shared` wraps PhotoKit. It handles authorization, fetches by month, builds month buckets with a 5-minute cache (`invalidateMonthBucketsCache()`), and manages the "Will Be Stored" album. It registers as `PHPhotoLibraryChangeObserver` only after access is granted and re-broadcasts `.photoLibraryDidChange`.
- `PhotoSimilarityService` (Vision feature prints, grouped within 2-minute time windows), plus the `EyeBlinkDetector` and `PhotoProcessor` actors (Core Image `CIDetector`).
- `ImageCacheService` wraps `PHCachingImageManager`. iCloud downloads are opt-in: `isNetworkAccessAllowed` follows `SettingsStore.shared.allowInternetAccess`, with an offline fallback.

**Stores** (`Purgio/Stores`, plus `UndoHistoryManager`) are `.shared` singletons. Each keeps an in-memory cache and persists JSON to `Documents/Purgio/*.json` on a private serial queue. Only `SettingsStore` and `OnboardingStore` use `UserDefaults`. `DeleteBinStore` is **main-thread only** (it asserts). It holds asset `localIdentifier`s, and assets are actually deleted only from `DeleteBinViewController` via `PHAssetChangeRequest.deleteAssets`.

**Cross-screen updates** go through `NotificationCenter`. Names are declared as `Notification.Name` extensions next to their owner: `.deleteBinCountDidChange`, `.photoLibraryDidChange`, `.undoHistoryDidChange`, `.storageAnalysis*`, `.filterByYear`, and others.

**Storage analysis.** `StorageAnalysisManager` (split into `+ChunkedAnalysis`, `+BackgroundTasks`, `+AppLifecycle` and `+LiveActivity`) scans the library in chunks of 500. It resumes through a `BGProcessingTask` (`com.purgio.storageAnalysis`, registered in `AppDelegate` and listed in Info.plist) and shows a Live Activity rendered by the `StorageAnalysisWidget` extension. `StorageAnalysisAttributes.swift` exists as **two identical copies**, in `Purgio/Models/` and `StorageAnalysisWidget/`. Keep them in sync.

**Other.** The tip jar uses StoreKit 2 (`TipJarManager`, local config `Purgio/Services/TipProducts.storekit`). Reminder notifications are handled by `ReminderNotificationService` and `ReminderDataCenter`. DEBUG builds have a shake-to-open dev menu in `MainTabBarController` for testing notifications. Logging is plain `print("[TypeName] ...")`.

## PhotoKit gotchas

- **Limited access:** use `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:completionHandler:)` to let the user add photos. `PHPickerViewController` only returns copies and does **not** expand the app's accessible asset set. After the picker closes, invalidate the month-bucket cache before reloading, or the cached empty result comes back.
- `presentLimitedLibraryPicker` is a PhotosUI Objective-C category method on `PHPhotoLibrary`. `import PhotosUI` alone doesn't link the framework when no PhotosUI symbol is referenced, and the call then crashes with "unrecognized selector". That is why `PhotosUI.framework` is linked explicitly in the app target. Don't remove it.
