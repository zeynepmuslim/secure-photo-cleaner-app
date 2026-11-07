# Purgio iOS

Purgio is a native iOS photo-cleanup app built with UIKit. It's Swift 5 language mode and works fully offline.
- **No networking:** no HTTP layer, no third-party SDKs, no analytics, no telemetry. Photos never leave the device. Don't add any of these.
- **Platforms:** the app supports **iOS 15.0** and later, iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait only. The widget extension supports iOS 18.0 (the project-level setting says 18.4 but is overridden).
  - Supporting old devices is a deliberate product goal: people on old phones need cleanup the most. Guard newer APIs with `#available` (see **Availability tiers**); never raise the deployment target to get an API.
- **Bundle IDs:** `com.zeynepmuslim.purgio` (app) and `com.zeynepmuslim.purgio.StorageAnalysisWidget`. App Store id `6762494793`. Team `9N5WN36F7P`.
- **How it works:** the user swipes through their library month by month. Left marks an item for deletion (Delete Bin), right keeps it, and up stores it in a real "Will Be Stored" album.
  - Assets are deleted only from `DeleteBinViewController`.
  - The only money is a three-tier consumable tip jar (StoreKit 2). There are no paywalls, subscriptions, ads or feature gates.
- **Languages:** English and Turkish.

## Architecture: UIKit MVC (RULE)

Purgio is **plain UIKit MVC**. There are no view models, coordinators, routers or presenters. Don't introduce them, and follow the existing patterns in new code.

### View controllers
- A view controller owns its own loading, state and navigation.
  - It pushes with `navigationController?.pushViewController` and presents with `present(_:animated:)`.
  - It calls services and stores directly.
- The UI is built in code.
  - `SceneDelegate` builds the window. `Main.storyboard` is legacy (it points at the old module `Secure_Photo_Cleaner`, and `UIMainStoryboardFile` is still set); only `LaunchScreen.storyboard` is real.
  - No XIBs, no new storyboards.
- **Sheets:**
  - Set them up in a `private func configureSheet()`: `modalPresentationStyle = .pageSheet` and `prefersGrabberVisible = true`.
  - Use an `if #available(iOS 16.0, *)` custom detent (`.custom { $0.maximumDetentValue * 0.75 }`) with an iOS 15 fallback to `.medium()` or `.large()`.
  - Size-dependent detents are chosen in `viewWillAppear` (see **Layout**).
- **Alerts** use `UIAlertController`. **Menus** use `UIMenu` / `UIAction`.
- **Large view controllers are split into `+Feature.swift` extensions:** `MonthReviewViewController+DataLoading/+Swipe/+UI/+Video/+Helpers/+UndoHistory`, and `StorageAnalysisManager+ChunkedAnalysis/+BackgroundTasks/+AppLifecycle/+LiveActivity`.
  - Members used across those files must be `internal`, not `private`.
- **Navigation:**
  - The 4 tabs live in `MainTabBarController`, each in its own `UINavigationController`. **The tab indices are fixed and used across screens:** 0 Home, 1 Photos (`MonthsListViewController(mediaType: .image)`), 2 Videos (`.video`), 3 Settings.
  - Code that jumps between tabs sets `selectedIndex`, calls `popToRootViewController`, and then pushes (see Home's `navigateOnTab`).

### Components
- Components are programmatic `UIView`, `UIControl` or `UIButton` subclasses.
  - `init(frame:)` calls a private `setupUI()` / `setupButton()`.
  - `required init?(coder:)` is `fatalError("init(coder:) has not been implemented")`.
- **Callbacks are closure properties named `onX`,** e.g. `onRefreshTapped`, `onDismiss`, `onTap`, `onICloudBadgeTap`, `onEnableInternet`.
  - The only delegate protocols are `FloatingBinButtonController`, `SimilarGroupCellDelegate` and `UndoHistoryDelegate`. All are `AnyObject` and held `weak`.
  - Don't add delegates where a closure works.
- **Configuration API shapes, in order of preference:**
  1. `configure(...)` with labeled parameters and defaults, e.g. `FilterCard.configure(icon:title:subtitle:tintColor:)` and `EmptyStateView.configure(icon:iconColor:title:message:actionTitle:onAction:…)`.
  2. A config struct, e.g. `SettingsInfoCardConfig`, `DashboardCardContent`, `VideoPlayerController.Configuration`.
  3. `update(with: state)`, e.g. `StorageAnalysisView.update(with: StorageAnalysisState)`.
  4. Init injection for fixed content, e.g. `TipTier(title:imageName:imageSize:price:)`.
- **Progress views and skeletons:**
  - Progress views expose `setProgress(_:animated:)` and `startIndeterminate()`.
  - Skeletons expose `startAnimating()` / `stopAnimating()`. Card, cell and stats skeletons use `startShimmerAnimation()`. All are built on `Others/ShimmerLayer.swift`.

### Dependencies: `.shared` singletons
Dependencies are `final class` singletons with `static let shared` and `private init()`. The one exception is `EyeBlinkDetector`, whose `init` is internal.
- View controllers either cache them (`private let statsStore = StatsStore.shared`) or call `.shared` inline.
- Don't create a singleton for screen state. Add one only for app-wide state or a PhotoKit / OS wrapper.

| Singleton | Owns |
|---|---|
| `PhotoLibraryService` | PhotoKit auth, every asset fetch, month buckets (5-minute cache), the "Will Be Stored" album, the change observer |
| `ImageCacheService` | `PHCachingImageManager` + `NSCache` (100 MB, 50 items, cleared on memory warning) |
| `PhotoSimilarityService` | Vision feature-print grouping (completion-handler API) |
| `EyeBlinkDetector` (actor) | `CIDetector` closed-eyes check + result cache |
| `PhotoProcessor` (actor) | `AsyncStream<ProcessingResult>` pipelines for review, large files and eyes closed |
| `StorageAnalysisManager` | Storage scan, background task, Live Activity |
| `ReminderNotificationService` | Local reminders, `UNUserNotificationCenterDelegate`, deep link |
| `DeleteBinStore`, `KeptAssetsStore`, `WillBeStoredStore`, `ReviewProgressStore`, `MonthFilterStatusStore`, `SimilarUndoStore`, `StatsStore`, `ReminderDataCenter` | Persistent state (see **Persistence**) |
| `SettingsStore`, `OnboardingStore` | `UserDefaults` wrappers |
| `UndoHistoryManager` | Per-session swipe undo stacks |
| `DashboardCardManager` | Home's smart dashboard card + 5-minute gallery-context cache |
| `DateFormatterManager` | Cached formatters: `yyyy-MM` (en_US_POSIX), `MMMM yyyy`, `MM.yyyy`, short time |
| `HapticFeedbackManager` | All haptics |
| `TipJarManager` (`@MainActor`, `ObservableObject`) | StoreKit 2 products and purchases |
| `iCloudSyncLogger` | Categorized iCloud logging (off: `shouldLog = false`) |

### Cross-screen updates: NotificationCenter
Declare each name as a `Notification.Name` extension next to its owner, with the raw value equal to the identifier. Observe with `addObserver(self, selector:name:object: nil)`.

| Name | Declared in | Posted by → observed by | userInfo |
|---|---|---|---|
| `.deleteBinCountDidChange` | `DeleteBinStore` | every bin change, synchronously on main → MainTabBar, MonthReview, DeleteBin | — |
| `.deleteBinButtonTapped`, `.deleteBinEditStateDidChange` | `MainTabBarController` | bin button ↔ DeleteBin | `isEditMode: Bool`, `selectedCount: Int` |
| `.undoHistoryDidChange` | `UndoHistoryManager` | all of its changes, on main → MonthReview, UndoHistory | — |
| `.photoLibraryDidChange` | `PhotoLibraryService` | PhotoKit observer → MonthsList | — |
| `.photoAuthorizationGranted` | `PhotoLibraryService` | AskPermission → PhotoLibraryService, StorageAnalysisManager | — |
| `.filterByYear` | `MonthsListViewController` | Home's oldest-year card → MonthsList | `year` |
| `.notificationDeepLinkToDeleteBin` | `ReminderNotificationService` | notification tap → SceneDelegate | — |
| `.reminderDataCenterDidChange` | `ReminderDataCenter` | debounced 0.3 s → ReminderNotificationService | — |
| `.storageAnalysisDidStart/DidFetchBasicInfo/DidUpdateProgress/DidComplete/DidFail/DidPause` | `StorageAnalysisNotifications.swift` | StorageAnalysisManager → Home, Settings, StorageAnalysisBottomSheet, storage views | see **Storage analysis** |

## Forbidden APIs

| Do not use | Use instead |
|---|---|
| `UIScreen.main` (bounds, scale, anything) | `view.window?.bounds`, `view.bounds`, `traitCollection.displayScale` |
| `keyWindow`, `isKeyWindow`, `UIApplication.shared.windows`, walking `UIApplication.shared.connectedScenes` for a window | `view.window` / `self.window`, `view.window?.windowScene` |
| `userInterfaceIdiom`, `interfaceOrientation` | Size classes, `view.bounds`, `windowScene.effectiveGeometry` |
| `UIRequiresFullScreen` (Info.plist or build settings) | Nothing: screens must lay out at any size (see **iPhone Duo**) |
| `UIGraphicsBeginImageContext*` | `UIGraphicsImageRenderer` |
| `PHPickerViewController` to grow limited access | `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:completionHandler:)` |
| `String(localized:)` | `NSLocalizedString("<screen>.<key>", comment:)` |
| Hand edits to `Localizable.xcstrings` | `Localization/translations.csv` |
| Networking (`URLSession` requests), third-party SDKs/packages, analytics | Nothing. The app is offline by design |
| Combine / `ObservableObject` / `@Published` in new code | Closures, NotificationCenter, async/await. `TipJarManager` + `TipJarViewController` are the legacy exception |
| `UIColor(named:)` | Generated asset symbols (`.textPrimary`) |
| Direct `UIImpactFeedbackGenerator` etc. | `HapticFeedbackManager.shared` |

`Scripts/forbidden-api-check.sh` enforces everything in this table from `UIScreen.main` through `String(localized:)`. It runs as the **Forbidden API check** build phase, the first phase of the app target, and a violation fails the build. Lines that start with `//` are ignored. Run it by hand with `Scripts/forbidden-api-check.sh`.

## Layout

- **Auto Layout through anchors only:**
  - Use `NSLayoutConstraint.activate([...])`.
  - Use leading/trailing, **never left/right**.
  - Use `NSDirectionalEdgeInsets` for insets.
  - Frames are only for layers, masks and overlays.
- **View declaration and setup:**
  - Declare views as closure-initialized properties: `private let x: T = { let v = T(); v.translatesAutoresizingMaskIntoConstraints = false; …; return v }()`.
  - Build in `setupUI()`, then constrain in `setupConstraint()`. The name is singular, as in the existing code.
  - Keep constraints that change as stored `NSLayoutConstraint?` and toggle `isActive`.
- **Size-dependent decisions run after layout, never in `init`, `viewDidLoad` or lazy initializers.** The window's size is unknown there and changes on the Duo.
  - Views re-apply in `layoutSubviews()`, e.g. `StorageAnalysisLiteView.applyHeaderLayoutVariant()`, `DashboardCard.applySizeVariant()` and `FilterCard`.
  - View controllers configure in `viewDidLayoutSubviews` or `viewWillAppear`, either behind a once-flag (`didSetupLayout` in Onboarding, `didConfigureForSize` in TipJar and SimilarPhotosHelpSheet) or re-applied whenever the value changes (`appliedToolbarShowsTitles` in UndoHistory).
  - **Compact variants follow the view's own width**, not the window's, so they follow display, column and Split View changes:
    - Cards compare `bounds.width` with `GeneralConstants.CompactContentWidth`: `fullWidthCard` (350) for full-width cards (`DashboardCard`, `StorageAnalysisLiteView`), `halfWidthCard` (167) for two-up cards (`FilterCard`). Both are calibrated so 375pt iPhones get the compact look and 390pt+ the regular one.
    - UndoHistory's toolbar shows titles in regular width or at 430pt+ of its own width.
  - Sheet detents still read `view.window?.bounds ?? view.bounds`: `<= 667` tall gets large detents.
- **Scale** comes from `traitCollection.displayScale`.
  - On iOS 17+, re-render thumbnails with `registerForTraitChanges([UITraitDisplayScale.self])`.
  - `ImageCacheService`'s overloads without `traitCollection:` are `@available(*, deprecated)` shims. Don't use them in new code.
- **Edge paddings 16, 18 and 20 are deliberately different.** Name each by its role and never merge them:
  - **20:** screen content (`GeneralConstants.EdgePadding.content`: Home, MonthReview card and controls, DeleteBin buttons, MediaPreview, sheet titles)
  - **16:** floating controls and sheet content (`GeneralConstants.EdgePadding.medium`: the bin button, LuckyPicker, UndoHistory, HistoryDetail)
  - **18:** Settings rows and cards' inner padding (`SettingsViewController`, `SettingsInfoCardView`, `SettingsLinkRowView`, `DashboardCard`, `StorageAnalysisView`), and the clearance from the device corner opposite a trailing rail
- **Tokens:** use `GeneralConstants` (`Purgio/Others/Constants.swift`) instead of new literals:
  - `EdgePadding.small` 10, `EdgePadding.medium` 16, `EdgePadding.content` 20. Values are positive; apply the edge's sign at the constraint.
  - `CornerRadius.card` 16
  - `CompactContentWidth.fullWidthCard` 350, `CompactContentWidth.halfWidthCard` 167
  - Vertical rail (`DuoLayout.RailPadding`, `Purgio/Others/DuoLayout.swift`): `nextToRail` 6, `bottom` 20, `cornerClearance` 18
  - `ButtonSize.small` 30, `medium` 44, `mediumLarge` 50, `large` 56
  - `Spacer.buttonBottom` 24
  - `BulkYear.sparseYearThreshold` 50

  If a value has no token yet and repeats, add the token first.
- **Corners:** every rounded corner sets `layer.cornerCurve = .continuous`. Pill buttons use `config.cornerStyle = .capsule`.
- **Lists:** classic data source / delegate with string reuse IDs.
  - `UITableView`: MonthsList and UndoHistory (`.insetGrouped`), SimilarPhotos (plain).
  - `UICollectionView` with a flow layout: DeleteBin grid, SimilarGroupCell, StoreTutorial.
  - Settings is a `UIScrollView` + `UIStackView`.
  - Nothing uses diffable data sources yet. New lists may use them (they need no newer OS).

## iPhone Duo (UNBREAKABLE RULES)

These rules come from Photolift's verified Duo work, adapted to Purgio's iOS 15 target. Every iPhone Duo API needs the **iOS 27.1 SDK**: `UIHingeInteraction`, `reservedRegions(kind:)`, `UIView.LayoutRegion.bar(onEdge:extent:)`, `preferredVerticalBarBehavior`, `visibilityPriority`. Wrap them in `if #available(iOS 27.1, *)`.

### Device facts
- **Inner display:** 669×951pt upright, 951×669pt held sideways. It is a regular-width size class.
- **Cover display (folded):** 466×678pt, compact width.
- **The camera** reserves 84pt along the **whole trailing edge**. `reservedRegions(kind: .occlusion)` shows the camera itself covers only the top 170pt. Content pinned to the superview runs under it.
- **System minimum layout margins** are 16pt on the iPhone 17 and 20pt on the Duo.
- **Bar buttons:** the system moves navigation-bar buttons beside the camera, but only once the bar lays out again. A button that starts on the leading side can jump to the trailing side after a push and pop. Put Duo-specific bar items where they'll end up from the start.
- **Tab bar:** on iOS 26 it can become a vertical rail beside the camera.

### Rules
- **Never add `UIRequiresFullScreen`.** It's deprecated since iOS 26, and with it the unfolded Duo shows the app in a letterboxed portrait window. Without it the app fills the display and every screen must lay out at any size. The forbidden-API script checks for it.
- **Never detect the Duo with screen sizes.** Layout reacts to what the view sees, on every layout pass: the tab rail's shape, the fold region, the size class and the view's own bounds.
  - **Inner vs cover display:** `traitCollection.horizontalSizeClass` is `.regular` on the inner display and `.compact` on the cover.
  - **Inner display held sideways:** additionally `view.bounds.width > view.bounds.height`.
  - No screen needs the hinge state today. If one does, use `UIHingeInteraction` (iOS 27.1); its update can arrive after the first layout, so layout code must handle the state changing later.
- **Camera and fold regions** are read in `viewDidLayoutSubviews` (or a method it calls), inside `#available(iOS 27.1, *)`:
  - Camera: `view.reservedRegions(kind: .occlusion).map(\.frame)`. On the cover display, controls may run under the system's side bar only where none of these frames intersect them.
  - Fold: use `FoldRegion` (`Purgio/Others/FoldRegion.swift`), which wraps `reservedRegions(kind: .division)`:
    - `activeFold(in:)`: the fold while the device is partly folded, else nil. `pose(for:)` turns it into `.flat`, `.book` (vertical band) or `.table` (horizontal band).
    - `splittingFold(in:)`: the fold even while fully open, but only when it leaves at least a third of the view on each side. Use it for where columns split, so the layout doesn't jump when the device folds (and doesn't split in Split View).
  - **Nothing tappable goes on the fold.** Inner layouts split at the fold's real position:
    - Home: storage plus the Photos/Videos tiles on one side, the dashboard on the other.
    - MonthFilterCards: stats plus All Photos/Videos on one side, the four filters on the other (one per row when side by side).
    - MonthReview (`+Fold.swift`): a vertical fold splits the undo/history row (undo ends before the fold, history starts after it). In the table pose the card sits on the raised half and stats plus controls on the base; in the book pose the video play button moves to the larger side of the fold.
    - DeleteBin: a vertical fold splits the grid into two equal halves on either side of the fold line (`FoldSplitFlowLayout` widens the gap there). The half with less room sets the cell size, so the other side gets a wider margin.
    - The wide "Delete All" bin button keeps to the trailing side of the fold in the book pose.
    - Split controls the same way Home splits content: use `splittingFold` so they don't jump when the device folds, center the gap on the fold line while fully open, and clear the whole fold region (`activeFold`'s width) while folded.
- **Detecting the tab rail:** no API reports where the tab bar sits (`mode` and `sidebar.preferredPlacement` don't), so use geometry, evaluated in `viewDidLayoutSubviews`. `DuoLayout` wraps it:
  - `isVerticalRail(tabBarController)`: the tab bar is taller than wide.
  - `railSide(_:in:)`: the physical side (`.left` / `.right`). The rail sits on the app's outer edge: right on the full display, left in Split View on the left half.
  - `railEdge(_:in:)`: the same as a layout edge (`.leading` / `.trailing`), for leading/trailing constraints.
- **Bar items are standard titled `UIBarButtonItem`s, never `customView`s.** The system can then move them into the vertical bar or the overflow menu. Give every item a `title`, even when it shows an image. Shared items live in `UIBarButtonItem+Common.swift` (`.helpItem`, `.luckyItem`). Set `visibilityPriority` (iOS 27.1) on screens with more than one item, so the frequent action overflows last.
- **Horizontal edges come from the safe area, never the superview.**
  - Every view a view controller adds to `view` pins its sides to `view.safeAreaLayoutGuide.leadingAnchor` / `trailingAnchor`, never to `view.leadingAnchor` / `trailingAnchor`.
  - Portrait iPhones can have a horizontal safe area: the Duo's 84pt camera strip.
  - **Exception — sideways-scrolling content spans the full width.** A collection view or scroll view that scrolls sideways pins to `view` and lets the safe area inset its content, so items rest inside it and scroll under the camera.
    - Set `contentInsetAdjustmentBehavior = .always`. With `.automatic` the trailing inset stayed 0 on the Duo.
    - For a compositional layout's `.continuous` sections, leave `contentInsetsReference` at its default; with `.none`, the last item rests under the camera.
    - A vertical scroll view that holds a sideways row also spans the full width. Pin its content's sides to `view.safeAreaLayoutGuide`, and set the `contentLayoutGuide` width to the `frameLayoutGuide`'s.
  - **Exception — full-screen decoration spans the full width.** Artwork, gradients and backgrounds with nothing to read or tap pin to `view`, e.g. the iOS 26 top gradient in MonthsList. Text and controls drawn over them still follow the safe-area rule.
  - Home, MonthFilterCards, MonthReview, DeleteBin and SimilarPhotos follow this rule. Other screens still pin to `view.leadingAnchor` (see **Known issues**); bring every screen you touch up to it.
- **Padding is a constraint constant from the safe area,** using the role's token (see **Layout**). Don't rely on system layout margins for padding: UIKit raises them to the system minimum, and 16pt quietly becomes 20pt on the Duo. Gaps between siblings are constants too.
- **Screen edges that must follow the vertical rail use `DuoEdgeConstraints`** (`Purgio/Others/DuoLayout.swift`). It builds the leading, trailing and (optionally) bottom constraints and switches them between the screen's standard padding and Home's rail padding:
  ```swift
  let edges = DuoEdgeConstraints(
      item: controlsStack, in: view,
      standardLeading: GeneralConstants.EdgePadding.content,
      standardTrailing: GeneralConstants.EdgePadding.content,
      standardBottom: GeneralConstants.Spacer.buttonBottom)
  duoEdges = [edges]
  NSLayoutConstraint.activate(edges.initialConstraints)

  // viewDidLayoutSubviews
  duoEdges.forEach { $0.update(railEdge: DuoLayout.railEdge(tabBarController, in: view)) }
  ```
  - With a rail: `RailPadding.nextToRail` (6) from the safe area on the rail's side, the standard padding on the other side, and the bottom at `view.bottomAnchor` − `RailPadding.bottom` (20), not the safe area.
  - `railTrailingFarLeading`: a different leading distance while the rail is trailing. Full-width rows that would touch the device's rounded corner pass `RailPadding.cornerClearance` (18), e.g. DeleteBin's edit buttons and the wide bin button.
  - `standardBottom: nil` leaves the bottom to other constraints. `railBottomOffset` lifts a view that sits above the bottom row instead of on it (MonthReview's loading skeleton).
- **Home is the reference.** Don't change `HomeViewController`'s padding or margins in Duo work (its only Duo layout change is the split at the fold); make the other screens match its edges, the bottom edge most of all.
  - `updateOuterPaddingForTabBarShape()`: with the rail showing, 6pt next to the rail, 20pt (`EdgePadding.content`) on the far side, and the bottom 20pt above `view.bottomAnchor`.
  - Bottom rows, the bin button and Home's content sit on the same baseline.
- **Card corners follow the device corner on the rail.** `UIView.updateCardCorners(followingDeviceCorner:)` (`UIView+CardCorners.swift`, iOS 26+) gives every corner the standard 16, except a bottom corner that sits in the window's bottom corner, which becomes container-concentric. Call it after layout, with `followingDeviceCorner` set to whether the rail shows. Home (dashboard and Photos/Videos tiles) and MonthFilterCards use it.
- **`Docs/iPhone-Duo-Transformation.md`** is the step-by-step guide. Follow it for any layout or bar change.
- **Bin button on iOS 26:** pinned to `contentLayoutGuide` (see **Floating bin button**).

### Verifying on the Duo
- Check every UI change on the **iPhone 17** and on the **iPhone Duo (iOS 27.1)** simulators, on both the cover and the inner display, in light and dark.
- **Cover display:** a new Duo simulator starts folded.
- **Inner display:** unfold the device in the Simulator app. Folding and unfolding can't be scripted with `simctl`.
- `xcrun simctl io <udid> screenshot` with no `--display` captures the inner display, which is black while the device is folded.
- On the Duo, the hinge update and the bar's button re-gather land late. Wait a moment and lay out again before judging a screenshot.
- The `device-interaction` skill drives the simulator: screenshots, UI hierarchy, taps (see **Skills**).

## Availability tiers

| Guard | Used for |
|---|---|
| `#available(iOS 16.0, *)` | `UISheetPresentationController.Detent.custom` (Home ×3, StorageAnalysisBottomSheet, YearDetailSheet, MonthsList, iCloudWarningSheet) |
| `#available(iOS 16.2, *)` | Live Activities: only in `StorageAnalysisManager+LiveActivity.swift`. The activity is stored as `Any?` so the class compiles for iOS 15 |
| `#available(iOS 17.0, *)` | `registerForTraitChanges` (DeleteBin, UndoHistory, GradientView); `@available(iOS 17.0, *)` on `#Preview`s |
| `#available(iOS 26.0, *)` | Liquid Glass: `.prominentGlass()` / `.glass()` button configurations, clear sheet backgrounds, MonthsList's top gradient, the bin button's `contentLayoutGuide`, card corners (`cornerConfiguration`) |
| `#available(iOS 27.1, *)` | iPhone Duo APIs: `reservedRegions` (`FoldRegion`), `visibilityPriority` (see **iPhone Duo**) |

- **Liquid Glass buttons:** on iOS 26 use `UIButton.Configuration.prominentGlass()` / `.glass()` with `tintColor`. Before iOS 26 fall back to `.filled()` / `.gray()` with `.capsule`.
  - `DynamicGlassButton` wraps this: `configure(title:…style: .prominent|.regular, backgroundColor:…)`, and `animateConfigure(...)` cross-dissolves. Disabled is alpha 0.5 via `configurationUpdateHandler`. It is the general-purpose button; use it for new buttons.
- The deprecated `traitCollectionDidChange` + `hasDifferentColorAppearance` is still used to refresh `CGColor`s in AnalysisProgressRing, MiniProgressRing, SlideToConfirmButton, SoapBubble, MonthReview+UI and Settings.
  - On iOS 17+ prefer `registerForTraitChanges([UITraitUserInterfaceStyle.self])`, keeping the old path for iOS 15/16.

## Design system

- **Colors come from `Purgio/Resources/Assets.xcassets`** through the generated asset symbols (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`).
  - Common: `.mainBackground`, `.cardBackground`, `.reviewCardBackground`, `.textPrimary`, `.textSecondary`, `.textTertiary`.
  - Media accents: `.photo100` / `.photo50` and `.video100` / `.video50`. Photo filters use `photo100`, video filters `video100`.
  - Status: `.progressCompleted`, `.progressInProgress`.
  - Storage: `.storageUsed`, `.storageFree`, `.storageAvailable`, `.storageOther`, `.storageSavedBar`, `.storageSavedLabel`.
  - Tip jar: `.tipJarRed100`.
  - Palette: `.blue100`, `.green100/200`, `.red100/200`, `.yellow100/200`.
  - Every colorset is a light/dark pair.
  - New colors: add a colorset with both appearances, then use its symbol.
  - Unused colorsets: `TextTertiaryReverse`, `purple100`, and `StorageUsed 1` (a duplicate).
- **System colors** (`.label`, `.systemBlue`, `.systemGreen`, …) are widely used and allowed.
  - `ThemeManager.Colors.statusRed/Green/Yellow` return `.systemRed/Green/Yellow`. Use them for delete, keep and store semantics.
- **Delete / keep / store colors:**
  - Delete is red (left edge gradient).
  - Keep is green (right).
  - Store is yellow (top).
  - Icons: trash, checkmark, archivebox.
- **Fonts:** `ThemeManager.Fonts` (`Purgio/Others/ThemeManager.swift`).
  - **Titles** use New York serif through `titleFont(size:weight:)` (`fontDescriptor.withDesign(.serif)`, with a system fallback): `display` 32 bold, `boldTitle` 24 bold, `semiboldBody` 16 semibold.
  - **Captions:** `regularCaption` / `semiboldCaption` (13), `thinBody` (17 thin). Body text is `.systemFont(ofSize:weight:)`.
  - **Counters** use `monospacedDigitSystemFont`.
  - `ThemeManager.configureNavigationBarAppearance()` runs first in `AppDelegate`. It sets serif titles: large 34 bold, inline 17 semibold.
  - `ThemeManager` has no theme switching, and `ThemeManager.shared` is unused.
  - **There's no Dynamic Type support yet**: no `preferredFont`, `UIFontMetrics` or `adjustsFontForContentSizeCategory` anywhere. Don't make it worse; new text should still fit when it wraps.
- **Haptics:** only through `HapticFeedbackManager.shared`.
  - `impact(intensity:)`: `.medium` for navigation and swipes, `.light` for secondary taps.
  - Also `success()`, `warning()`, `error()`, `selection()`, and `prepareAll()` before swipe sessions.
- **Animation:** `UIView.animate`.
  - Morphs use a spring (0.4 s, damping 0.75, velocity 0.8). Fades take 0.25–0.3 s.
  - No `UIViewPropertyAnimator` or `CADisplayLink`.
- **Reusable components** (`Purgio/Components`, `Purgio/Views`):
  - Buttons: `DynamicGlassButton`, `FloatingBinButton`, `CloseButton` (44×44).
  - Bar items: `UIBarButtonItem.helpItem(target:action:)` and `.luckyItem(title:target:action:)`.
  - Cards and rows: `FilterCard`, `DashboardCard`, `SwipeCardView`, `StatItemView`, `MonthStatItemView`, `ImpactStatsView`, `SettingsInfoCardView`, `SettingsLinkRowView`, `TipTier`, `FakeAlbumCell`.
  - Progress: `SegmentedBarView`, `CircularProgressView`, `MiniProgressRing`, `AnalysisProgressRing`.
  - Controls and players: `SlideToConfirmButton`, `VideoPlayerController`.
  - Views: `GradientView`, `EmptyStateView`, `PaddingLabel`, `SoapBubble`, plus the skeletons.
  - Reuse these before writing new ones.

## Concurrency

- **Services expose async/await APIs** built on GCD. All of `PhotoLibraryService`'s fetches use this shape:
  ```swift
  await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async { …; continuation.resume(returning: result) }
  }
  ```
- **Actors:** `EyeBlinkDetector` and `PhotoProcessor` (which returns `AsyncStream`).
- **Completion handlers** remain in `PhotoSimilarityService`, `ImageCacheService.loadImage` (`(UIImage?, isInCloud, isDegraded)`) and `ReminderNotificationService.requestAuthorization`. They call back on main.
- **Work started by a view controller** is a stored, cancellable task. Cancel it before replacing it and in `viewWillDisappear`:
  ```swift
  dashboardRefreshTask?.cancel()
  dashboardRefreshTask = Task { [weak self] in
      guard let self else { return }
      let content = await cardManager.generateSmartCard()
      guard !Task.isCancelled else { return }
      await MainActor.run { self.dashboardCard.updateContent(content) }
  }
  ```
- **View controllers aren't annotated `@MainActor`.** Hop to main explicitly: `MainActor.run`, `DispatchQueue.main.async`, or `Task { @MainActor in }`.
- **Debounce** with a `DispatchWorkItem` + `asyncAfter(0.3)` or `Task.sleep(nanoseconds:)`.
- **Main-thread-only stores** assert on every call (`assert(Thread.isMainThread)`): `DeleteBinStore`, `KeptAssetsStore`, `WillBeStoredStore`, `MonthFilterStatusStore`, `SimilarUndoStore`, and `ReminderDataCenter`'s setters. Never touch them from a background queue or a detached task.
  - `ReviewProgressStore` (serial queue: `sync` reads, `async` writes), `StatsStore` (`NSLock`) and `UndoHistoryManager` (concurrent queue with barrier writes) are safe from any thread.

## Persistence

**Shape of a JSON store:**
- `final class`, `.shared`, with an in-memory cache.
- `init` creates `Documents/Purgio/` and loads synchronously.
- Writes go through `try? data.write(to:options: .atomic)` on a private serial `DispatchQueue`.
- Errors are swallowed with `try?`.

**New stores** use `Documents/Purgio/<name>.json` and a `com.purgio.<Type>.storage` queue label. Existing labels mix the legacy `com.galary.*`, `com.purgio.*` and bare `XStore.storage`; leave those alone.

| Store | File (under `Documents/`) | Writes | Notes |
|---|---|---|---|
| `DeleteBinStore` | `Purgio/deleteBin.json` | debounced 0.3 s | main only; posts `.deleteBinCountDidChange` |
| `KeptAssetsStore` | `Purgio/keptAssets.json` | immediate async | main only |
| `WillBeStoredStore` | `Purgio/willBeStored.json` | immediate async | main only |
| `MonthFilterStatusStore` | `Purgio/monthFilterStatus.json` | immediate async | main only; `[monthKey: finishedFilters]`; defines `FilterType` |
| `ReviewProgressStore` | `Purgio/reviewProgress.json` | async on its queue | see **Review model** |
| `StatsStore` | `Purgio/stats.json` | debounced 0.3 s | `NSLock` |
| `SimilarUndoStore` | `Purgio/similarUndo.json` | detached task, debounced 0.3 s | main only; prunes entries older than 30 days at init |
| `ReminderDataCenter` | `Purgio/reminderData.json` | debounced 0.3 s | setters main only |
| `EyeBlinkDetector` cache | `Purgio/eyeBlinkCache.json` | debounced 2 s | at most 5000 entries, oldest evicted first |
| `StorageAnalysisManager` | `Purgio/storageAnalysisCache.json`, `Purgio/storageAnalysisProgress.json` | atomic, on its queue | |
| `UndoHistoryManager` | **`undoHistory.json` at the Documents root** | debounced 1 s | at most 50 sessions |

**`UserDefaults.standard`** keys are `private let fooKey = "foo"` constants behind computed properties. Defaults use an `object(forKey:) == nil` check.
- **`SettingsStore`:**
  - `allowInternetAccess`, `internetOverrideActive`, `skipICloudPhotos`
  - `hasShownInitialICloudWarning`, `hasShownPerCardICloudWarning`, `hasShownStoreTutorial`
  - `remindersEnabled`, `reminderHour` (20), `reminderMinute` (0), `reminderFrequency` (`.weekly`), `reminderWeekdays` (`[6]`, Friday), `reminderMonthDay` (1, clamped to 1…28)
- **`OnboardingStore`:** `hasCompletedOnboarding`.
- **`DashboardCardManager`:** `hasGeneratedDashboardCard`. `cachedDashboardCardContent` is declared but unused.
- **`StorageAnalysisManager`:** `storageAnalysisSessionId`, `iCloudPhotosSyncOn`.

## PhotoKit and services

### Authorization and the library
- Always use `PHPhotoLibrary.authorizationStatus(for: .readWrite)`.
  - **`.authorized` and `.limited` both count as granted.** `.notDetermined` is special: don't touch PhotoKit there, because that can trigger the system prompt.
- `PhotoLibraryService` registers as `PHPhotoLibraryChangeObserver` only once access is granted: at init if already granted, otherwise on `.photoAuthorizationGranted`. Its change callback invalidates the bucket cache and posts `.photoLibraryDidChange` on main.
- **Month buckets:**
  - `loadMonthBuckets(mediaType:)` groups assets by `DateFormatterManager.monthKey` (`"yyyy-MM"`), newest first, into `MonthBucket { key, title, totalCount }`.
  - The cache is valid for 300 s. Call `invalidateMonthBucketsCache()` after anything changes the library: deletions, or the limited-library picker closing.
  - `AppDelegate` preloads it when access is granted.
- **"Will Be Stored" album:** `getOrCreateWillBeStoredAlbum()` finds or creates an album titled exactly `"Will Be Stored"` (not localized; see **Known issues**). Use `addAssetToWillBeStoredAlbum` and `removeAssetFromWillBeStoredAlbum`.
- **Limited access:**
  - Use `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:completionHandler:)`. `PHPickerViewController` only returns copies and doesn't expand the accessible set.
  - After the picker closes, call `invalidateMonthBucketsCache()` before reloading, or the cached empty result comes back.
  - `presentLimitedLibraryPicker` is a PhotosUI Objective-C category method. `import PhotosUI` alone doesn't link the framework when no PhotosUI symbol is referenced, and the call then crashes with "unrecognized selector". That's why `PhotosUI.framework` is linked explicitly in the app target. **Don't remove it.**
- **Asset metadata:** `PHAsset.resourceMetadata()` (`Others/PHAsset+Metadata.swift`) makes one `assetResources` call and returns `(fileSize, isCloudOnly)`.
  - `fileSize` is the first resource's KVC `fileSize`.
  - `isCloudOnly` means every resource has `locallyAvailable == false`.
  - Prefer it over the `fileSize` / `isCloudOnly` convenience properties, which each call it again.

### Images (`ImageCacheService`)
- **`ImageQuality`:**

  | Quality | Size | Delivery |
  |---|---|---|
  | `.thumbnail` | 200×200 × scale | `.opportunistic` |
  | `.preview` | screen × scale × 0.7 | `.opportunistic` |
  | `.full` | screen × scale | `.highQualityFormat` |

  All use resize mode `.fast` and `.aspectFill`.
- **Call shape:** `loadImage(for:quality:screenSize:allowNetworkAccess:traitCollection:completion:)`. Pass `screenSize: view.bounds.size` and the view's `traitCollection`.
- **iCloud is opt-in:** pass `allowNetworkAccess: SettingsStore.shared.allowInternetAccess`.
  - **Offline fallback:** when the image is nil and `PHImageResultIsInCloudKey` is set, it retries with `.fastFormat` at 100×100 without network access.
  - Degraded images aren't cached.
- **Still on the deprecated overloads:** `PhotoSimilarityService`, `EyeBlinkDetector`, and MonthReview's `startCaching` / `stopCaching`.

### Analysis
- **Similar photos** (`PhotoSimilarityService`):
  1. Sort the assets by date.
  2. Cluster them with a **chained 120 s gap**: a new cluster starts when consecutive photos are more than 120 s apart.
  3. In clusters of 2 or more, run `VNGenerateImageFeaturePrintRequest` on 128×128 thumbnails, in batches of 5 with a 30 s timeout per batch. `usesCPUOnly` is on in the simulator.
  4. **Complete linkage:** a photo joins a group only if its distance to *every* member is **< 10.0**.

  The best photo is the first favorite, otherwise the earliest.
- **Eyes closed** (`EyeBlinkDetector`, an actor):
  - Uses `CIDetector` (face, high accuracy, `CIDetectorEyeBlink`) on a 1024×1024 preview.
  - Only the **largest face** counts, so faces in the background of a selfie don't. It counts as closed only when **both** eyes are closed.
  - 15 s timeout per asset. Timeouts and no-face results aren't cached.
- **Large files** has **no size threshold**. It's every unprocessed item, sorted by size, largest first (`PhotoProcessor.processAssetsForLargeFiles`).
- **`PhotoProcessor`** streams `ProcessingResult`: `.progress`, `.initialBatchReady([ReviewAsset])` (the first 50 when a month has more than 50, so the deck appears early), `.completed`, `.cancelled`. Check `Task.isCancelled`.

## Review model

- **Month keys** are `"yyyy-MM"` (`DateFormatterManager.monthKey(from:)`).
  - **Year keys** are `"year-YYYY"`. A year with fewer than `BulkYear.sparseYearThreshold` (50) items is reviewed as one session.
  - Year keys don't parse as dates: `fetchPhotos(forMonthKey:)` matches nothing and `countBinAssets` returns 0. Guard with `hasPrefix("year-")` and use the preloaded year assets.
- **Progress keys** (`ReviewProgressStore`) are `"photo_<key>"` or `"video_<key>"`.
  - `<key>` is a month key, a year key, or a filter sub-key `"<monthKey>_<filter>"`.
  - `<filter>` is a `MonthFilterStatusStore.FilterType` raw value: `screenshots`, `largeFiles`, `eyesClosed`, `similar`, `screenRecordings`, `slowMotion`, `timeLapse`.
  - Each record holds `currentIndex, reviewedCount, deletedCount, keptCount, storedCount, originalTotalCount`.
- **"Complete" is always** `originalTotalCount > 0 && reviewedCount >= originalTotalCount`. Use the same test everywhere.
- **"Processed" is global.** An asset in the bin, kept or will-be-stored store is skipped by every deck, filter and session (`advanceToFirstUnprocessedIndex`), even when another session processed it.
  - SimilarPhotos is the exception: it keeps assets that `SimilarUndoStore` knows about, so those groups can be undone.
- **Filter progress has two layers.**
  - The filter key holds the filter's own counters.
  - MonthReview's `saveProgress()` **delta-syncs** changes into the main month key with one `batchSave`. Reviewed is clamped to the main total; delete + keep + store is scaled down so it never exceeds reviewed. If the filter's total changed, the sync is skipped.
  - SimilarPhotos `batchSave`s both keys directly.
  - In filter mode, the stats label shows the **main** month's numbers. The nav bar's `MiniProgressRing` shows the filter's own progress.
- **Finished flags** (`MonthFilterStatusStore`):
  - **Set** when a filter returns nothing, when a filter review completes, and when a fully reviewed month drops to 0 items.
  - **Cleared** when a non-empty filter loads, and by `clearAllFinishedFilters(month)` when a month's item count grows.
  - A finished card can't be opened.
- **Total-count resync:** MonthsList and MonthFilterCards compare the live count with `originalTotalCount`.
  - **Grew:** save the new total and clear the finished flags.
  - **Shrank:** clamp reviewed, deleted, kept, stored and `currentIndex`.
- **Filters per media type** (`MonthFilterStatusStore.filters(for:)`):
  - Photos: all, screenshots, largeFiles, eyesClosed, similar.
  - Videos: all, largeFiles, screenRecordings, slowMotion, timeLapse.
  - Subtype filters: `.photoScreenshot`, `.videoScreenRecording`, `.videoHighFrameRate`, `.videoTimelapse`.

## Screens

### Startup and onboarding
- **`AppDelegate.didFinishLaunching`**, in order:
  1. `ThemeManager.configureNavigationBarAppearance()`
  2. `SettingsStore.endTemporaryInternetOverride()`
  3. Register the background task.
  4. Preload buckets if access is granted.
  5. Set the reminder delegate and categories.
  6. Touch `TipJarManager.shared` (starts the `Transaction.updates` listener).
- **`SceneDelegate`** builds the tabs, calls `ReminderNotificationService.shared.syncScheduleIfNeeded()` and handles the Delete Bin deep link: tab 1, pop to root, push `DeleteBinViewController`.
- **`HomeViewController.runStartupFlow()`** runs once, from `viewDidAppear`:
  1. Onboarding not completed: present `OnboardingViewController` (the swipe guide, 75% detent). "Got it" and swipe-to-dismiss both set `hasCompletedOnboarding`, and `onDismiss` runs the flow again.
  2. Otherwise, with access `.notDetermined`: present `AskPermissionBoardingViewController()` with `isModalInPresentation = true`. Granted or limited posts `.photoAuthorizationGranted` and dismisses. Denied offers Open Settings. It also re-checks on `didBecomeActive`.
- `AskPermissionBoardingViewController(status: .noAction)` is the same screen as a read-only privacy sheet. Settings' Privacy card opens it.

### Home (`Screens/Home`)
- **Layout:** a vertical stack of `StorageAnalysisLiteView`, a row of Photos and Videos `FilterCard`s ("Browse by month"), and a `DashboardCard`. On the Duo's inner display it splits at the fold (see **iPhone Duo**).
- **Bar buttons:** `.luckyItem` on the left, `.helpItem` on the right (presents onboarding again).
- **Data:** `loadData()` returns early while access is `.notDetermined`. Otherwise it shows the cached storage data, calls `refreshIfNeeded()` and refreshes the dashboard. It observes the storage notifications.
- **Storage view tap:** presents `StorageAnalysisBottomSheet` (55% detent, a ring while loading). Ignored while iCloud Photos sync is on.
- **Photos / Videos cards:** select tab 1 or 2 and pop to root.
- **Dashboard card:** `DashboardCardManager.generateSmartCard()` makes a weighted random pick:
  - **Motivation** (weight 60): one of 11 messages plus one of 5 action suggestions built from a cached `GalleryContext`.
  - **Resume** (25): a random in-progress plain month.
  - **Analytics** (25): only when the user has deleted 20+ items or saved 50 MB+. It suggests the opposite media type, or Similar.
- **Dashboard actions:**
  - `.viewLargestVideos` → MonthReview (largeFiles, video)
  - `.viewSimilarPhotos` → SimilarPhotos (`.dashboard` source)
  - `.viewScreenshots` → MonthReview (screenshots)
  - `.viewOldestYear` → tab 1, then `.filterByYear` after 0.3 s
  - `.resumeMonth` → MonthFilterCards
  - `.browsePhotos` / `.browseVideos` → the matching tab

  `navigateOnTab` selects the tab, pops to root, then pushes after 0.1 s.
- **Lucky picker** (`LuckyPickerSheetViewController`, 360pt detent):
  - A 2 s slot-machine shuffle (0.12 s ticks) picks a media type, an unfinished month and a filter.
  - Go pushes `MonthReviewViewController(filterContext:)` with `navigationSource = .luckyPicker`.
  - With no unfinished months, Go is disabled.

### Months list (`Screens/MonthsList`)
- One class, two tabs: `MonthsListViewController(mediaType:)`.
- **Permission states:**
  - Granted: the table.
  - `.notDetermined`: "Allow access", which requests access.
  - Denied: Open Settings.
- **Loading:** `loadMonths()` runs on `viewWillAppear`, on `.photoLibraryDidChange` and after the limited picker. It shows `SkeletonMonthListView` only when there's no data yet, and resyncs totals (see **Review model**).
- **Sections:** an inset-grouped table, one section per year.
  - A year with fewer than 50 items gets one `YearAggregateCell`, which opens the `year-YYYY` session. Otherwise each month gets a `MonthListCell`.
  - Both push `MonthFilterCardsViewController`.
  - A cell shows one of three states: done ("All caught up", `.progressCompleted`), not started ("N to review"), or in progress (partial `photo50` / `video50` fill + stats).
- **Filters:**
  - A status menu: All / Completed / In Progress / Not Started. A year menu, plus `.filterByYear`.
  - A reset button appears while a filter is active. Filters that match nothing reset themselves.
- **Limited access with no months:** `EmptyStateView` with "Select photos/videos", which calls `presentLimitedLibraryPicker`.
- **Bin button:** global `.count(DeleteBinStore.count)`; it opens the unfiltered bin.
- On iOS 26 a top gradient covers the area above the safe area.

### Month filter cards (`Screens/MonthFilterCards`)
- **The hub for a month or year session.** Its title is the month (or year) alone; the selected Photos/Videos tab names the media type.
- **Stats card:** a `CircularProgressView` plus Reviewed / Delete / Keep / Store `MonthStatItemView`s, clamped so the numbers stay consistent.
- **Cards:**
  - Photos: Similar & Duplicated | Largest First, Eyes Closed | Screenshots, All Photos.
  - Videos: Slow Motion | Largest First, Time-lapse | Screen Recordings, All Videos.
  - A card's status comes from its finished flag, then from its filter key's progress. A complete card does nothing when tapped.
- **Routes:**
  - Similar → `SimilarPhotosViewController`
  - Largest and Eyes Closed → `ProcessingLoadingViewController(config: .largeFiles() / .eyesClosed())`
  - Everything else → `MonthReviewViewController(filterContext:)` directly
- **Year sessions:**
  - `preloadYearAssets()` fetches every `YYYY-` bucket once and hands the assets to each filter (`setSortedAssets`).
  - An info button opens `YearDetailSheet`. Its per-month percentages are **estimates**: the year's reviewed count spread in proportion to photo counts.
- **Bin button:** `.count`, refined with `countBinAssets(in: month)`. Its tap opens the bin filtered to this month (unfiltered for year keys).

### Processing loading (`Screens/ProcessingLoading`)
- Runs the slow filters with a progress bar, `n/total`, an ETA and Cancel (pops and cancels the task).
- It then **replaces itself** in the stack with `MonthReviewViewController` + `setPreComputedAssets`, forwarding `navigationSource` and `isFilterResultMode`.
- **Large files** removes processed assets first. **Eyes closed** (`isFilterResultMode = true`) doesn't.

### Month review — the swipe deck (`Screens/MonthReview`)
- **Init:** `(monthTitle:monthKey:mediaType:filterContext:)`. `FilterContext` is `.none`, `.screenshots`, `.largeFiles`, `.eyesClosed`, `.screenRecordings`, `.slowMotion` or `.timeLapse`.
  - Filter mode is on when `preSortedAssets` (`setSortedAssets`) or `preComputedAssets` (`setPreComputedAssets`) is set.
  - `navigationSource` (`.manual` / `.dashboard` / `.luckyPicker`) changes the empty state's action.
  - Year sessions with `.none` set the title to the current asset's month.
- **Lifecycle:**
  - **First `viewDidAppear`:** starts the undo session (`SessionKey(monthKey, mediaType)`), builds 3 recycled `SwipeCardView`s and the pan gesture, and calls `loadPhotos()`.
  - **Returning from a child:** recomputes the bin increment, prunes undo actions for deleted assets, recalculates counts from the stores, then re-advances.
  - **`viewWillDisappear`:** saves progress, cancels loading and image requests, cleans up video. When popped, it also hides the bin button.
- **Loading:**
  1. Source assets: the pre-computed ones, else the pre-sorted ones, else `fetchPhotos(month)` (oldest first).
  2. Filter by subtype.
  3. Wrap each in a `ReviewAsset` through `PhotoProcessor`.
  4. Start index: from `currentIndex`, skip processed assets. With `skipICloudPhotos` on and internet off, also skip iCloud-only assets.
  5. Then show the empty state, the completion summary, or the deck. Prefetch the next 3 at preview quality.
- **Swipe thresholds** (`+Swipe.swift`):
  - **While dragging:** the card rotates by `x / width × 0.2`. Edge gradients start after 15pt, with alpha = distance / 200.
  - **Release, distance:** 100pt; **velocity:** 800pt/s.
  - **Up** needs `y < −100` **and** an angle above **60°** from horizontal, or `vy < −800` at above 60°. A thumb's arc curves upward before going right, so a rightward arc mustn't count as up.
  - **Horizontal:** fires when `|x| > 100` or `|vx| > 800`. Direction comes from the translation sign when `|x| > 10`, otherwise from velocity.
  - **Otherwise** the card springs back (0.6 s, damping 0.7).
  - **Completing** plays a medium haptic and flies the card off-screen in 0.4 s.
- **Effects** (`advanceToNext`), each recorded in `UndoHistoryManager` with its index and size:
  - **Up (store):** `WillBeStoredStore`, adds the asset to the PhotoKit album, `storedCount++`. The first time ever, `StoreTutorialSheetViewController(storedAsset:)` shows the photo flying into a "Will Be Stored" album.
  - **Left (delete):** `DeleteBinStore`, `StatsStore.recordDeletion(mediaType, bytes)`, `deletedCount++`, and the bin shows `.increment(sessionIncrementCount)`.
  - **Right (keep):** `KeptAssetsStore`, `keptCount++`.
  - **Then:** `recordReview`, advance past processed assets, `saveProgress()`, recycle the top card to the bottom, keep the cache window at the current asset + 3. At the end, `showCompletionSummary()`.
- **Undo:**
  - **Undo button:** pops the last action, resets `currentIndex` to it and reverts its store and stats.
  - **History button:** `UndoHistoryViewController` in a sheet (medium and large), through `UndoHistoryDelegate`:
    - `didPerformAction(newType:on:)` changes an action's type. It moves the asset between stores and album, but the deck position and the review count stay.
    - `didUndoActions` / `didUndoAll` remove the actions, revert everything, and reset `currentIndex` to the earliest undone index.
- **Completion:** marks the progress key and the filter complete, then shows an alert with "Back to months" or "View Delete Bin". The second pushes the unfiltered bin and removes the deck from the stack.
- **Empty state:**
  - **Filter active:** marks the filter finished. With the dashboard or Lucky source, "Try another month" replaces the deck with a random other month. Otherwise "Clear filter" pops.
  - **No filter:** "No Photos in <month>".
- **iCloud:**
  - **Card images:** the top card loads at `.full`, the rest at `.preview`.
    - Degraded + iCloud + offline shows the "Low quality" badge.
    - No image + iCloud + offline tries a 400×400 thumbnail, then shows the `.iCloudUnavailable` placeholder.
  - **Warning sheets** (`iCloudWarningSheet`):
    - `.initial` shows once ever, when offline and the month has iCloud-only assets.
    - `.perCard` shows once ever, and again on every badge tap. Its Skip **marks the asset kept**.
    - "Enable internet" sets `allowInternetAccess` and reloads.
- **Video:**
  - `VideoPlayerController` (an 80pt play button + scrubber) embeds its layer in the top card. There's **no autoplay**.
  - The controls hide while dragging. While playing they fade to 0.5 alpha after 2 s.
- **Size badge:** shown for largeFiles, for videos, or when `isSizeBadgeOpen`.

### Similar photos (`Screens/SimilarPhotos`)
- **Inputs:** `(assets?, monthTitle?, monthKey?, mediaType)`.
  - With `assets` passed in (year sessions), it scans them as-is.
  - Otherwise it fetches the month and drops processed assets, except those `SimilarUndoStore` knows about.
  - With neither assets nor a month (dashboard), it scans the whole library.
- **Defaults:** the best photo is keep, all others delete. Each `SimilarGroupCell` ("Set #n", 240pt) scrolls horizontally with the best photo first.
  - **Tap:** cycles keep ↔ delete.
  - **Store mode:** the cell's archivebox button. Only one cell at a time; the photos wiggle; it ends after 30pt of scroll. A tap toggles a photo between store and its default.
  - **Long-press (0.3 s):** a full-screen blurred preview on the cell's `window`.
- **Confirm a group:**
  - Updates the bin, kept and stored stores (and the album), `recordDeletion`, `recordReview`.
  - `batchSave` on `"<month>_similar"` and the main month key; `markSimilarReviewActivity`.
  - Saves to `SimilarUndoStore`, keyed by a **signature**: the sorted localIdentifiers joined with `|`. Groups are restored as processed by signature after a rescan.
  - **Undo** reverses all of it. Similar doesn't use `UndoHistoryManager`.
- **Bin button:**
  - Wide "Undo All" right after a batch confirm.
  - Else wide batch-confirm (an alert with the totals, then every unprocessed group is confirmed) while unprocessed groups have deletes.
  - Else `.count`.
- **Results:** groups found → `markFilterNotFinished(.similar)`. None found → `markFilterFinished(.similar)` and an empty state.

### Delete bin (`Screens/DeleteBin`) — the only place assets are deleted
- **Data:** `DeleteBinStore` ids → `fetchAssets(withLocalIdentifiers:)`. With `filterMonthKey`, it keeps only assets from that month.
  - A grid with 3 columns in compact width, and 4 (or 6 once cells would pass 180pt) in regular width, so it splits evenly at the fold. Side insets follow the safe area and the rail. A header pill shows "N photos and M videos · ~size", with the size summed off main.
- **Edit mode:**
  - The pencil bar item ("Edit"). The filtered bin also has a "Go to general bin" bar item, with a lower `visibilityPriority`.
  - Multi-select; Remove (with confirmation) only takes items out of the bin.
  - The floating bin becomes a half-width "Delete" button through `.deleteBinEditStateDidChange`.
- **Preview:** a tap or long-press opens `MediaPreviewViewController`:
  - Remove / Undo, toggling the item in the bin.
  - "Delete now" runs the deletion immediately; only the system dialog confirms it.
- **Deletion flow:**
  1. Delete All (or Delete in edit mode) shows a confirmation alert. Deleted items go to Recently Deleted.
  2. "Preparing…" while sizes are summed, then `PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(...) }`, and iOS shows its own confirmation.
  3. **Success:**
     - `StorageAnalysisManager.invalidateAndRefresh()`, `invalidateMonthBucketsCache()`, `ReminderDataCenter.markCleanedNow(count:)`
     - remove the ids from the bin (`clearAll()` when deleting everything)
     - an "All cleaned up — you freed X" empty state
  4. **Failure:**
     - `PHPhotosErrorDomain` 3072 (the user cancelled the system dialog) is silent.
     - Other errors show an alert. Over 500 assets, it offers "Try in parts": chunks of 500.
     - A failed chunk offers Try again or "Report to developer" (`MFMailComposeViewController` to `zeynep.muslim@icloud.com` with the error, device, iOS and app version).
- **Empty bin:** the bar item and the floating bin are disabled. `viewWillDisappear` re-enables them.

### Undo history (`Screens/UndoHistory`)
- Lists the current session's actions, newest first, with a stats header. On load it removes actions whose asset no longer exists, and it dismisses itself when the list is empty.
- **Tapping a row** opens `HistoryDetailBottomSheet`: the image or video (full-screen zoom up to 4×, pan down to dismiss), plus Keep, Delete and Store.
- **Edit mode:** multi-select with a Keep / Delete / Store / Undo toolbar. Titles show in regular width or at 430pt or more, icons only below that, re-evaluated on every size change.
- **"Undo all"** asks first.
- **Undo vs change type:**
  - **Undo** removes the action and puts the asset back in the deck.
  - **Changing an action's type** keeps the deck position and the review count.

### Settings (`Screens/Settings`)
A scroll view, top to bottom:
- **Your Impact:** `ImpactStatsView` (StatsStore + stored count).
- **Storage Analysis:** `StorageAnalysisView`.
- **Photo Management:**
  - **Internet access** toggle (`allowInternetAccess`).
  - **Skip iCloud photos** (`skipICloudPhotos`), shown only while internet is off.
- **Features:**
  - **Reminders** toggle. Turning it on asks for authorization: granted schedules reminders, denied shows an alert and switches the toggle off.
  - **Schedule** menu: Daily, Weekly, Monthly.
  - **Language** card: opens the Settings app. There's no in-app picker.
  - **Store** card: the store tutorial.
- **Transparency & Safety:** the Privacy card (the read-only permission sheet) and a Transparency card that opens the GitHub repo.
- **Support:** the tip jar, Rate (`…/id6762494793?action=write-review`), and Feedback (`MFMailComposeViewController`, else `mailto:`).
- **About:** version and author.
- **Nav bar:** a heart button opens the tip jar.
- `scrollToInternetToggle()` pulses the internet toggle. Its caller, MonthReview's `openSettingsTab()`, is currently unreachable.

### Tip jar (`TipJarViewController`, `TipJarManager`)
- **Products** (StoreKit 2, consumable, `Purgio/Services/TipProducts.storekit`), sorted by price:
  - `com.zeynepmuslim.purgio.tip.small` (0.99)
  - `com.zeynepmuslim.purgio.tip.medium` (2.99)
  - `com.zeynepmuslim.purgio.tip.large` (4.99)
- **Internet gate:** with internet off, the sheet shows a `SlideToConfirmButton` gate (85% threshold).
  - Confirming calls `SettingsStore.beginTemporaryInternetOverride()`. Closing the sheet calls `endTemporaryInternetOverride()`, and Settings briefly confirms that the setting is restored.
  - StoreKit traffic doesn't depend on the app's setting. The gate is a privacy courtesy.
- **Flow:** select a tier, then "Send <price> tip".
  - **Success:** heart animation, success haptic, dismisses itself after 2 s.
  - **Cancelled or pending:** back to idle.
  - **Failure:** an alert.
- **Transactions:** `Transaction.updates` is verified and finished. Refunds are only logged.
- **Local testing:** the shared scheme doesn't attach the `.storekit` file. Select it under Edit Scheme → Run → Options.

## Floating bin button

There is **one global `FloatingBinButton`**, owned by `MainTabBarController` and added to its view. Screens never own a bin button.
- **Display modes:**
  - `.count(n)`: the plain bin count.
  - `.increment(n)`: "+n" during a review session.
  - `.wide`: "Delete All" / "Delete" on DeleteBin, or a custom title from SimilarPhotos.
  - Morph with `morphToWide` / `morphToCompact`. Counts use a monospaced digit font. The `accessibilityIdentifier` is `floatingBinButton`.
- **Screens drive it through `FloatingBinButtonController`:**
  ```swift
  private var binController: FloatingBinButtonController? { tabBarController as? FloatingBinButtonController }
  binController?.configureBinButton(mode: .count(n), monthKey: monthKey, monthTitle: monthTitle,
                                    tapHandler: { [weak self] in self?.handleBinTap() })
  ```
  - Other methods: `configureWideBinButton(title:monthKey:monthTitle:tapHandler:)`, `showBinButton()`, `hideBinButton()`.
  - Configure it in `viewWillAppear`. MonthReview and SimilarPhotos hide it when they're popped.
- **Visibility:** hidden on the Home and Settings tabs, unless the top view controller is MonthReview, MonthFilterCards, DeleteBin or SimilarPhotos (Lucky and dashboard pushes). It isn't updated during an animated transition.
- **Mode changes:**
  - `navigationController(willShow:)` morphs it to wide for DeleteBin. `didShow` morphs it back, except on DeleteBin and SimilarPhotos.
  - A tab switch resets the handler, the month context and the mode.
  - `.deleteBinCountDidChange` updates the count, except in `.increment` mode (the screen owns it) or `.wide` with a custom handler.
- **Tap routing:**
  - On DeleteBin: post `.deleteBinButtonTapped`.
  - Otherwise: the screen's `tapHandler`, or else push `DeleteBinViewController` with the current month context.
- **Placement** (`setupBinButton`, `viewDidLayoutSubviews`), height `ButtonSize.large`:
  - **iOS 26:**
    - Leading and trailing pinned to `contentLayoutGuide` ±16.
    - Two bottom constraints, switched by `isVerticalRail`:
      - `binButtonAboveTabBarConstraint`: `contentLayoutGuide.bottom − Spacer.buttonBottom`.
      - `binButtonAlignedWithTabBarConstraint`: `tabBar.bottomAnchor`, constant `−tabBar.safeAreaInsets.bottom + 8`.
  - **Before iOS 26:** pinned to `view` ±16, above `tabBar.topAnchor − 24`.
  - Compact mode activates trailing only; wide mode activates both sides.
  - DeleteBin's edit mode uses half the width minus 1.5 × 16.

## Storage analysis and Live Activity (`Managers/StorageAnalysis`)

- **What it measures:**
  - Device total and available space (`volumeAvailableCapacityForImportantUsageKey`).
  - For each photo, then each video: local bytes (`PHAssetResource` KVC `fileSize` / `locallyAvailable`), original bytes (primary resource + a Live Photo's paired video), cloud-only counts and bytes.
  - The result is `StorageAnalysisData` (Codable). Computed fields: `usedBytes`, `otherBytes`, `freshness` (fresh under 1 day, recent 1–6 days, stale 7+).
- **iCloud short-circuit:** when iCloud Photos sync is on (`checkICloudPhotosSyncStatus()` reads `/var/mobile/Media/PhotoData/CPL/syncstatus.plist` after a warm-up fetch), the per-asset scan is skipped and only basic data is saved, with `iCloudPhotosSyncOn = true`. The UI then shows an info message and hides refresh.
- **Chunks of 500**, each asset in an `autoreleasepool`. After every chunk:
  - save progress
  - update the Live Activity
  - post `.storageAnalysisDidUpdateProgress` on main with `phase`, `progress` (0–100), `current`, `total`
- **Resume:**
  - `StorageAnalysisProgress` keeps `lastProcessedPhotoIndex` / `lastProcessedVideoIndex` and **expires after 1 hour**.
  - **`refreshIfNeeded()` order:**
    1. `.notDetermined`: return.
    2. Resumable progress: resume.
    3. No cache: start.
    4. Partial cache: start.
    5. Stale cache (7+ days): start.
  - `startAnalysis()` has a 5 s cooldown and won't run twice.
  - `invalidateAndRefresh()` (after deletions) bumps `activeSessionId` so the running loop bails out, clears everything, and restarts.
- **States:** `StorageAnalysisState` is `.idle`, `.loading`, `.loadingWithBasicInfo(totalBytes:availableBytes:)`, `.loaded(data)` or `.error`.
  - Pausing saves a partial `.loaded` (`isPartial`).
  - A partial cache loads at launch as `.idle`, so the next refresh resumes it.
- **Background:**
  - A `BGProcessingTask` `com.purgio.storageAnalysis`, registered in `AppDelegate` and listed in Info.plist's `BGTaskSchedulerPermittedIdentifiers`; `UIBackgroundModes = processing`.
  - **`didEnterBackground`:** starts a UI background task and schedules the BG task.
  - **`didBecomeActive`:** cancels both and resumes.
  - **Expiry:** sets `isCancelled`, which pauses the scan.
  - **`willTerminate`:** ends the Live Activity, blocking for at most 2 s.
- **Live Activity** (iOS 16.2+):
  - **Start:** started with the scan. It needs `areActivitiesEnabled`, and any old activity is ended first.
  - **Updates:** after every chunk, with a 30 s stale date. `ContentState` holds `analyzedCount`, `totalCount`, `phase` (photos / videos / complete), `statusMessage`, `progress` and `bytesAnalyzed`.
  - **End:** dismissed 10 s after completing, immediately when paused. Stale activities are cleaned up 1 s after init.
  - **Rendering:** the `StorageAnalysisWidget` extension does it, for the lock screen and the Dynamic Island.
- **`StorageAnalysisAttributes.swift` exists as two byte-identical copies,** in `Purgio/Models/` and `StorageAnalysisWidget/`. They are separate files in two synchronized groups. **Change both together.**
- **Storage views:**
  - `StorageAnalysisView`: the full card, in Settings and the bottom sheet.
  - `StorageAnalysisLiteView`: Home's compact version, whose header switches layout under 390pt.
  - Both have DEBUG hooks: `setDebugSavedBytesOverride`, `setDebugProgress`.

## Reminders (`ReminderNotificationService`, `ReminderDataCenter`)

- **Category and actions:** category `CLEANUP_REMINDER`, with actions `CLEAN_NOW_ACTION` (foreground) and `SNOOZE_ACTION`.
- **Request ids:** `cleanupReminder.daily`, `cleanupReminder.weekly_<1-7>`, `cleanupReminder.monthly`, `cleanupReminder.snooze`, and the DEBUG `cleanupReminder.test`.
- **Scheduling:**
  - `scheduleReminders()` removes every pending `cleanupReminder*` request, then schedules **one repeating `UNCalendarNotificationTrigger`**.
  - The content comes from `ReminderDataCenter.notificationMessages(fallback:)` and is fixed at scheduling time.
  - It reschedules on `.reminderDataCenterDidChange` while reminders are on.
- **Snooze** is 3600 s, or 90 s in DEBUG. **Tap / Clean now** calls `recordReminderOpened()` and posts the Delete Bin deep link.
- **Messages:** `ReminderDataCenter` turns what the user has done into signals. Title keys are `notification.title.<signal>`, body keys `reminder.<signal>`.
  - **Time-based:** 30+ days since the last clean; 7+ days inactive; similar-photos review overdue (14+ days).
  - **Bin and savings:** the bin has items; last cleaned count; freed last time; potential savings; saved last time.
  - **Progress:** a month in progress; a streak of 3+ days.
  - **Totals:** total saved, deleted, reviewed (50+).
  - No signal means the `notification.fallback1…8` messages.

## Localization

English is the source; Turkish is translated in full. **Translate a language completely or not at all.**
- **Source of truth:** `Localization/translations.csv`.
  - Semicolon-delimited, header `DEV_KEY;en;tr;en_one;en_other;tr_one;tr_other`, about 424 keys.
  - **Never edit `Localizable.xcstrings` by hand.**
- **Build phase:** "Generate Localizable.xcstrings" runs `Localization/csv_to_xcstrings.py` and **overwrites** the root `Localizable.xcstrings`.
  - Every entry is written as `extractionState: manual`, `state: translated`, and a literal `\n` becomes a newline.
  - The phase runs **after** Resources, so a CSV change may only show up on the next build.
  - It writes into `SRCROOT`, which is why the app target has `ENABLE_USER_SCRIPT_SANDBOXING = NO`.
  - To regenerate by hand: `python3 Localization/csv_to_xcstrings.py --csv Localization/translations.csv --output Localizable.xcstrings`.
- **Keys:** `<screenOrFeature>.<camelCaseKey>`, e.g. `deleteBin.binCountTitle`, `storageAnalysis.saved`, `notification.title.binHasItems`, `widget.scanningPhotos`, `common.cancel`.
  - Keys belong to the screen they appear on. Use `common.*` (`CommonStrings`) only for genuinely shared UI.
  - Never change an existing `DEV_KEY`.
- **Call sites:** each file declares a `// MARK: - Strings` `private enum Strings` with `static let x = NSLocalizedString("<screen>.<key>", comment: "…")`.
  - **Formatted strings** are `static func`s:
    ```swift
    static func navTitle(month: String) -> String {
        String(format: NSLocalizedString("similarPhotos.navTitle", comment: ""), month)
    }
    ```
  - **Shared strings** alias `CommonStrings` (`Purgio/Others/Constants.swift`: `remove`, `cancel`, `delete`, `ok`).
- **Plurals:** leave the plain `en` / `tr` columns empty and fill `en_one` / `en_other` / `tr_one` / `tr_other`.
  - Call with `String.localizedStringWithFormat(NSLocalizedString(key, comment: ""), count)`.
  - Never build "1 photos".
- **Format specifiers:** `%@`, `%d`, `%lld`. Use positional specifiers (`%1$d`, `%2$@`) when word order differs between languages.
- **Adding a string:** add the CSV row with `en` and `tr` in the same change.
- **Byte sizes:** `Int64.formattedBytes()` (`ByteCountFormatter`, `.file`).
- **Check:** `Scripts/localization-check.sh` runs as the **Localization check** build phase, before Sources. It fails the build when:
  - an `NSLocalizedString` literal key isn't a dotted route
  - a key is missing from the CSV

  Interpolated keys (`"notification.fallback\(i)"`) are skipped. Keys used only by previews and not yet in the CSV are listed in its `ALLOWLIST`; never allowlist a key the shipping UI shows.
- **Info.plist:** the permission strings (`NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`) are English-only `INFOPLIST_KEY_*` build settings. No `InfoPlist.xcstrings` exists yet.
- **Adding a language:** see `Docs/Developer-Localization-Guide.md`. Add it in Xcode (Project → Info → Localizations), then add its CSV columns.

## DEBUG-only code

- **Dev menu:** `MainTabBarController`'s `#if DEBUG` extension, opened by shaking the device. It schedules test notifications (5 s and 60 s), shows the pending count, and has "Dev Menu Kapat" (hide until relaunch). Its strings are Turkish.
  - **That extension overrides `viewDidAppear`, so the main class body must not override it**, or the Debug build breaks.
- **Previews:** every UI file ends with `#if DEBUG` → `import SwiftUI` → `@available(iOS 17.0, *) #Preview(...)`, using `UIViewRepresentable` wrappers.
  - Preview and debug hooks: `init(previewState:)` (TipJar), `init(debugImage:)` (StoreTutorial), `configureForEmptyPreview()` (DeleteBin), and the storage views' `setDebug…`.
  - Keep preview-only code inside `#if DEBUG`.
- `ReminderNotificationService`'s DEBUG extension adds `scheduleTestNotification(afterSeconds:)` and `getPendingCount`.
- Turn on `iCloudSyncLogger` by setting `shouldLog = true` locally. Never commit it on.

## Skills

Both skills are in `.claude/skills/`, copied from Photolift and unchanged.
- **`app-resizability`:** use it for any iPhone Duo, resizable-window, Split View or Stage Manager work, and to replace `UIScreen.main`, `interfaceOrientation`, `userInterfaceIdiom`, symmetric safe-area assumptions or app-delegate lifecycle code. Its `references/` hold one task file per API. Where its defaults differ from this file, this file's rules win (e.g. the iOS 15 fallbacks).
- **`device-interaction`:** a subagent skill that verifies UI on the simulator or a device through screenshots, the UI hierarchy and synthesized touches. Use it after UI changes, on the iPhone 17 and both Duo displays. It needs Xcode's device-interaction tools. Without them, use `xcrun simctl` screenshots.

## Known issues / gotchas

These are real behaviors today. Don't build on them, and fix them only when asked. Each is worth its own change.
- **Undo can crash.**
  - The undo session key is `(monthKey, mediaType)`, so every filter session of a month shares one stack.
  - `UndoAction.index` points into the `reviewAssets` of the session that recorded it, but `handleUndo` / `didUndo*` / `didPerformAction` index `reviewAssets[action.index]` with **no bounds check**.
  - The stack also survives relaunches.
- **Swipe undo doesn't remove an asset from the PhotoKit album.** History-sheet undo and Similar undo do.
- **`StatsStore` counts swipes, not deletions.** `recordDeletion` runs on a left swipe and is reversed by undo. Real deletion in DeleteBin doesn't touch it, and doesn't clean the kept and stored stores either.
- **Dashboard and Lucky routes skip ProcessingLoading.** `.largeFiles` and `.eyesClosed` from them show the month unsorted and unfiltered. Only MonthFilterCards goes through `ProcessingLoadingViewController`.
- **Reminders ignore the user's chosen time details.** The minute is `Int.random(0...59)` and weekly reminders use one random weekday; `reminderMinute` and `reminderWeekdays` are ignored.
- **Home:**
  - It doesn't reload after the permission grant: the sheet's dismissal doesn't trigger `viewWillAppear`, and Home doesn't observe `.photoAuthorizationGranted`.
  - The dashboard card only applies freshly generated content after the user has left Home once (`hasNavigatedAway`).
- **Hard-coded English user-facing strings:**
  - `FilterStatus` raw values in MonthsList's menu
  - `FilterCard` "Finished"
  - "Skip" in `SwipeCardView` and `iCloudWarningSheet`
  - `MediaPreviewViewController` "Undo" and "Failed to load…"
  - `FloatingBinButton.morphToWide`'s "Delete All" (overridden immediately)
  - MonthReview's "Internet access enabled…" alert
  - the resume card's `formattedProgress`
  - Live Activity `statusMessage`s
  - `TipJarManager.StoreError`
  - the "Will Be Stored" album name
- **Settings shows version "1.0" hard-coded** instead of `CFBundleShortVersionString` (the real version is 1.1).
- **DeleteBin** prints `[BIN DEBUG]` / `[BIN SYNC]` lines in `numberOfItems` / `cellForItem` without `#if DEBUG`.
- **Screens outside the Duo work pin their horizontal edges to `view` instead of the safe area** (sheets, Settings, MonthsList's permission and empty states, ProcessingLoading, Onboarding; see **iPhone Duo**).
- **`PHPhotoLibraryPreventAutomaticLimitedAccessAlert` isn't set,** so iOS may show its own "select more photos" alert.
- **Storage analysis:**
  - The resume indices can point at different assets if the library changed in between.
  - `chunkSize = 500` is declared twice.
  - `cancelAnalysis()` and `performBasicOnlyAnalysis()` have no callers.
- **`ReviewProgressStore` / `MonthFilterStatusStore`** fall back to `NSTemporaryDirectory()` when Documents is unavailable.
- **`SimilarPhotosViewController`** uses the legacy `PHPhotoLibrary.authorizationStatus()` without `.readWrite`.
- **`MonthStatItemView`'s previews** sit outside `#if DEBUG`.
- **Tracked user files:** `xcuserdata/` and `UserInterfaceState.xcuserstate` are tracked despite `.gitignore`. Never stage changes to them.

## Code style

- 4-space indentation.
- **Classes:** `final class` by default; non-final only when subclassed or overridden from an extension. `private` by default; `private(set) var` for read-only state.
- **Sections:** `// MARK: - Section` (Lifecycle, Setup, Actions, Data Loading, Notifications, Strings, Preview). Each protocol conformance goes in its own `extension X: Proto` under `// MARK: - Proto`.
- **Errors:** no `try!`. `fatalError` only in `init(coder:)`. `as!` only for cell dequeues and `layerClass` casts. Prefer `guard let` over force-unwraps and IUOs.
- **Logging:** `print("[TypeName] message")`. Keep noisy logs in `#if DEBUG`.
- **File headers:** the Xcode template (`//  Name.swift`, `//  Purgio`, `//  Created by …`).
- **Shared extensions:** helpers go in `Others/Extension++.swift` (`Int.compactFormatted`, `Int64.formattedBytes()`, `UIView.spacer`, `UIImage.resized(to:)`). Type extensions go in `Type+Topic.swift`.
- **Commits:** English, lowercase conventional prefixes (`fix:`, `refactor:`, `feat:`), a short subject, and an optional body explaining why.
- Never hard-code user-facing strings. See **Localization**.

## Building and testing

- **Project:** Xcode project `Purgio.xcodeproj`, objectVersion 77, no Swift packages.
  - **File-system synchronized groups:** new `.swift` files under `Purgio/` or `StorageAnalysisWidget/` join their target automatically. Build phases and frameworks still live in the pbxproj.
  - **Schemes:** `Purgio` (app) and `StorageAnalysisWidgetExtension`.
  - **Frameworks** linked explicitly in the app target: StoreKit and PhotosUI (keep it). The widget links SwiftUI and WidgetKit.
  - **App target build phases, in order:**
    1. Forbidden API check
    2. Localization check
    3. Sources
    4. Frameworks
    5. Resources
    6. Embed Foundation Extensions
    7. Generate Localizable.xcstrings
- **`xcode-select` may point at CommandLineTools.** Build with the installed Xcode, which has the iOS 27.1 SDK for the Duo APIs:
  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    xcodebuild -project Purgio.xcodeproj -scheme Purgio \
    -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
  ```
- **The checks run by hand:** `Scripts/forbidden-api-check.sh` and `Scripts/localization-check.sh`.
- **There is no test target and no linter.** Verify a change by building it and running it in the simulator.
  - UI changes: the iPhone 17 and both iPhone Duo displays, in light and dark (see **iPhone Duo → Verifying**).
  - Deployment-target-sensitive code also needs a check on the oldest simulator runtime you have.
- **Simulator limits:** the simulator has no iCloud Photos, so iCloud paths need a device with Optimize iPhone Storage on. Live Activities and background tasks are best checked on a device.
