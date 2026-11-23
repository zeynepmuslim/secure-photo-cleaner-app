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
- **Large view controllers are split into `+Feature.swift` extensions:** `MonthReviewViewController+DataLoading/+Swipe/+UI/+Video/+Helpers/+UndoHistory/+Fold/+Landscape/+TablePose/+EndStates`, and `StorageAnalysisManager+ChunkedAnalysis/+BackgroundTasks/+AppLifecycle/+LiveActivity`.
  - Members used across those files must be `internal`, not `private`.
- **Navigation:**
  - The 4 tabs live in `MainTabBarController`, each in its own `UINavigationController`. **The tab indices are fixed and used across screens:** 0 Home, 1 Photos (`MonthsListViewController(mediaType: .image)`), 2 Videos (`.video`), 3 Settings.
  - Code that jumps between tabs sets `selectedIndex`, calls `popToRootViewController`, and then pushes (see Home's `navigateOnTab`).

### Components
- Components are programmatic `UIView`, `UIControl` or `UIButton` subclasses.
  - `init(frame:)` calls a private `setupUI()` / `setupButton()`.
  - `required init?(coder:)` is `fatalError("init(coder:) has not been implemented")`.
- **Callbacks are closure properties named `onX`,** e.g. `onRefreshTapped`, `onDismiss`, `onTap`, `onICloudBadgeTap`, `onEnableInternet`.
  - The only delegate protocols are `FloatingBinButtonController` and `UndoHistoryDelegate`. All are `AnyObject` and held `weak`.
  - Don't add delegates where a closure works.
- **Configuration API shapes, in order of preference:**
  1. `configure(...)` with labeled parameters and defaults, e.g. `FilterCard.configure(icon:title:tintColor:style:)` and `EmptyStateView.configure(icon:iconColor:title:message:actionTitle:onAction:…)`.
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
| `DateFormatterManager` | Cached formatters: `yyyy-MM` (en_US_POSIX), `MMMM yyyy`, `MM.yyyy`, short time, `dayMonthTime` ("12 Oct, 18:30", localized template `dMMMjmm`), `monthName(fromMonthKey:)` ("August", nil for year keys) |
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
| `.photoAuthorizationGranted` | `PhotoLibraryService` | AskPermission, MonthsList's "Allow access" → PhotoLibraryService, StorageAnalysisManager, MonthsList | — |
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
  - Views re-apply in `layoutSubviews()`, e.g. `StorageAnalysisLiteView.applyHeaderLayoutVariant()`, `DashboardCard.applySizeVariant()` and `FilterCard` (how much of its text fits its own height).
  - View controllers configure in `viewDidLayoutSubviews` or `viewWillAppear`, either behind a once-flag (`didSetupLayout` in Onboarding, `didConfigureForSize` in TipJar and SimilarPhotosHelpSheet) or re-applied whenever the value changes (`appliedToolbarShowsTitles` in UndoHistory).
  - **Compact variants follow the view's own width**, not the window's, so they follow display, column and Split View changes:
    - Cards compare `bounds.width` with `GeneralConstants.CompactContentWidth`: `fullWidthCard` (350) for full-width cards (`DashboardCard`, `StorageAnalysisLiteView`, `StorageAnalysisView`'s legend), `halfWidthCard` (167) for two-up cards (`FilterCard`'s `.link` style). Both are calibrated so 375pt iPhones get the compact look and 390pt+ the regular one.
    - UndoHistory's toolbar shows titles only when the widest one fits a button of the toolbar's own width.
  - Sheet detents still read `view.window?.bounds ?? view.bounds`: `<= 667` tall gets large detents.
- **Scale** comes from `traitCollection.displayScale`.
  - On iOS 17+, re-render thumbnails with `registerForTraitChanges([UITraitDisplayScale.self])`.
  - `ImageCacheService`'s overloads without `traitCollection:` are `@available(*, deprecated)` shims. Don't use them in new code.
- **Edge paddings 16, 18 and 20 are deliberately different.** Name each by its role and never merge them:
  - **20:** screen content (`GeneralConstants.EdgePadding.content`: Home, MonthReview card and controls, DeleteBin buttons, MediaPreview, sheet titles)
  - **16:** floating controls and sheet content (`GeneralConstants.EdgePadding.medium`: the bin button, LuckyPicker, UndoHistory, HistoryDetail)
  - **18:** Settings rows and cards' inner padding (`SettingsViewController`, `SettingsInfoCardView`, `SettingsLinkRowView`, `DashboardCard`, `StorageAnalysisView`), and the clearance from the device corner opposite a trailing rail
- **Tokens:** use `GeneralConstants` (`Purgio/Others/Constants.swift`) instead of new literals:
  - `EdgePadding.small` 10, `EdgePadding.medium` 16, `EdgePadding.content` 20, `EdgePadding.cardInner` 18 (cards' inner padding). Values are positive; apply the edge's sign at the constraint.
  - `CornerRadius.card` 16
  - `CompactContentWidth.fullWidthCard` 350, `CompactContentWidth.halfWidthCard` 167
  - Vertical rail (`DuoLayout.RailPadding`, `Purgio/Others/DuoLayout.swift`): `nextToRail` 6, `bottom` 20, `cornerClearance` 18
  - `ButtonSize.small` 30, `medium` 44, `mediumLarge` 50, `large` 56
  - `Spacer.buttonBottom` 24, `Spacer.foldGap` 12 (clearance from the Duo fold region on either side: MonthReview, TipJar)
  - `TipCapsule` (the tip jar's vertical capsules): `width` 72, `minimumWidth` 44, `maximumHeight` 200, `spacing` 10
  - `ActionGrip` (MonthReview's sideways grips and table-layout trays): `width` 104 (corner radius is half), `inset` 8, `storeSegmentHeight` 120, `trayCornerRadius` 44 (segments inside a tray use 44 − `inset`), and the shared tray shadow `Shadow.opacity` 0.07, `offsetY` 8, `radius` 12
  - `BulkYear.sparseYearThreshold` 50
  - `LargeFile.photoHighlightBytes` 20 MB and `videoHighlightBytes` 150 MB (decimal, as `formattedBytes()` shows them): what the filter loading screen counts as "Over 20 MB" / "Over 150 MB". Not a filter; Largest First still shows every item.
  - `BinSlot.compactWidth` 96 (the bin's slot beside a bottom row's primary button)
  - `LegendCapsule` (the storage cards' legend and status marks, radius width / 2): `width` 5, `height` 12; `rowWidth` 6 / `rowHeight` 22 for the storage sheet's ledger rows; `LegendGrid`: `columnSpacing` 12, `packedItemSpacing` 16

  If a value has no token yet and repeats, add the token first.
- **Corners:** every rounded corner sets `layer.cornerCurve = .continuous`. Pill buttons use `config.cornerStyle = .capsule`.
- **Lists:** classic data source / delegate with string reuse IDs.
  - `UITableView`: MonthsList and UndoHistory (`.insetGrouped`).
  - `UICollectionView` with a flow layout: DeleteBin grid, `SimilarSetCardView`'s photo row, StoreTutorial.
  - `UICollectionView` with a compositional layout, self-sizing cells and a diffable data source: SimilarPhotos' list (see **Similar photos**). New lists may use them (they need no newer OS).
  - Settings is a `UIScrollView` + `UIStackView` (two of them, one per pane, split at the Duo's fold).

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
    - **The one exception:** while the inner display is fully open sideways, `EmptyStateView`'s centered group may cross the fold line. The fold isn't a gap there, and the group splits away from it as soon as `activeFold` appears. Nothing else may.
    - Home: storage plus the Photos/Videos tiles on one side, the dashboard on the other.
    - MonthsList: sideways the list on the left and the selected row's hub on the right; upright the hub on the raised half and the list on the base (see **Months list**).
    - MonthFilterCards: the progress overview on one side, the four filters plus All Photos on the other. Sideways the Continue pill sits under the overview, and All Photos and the filters are one per row (All Photos first) with the bin's full-width slot under them, level with the pill; upright the All Photos row sits over the filters' 2×2 tiles on the base, with the pill and the bin's slot along the bottom (see **Month filter cards**).
    - MonthReview (`+Fold.swift`): a vertical fold splits the undo/history row (undo ends before the fold, history starts after it). In the table layout (`+TablePose.swift`; the table pose, and the upright inner display fully open) the stats and the card sit above the base: partly folded they end at the horizontal fold and the base below it holds the saved trackpad/keys choice; fully open the deck takes about 70% and the keys 30%; in the book pose the video play button moves to the larger side of the fold. Held sideways (`+Landscape.swift`), the bottom row splits at the fold (Undo + History before it, the bin button's slot after it) and the video controls split into two capsules there.
    - SimilarPhotos (`+Fold.swift`): sideways the sets in pairs, one on each side of the fold, with the bottom row under the second column; upright the summary card and a spotlight set on the raised half, the other sets and the bottom row on the base (see **Similar photos**).
    - ProcessingLoading (`+Fold.swift`): sideways the filter's glyph and name in the leading half, the meter and the bottom row in the trailing half; upright the filter on the raised half, the meter and the bottom row on the base (see **Processing loading**).
    - DeleteBin: a vertical fold splits the grid into two equal halves on either side of the fold line (`FoldSplitFlowLayout` widens the gap there). The half with less room sets the cell size, so the other side gets a wider margin.
    - The wide "Delete All" bin button keeps to the trailing side of the fold in the book pose.
    - Settings: sideways two columns, the impact tiles, Storage and Support on one side and the settings groups and About on the other; upright a raised half (impact tiles, then Storage | Support in one row) over a base with the settings groups and About. Each pane scrolls on its own (see **Settings**).
    - Split controls the same way Home splits content: use `splittingFold` so they don't jump when the device folds, center the gap on the fold line while fully open, and clear the whole fold region (`activeFold`'s width) while folded.
- **Detecting the tab rail:** no API reports where the tab bar sits (`mode` and `sidebar.preferredPlacement` don't), so use geometry, evaluated in `viewDidLayoutSubviews`. `DuoLayout` wraps it:
  - `isVerticalRail(tabBarController)`: the tab bar is taller than wide.
  - `isDuoDisplay(_ window:)`: either Duo display, from the window's traits and safe area (regular width, or compact width with a horizontal safe area). The tip jar's detents and `PrivacyShieldArtView`'s phone use it.
  - `railSide(_:in:)`: the physical side (`.left` / `.right`). The rail sits on the app's outer edge: right on the full display, left in Split View on the left half.
  - `railEdge(_:in:)`: the same as a layout edge (`.leading` / `.trailing`), for leading/trailing constraints.
- **Bar items are standard titled `UIBarButtonItem`s, never `customView`s.** The system can then move them into the vertical bar or the overflow menu. Give every item a `title`, even when it shows an image. Shared items live in `UIBarButtonItem+Common.swift` (`.helpItem`, `.luckyItem`, `.tableLayoutItem`). Set `visibilityPriority` (iOS 27.1) on screens with more than one item, so the frequent action overflows last.
- **Horizontal edges come from the safe area, never the superview.**
  - Every view a view controller adds to `view` pins its sides to `view.safeAreaLayoutGuide.leadingAnchor` / `trailingAnchor`, never to `view.leadingAnchor` / `trailingAnchor`.
  - Portrait iPhones can have a horizontal safe area: the Duo's 84pt camera strip.
  - **Exception — sideways-scrolling content spans the full width.** A collection view or scroll view that scrolls sideways pins to `view` and lets the safe area inset its content, so items rest inside it and scroll under the camera.
    - Set `contentInsetAdjustmentBehavior = .always`. With `.automatic` the trailing inset stayed 0 on the Duo.
    - For a compositional layout's `.continuous` sections, leave `contentInsetsReference` at its default; with `.none`, the last item rests under the camera.
    - A vertical scroll view that holds a sideways row also spans the full width. Pin its content's sides to `view.safeAreaLayoutGuide`, and set the `contentLayoutGuide` width to the `frameLayoutGuide`'s.
  - **Exception — a page sheet that covers the tab bar and the side bar spans the full width** (the tip jar, onboarding, the Similar photos help sheet). The camera strip's safe area doesn't apply there: its column is centered with its side padding (`EdgePadding.content` in the tip jar, 24 in the help sheet), and only rows the camera itself overlaps (`reservedRegions(kind: .occlusion)`) narrow, evenly on both sides, through constraint constants (`updateOcclusionClearance`).
  - **Exception — full-screen decoration spans the full width.** Artwork, gradients and backgrounds with nothing to read or tap pin to `view`, e.g. the iOS 26 top gradient in MonthsList. Text and controls drawn over them still follow the safe-area rule.
  - Home, MonthFilterCards, ProcessingLoading, MonthReview, DeleteBin, SimilarPhotos and Settings follow this rule. Other screens still pin to `view.leadingAnchor` (see **Known issues**); bring every screen you touch up to it.
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
- **Card corners follow the device corner on the rail.** `UIView.updateCardCorners(followingDeviceCorner:)` (`UIView+CardCorners.swift`, iOS 26+) gives every corner the standard 16, except a bottom corner that sits in the window's bottom corner, which becomes container-concentric. Call it after layout, with `followingDeviceCorner` set to whether the rail shows. Home (dashboard and Photos/Videos tiles), MonthFilterCards and Settings (the support card, held sideways) use it. Buttons in such a card's bottom corner follow it too: `SettingsSupportCardView.updateLinkCorners()` gives a link button's outer bottom corner the card's `effectiveRadius(corner:)` minus the padding (at least 12); `containerConcentric` would resolve against the window, not the card.
- **These rules and the `app-resizability` skill** (see **Skills**) are the guide for any layout or bar change.
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
| `#available(iOS 26.0, *)` | Liquid Glass: `.prominentGlass()` / `.glass()` button configurations, `UIGlassEffect` (VideoPlayerController's split capsules), clear sheet backgrounds, MonthsList's top gradient, the bin button's `contentLayoutGuide`, card corners (`cornerConfiguration`, `effectiveRadius(corner:)`), Settings panes' `topEdgeEffect.style` |
| `#available(iOS 27.1, *)` | iPhone Duo APIs: `reservedRegions` (`FoldRegion`), `visibilityPriority` (see **iPhone Duo**) |

- **Liquid Glass buttons:** on iOS 26 use `UIButton.Configuration.prominentGlass()` / `.glass()` with `tintColor`. Before iOS 26 fall back to `.filled()` / `.gray()` with `.capsule`.
  - `DynamicGlassButton` wraps this: `configure(title:…style: .prominent|.regular, backgroundColor:…)`, and `animateConfigure(...)` cross-dissolves. Disabled is alpha 0.5 via `configurationUpdateHandler`. It is the general-purpose button; use it for new buttons.
- The deprecated `traitCollectionDidChange` + `hasDifferentColorAppearance` is still used to refresh `CGColor`s in AnalysisProgressRing, MiniProgressRing, SlideToConfirmButton, SoapBubble (unused), MonthReview+UI, Settings and ProgressiveBlurView (its fade colors), and as the iOS 15/16 path in DecisionRingView and MonthFilterCards (Continue pill).
  - On iOS 17+ prefer `registerForTraitChanges([UITraitUserInterfaceStyle.self])`, keeping the old path for iOS 15/16.

## Design system

- **Colors come from `Purgio/Resources/Assets.xcassets`** through the generated asset symbols (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`).
  - Common: `.mainBackground`, `.cardBackground`, `.reviewCardBackground`, `.textPrimary`, `.textSecondary`, `.textTertiary`.
  - Media accents: `.photo100` / `.photo50` and `.video100` / `.video50`. Photo filters use `photo100`, video filters `video100`.
  - Storage: `.storageUsed`, `.storageFree`, `.storageAvailable`, `.storageOther`, `.storageSavedBar`, `.storageSavedLabel`.
  - Tip jar: `.tipJarRed100`.
  - Palette: `.blue100`, `.green100/200`, `.red100/200`, `.yellow100/200`.
  - Every colorset is a light/dark pair.
  - New colors: add a colorset with both appearances, then use its symbol.
  - Unused colorsets: `TextTertiaryReverse`, `purple100`, `StorageUsed 1` (a duplicate), and `ProgressCompleted` / `ProgressInProgress` (the old month-row fill).
- **System colors** (`.label`, `.systemBlue`, `.systemGreen`, …) are widely used and allowed.
  - `ThemeManager.Colors.statusRed/Green/Yellow` return `.systemRed/Green/Yellow`. Use them for delete, keep and store semantics.
- **Delete / keep / store colors:**
  - Delete is red (left edge gradient).
  - Keep is green (right).
  - Store is yellow (top).
  - Icons: trash, checkmark, archivebox.
- **Fonts:** `ThemeManager.Fonts` (`Purgio/Others/ThemeManager.swift`).
  - **Titles** use SF Pro (the system font) through `titleFont(size:weight:)`; don't use other font designs: `display` 32 bold, `boldTitle` 24 bold, `semiboldBody` 16 semibold.
  - **Captions:** `regularCaption` / `semiboldCaption` (13), `thinBody` (17 thin). Body text is `.systemFont(ofSize:weight:)`.
  - **Counters** use `monospacedDigitSystemFont`.
  - `ThemeManager.configureNavigationBarAppearance()` runs first in `AppDelegate`. It sets title fonts: large 34 bold, inline 17 semibold.
  - `ThemeManager` has no theme switching, and `ThemeManager.shared` is unused.
  - **There's no Dynamic Type support yet**: no `preferredFont`, `UIFontMetrics` or `adjustsFontForContentSizeCategory` anywhere. Don't make it worse; new text should still fit when it wraps.
- **Haptics:** only through `HapticFeedbackManager.shared`.
  - `impact(intensity:)`: `.medium` for navigation and swipes, `.light` for secondary taps.
  - Also `success()`, `warning()`, `error()`, `selection()`, and `prepareAll()` before swipe sessions.
- **Animation:** `UIView.animate`.
  - Morphs use a spring (0.4 s, damping 0.75, velocity 0.8). Fades take 0.25–0.3 s.
  - No `UIViewPropertyAnimator` or `CADisplayLink`.
- **Reusable components** (`Purgio/Components`, `Purgio/Views`):
  - Buttons: `DynamicGlassButton`, `FloatingBinButton`, `CloseButton` (44×44), `ActionGripView` (MonthReview's sideways Store + Delete/Keep column), `TablePoseKeysView` (MonthReview's table-layout Store key over Delete | Keep). Store / Delete / Keep segments share `UIButton.Configuration.actionSegment(title:systemImage:iconSize:iconColor:cornerRadius:)`.
  - Controls: `TablePoseTrackpadView` (MonthReview's table-layout swipe pad: `panGesture`, a mini gray box (`.systemGray5`, thin `.systemGray3` border) at the top card's aspect ratio via `setPreview(aspectRatio:identifier:)` / `setPreviewTransform(_:cardWidth:)`, VoiceOver custom actions).
  - Bar items: `UIBarButtonItem.helpItem(target:action:)`, `.luckyItem(title:target:action:)` and `.tableLayoutItem(title:layout:menu:)`.
  - Cards and rows: `FilterCard` (a tappable card in a style the screen picks, never its size: `.link` is Home's Photos / Videos tile (icon, title, chevron; tall from 110pt with `allowsTallVariant`); `.tile` is the month hub's filter tile: the icon and a `ReviewCapsuleView` in the top row, and at the bottom the title (no subtitle: the names say what the filters do) right above a 12pt status resting on the bottom edge, so neighbors' statuses line up and the free height sits under the top row; `.row` puts icon, title, then status, capsule and chevron on one line. `setProgress(deleted:kept:stored:total:reviewed:isFinished:)` feeds the capsule (progress only, in one ink color; the split lives on the overview card) and the status ("N% reviewed", a green "All caught up", "Not started"; the finished flag wins). In `layoutSubviews` the title gets the lines it needs (two at most) when the card's own height holds them, never shrunk to fit; a tile too short for a two-line title under the top row packs tighter (12pt insets, the title beside the capsule's lower end). One VoiceOver element, "title, status"; `setStyle(_:)` switches tile ↔ row), `DashboardCard`, `SwipeCardView`, `MonthStatItemView`, `ImpactStatsView`, `SettingsInfoCardView`, `SettingsLinkRowView`, `TipTier` (a vertical capsule whose height shows the amount, name and price under it; gray with a red icon, solid red when chosen; the row hands every tier the same area through `setCapsuleSize(width:areaHeight:)` and each takes `heightRatio` of it, bottom-aligned), `FakeAlbumCell`, `ReviewStatsPillView` (reviewed/total, a black (`.label`) progress bar and the three counts), `MonthProgressRowView` (`Screens/MonthsList`; the month and sparse-year row, board PM3: a `ReviewCapsuleView` in a 24pt slot, 12pt to the title over the state's subtitle (count chips that wrap between chips, the cell's not-started text, or a green "All caught up!"), and the number left over "left" or a decorative Done pill; `configure(title:titleFont:deleted:kept:stored:total:reviewed:notStartedSubtitle:)`, `reset()`, `accessibilitySummary` for the cell's VoiceOver label).
  - Progress: `SegmentedBarView` (a capsule bar: radius height / 2, clips its segments and anything added on top; segments have no rounding of their own, 2pt separators, a non-zero segment is at least 4pt wide (taken from the largest), `segmentStartX(at:)` for overlays), `CircularProgressView`, `MiniProgressRing`, `AnalysisProgressRing`, `DecisionRingView` (a ring split by choice: delete red, keep green, store yellow, left `.systemGray5`, from 12 o'clock with gaps, zero arcs skipped; stroke 0.09 × diameter; the reviewed percent in the center, a green checkmark at 100%, "–" while the total is 0; `configure(deleted:kept:stored:total:reviewed:animated:)`), `ReviewCapsuleView` (a vertical capsule, 12×40 by default; at any other size its gaps, outline, minimum segment and check scale with its width (22×128 in `ProgressSummaryCardView`, a fifth of its height in `ProgressOverviewView`): a dashed `.systemGray3` outline before it's started; a bottom-up delete / keep / store / left (`.systemGray5`) fill with 1pt gaps, a non-zero segment at least 3pt tall (taken from the largest), zero segments skipped; finished, the stamp (`ReviewStampView`, a 10pt capsule at the standard size); `stampCheckBorderColor` passes through to it; with `alwaysShowsSplit` (the hub's overview cards) a total always shows the fill, all gray before it's started and the full split once finished, and the dashed outline only means no total yet; with `usesSingleProgressColor` (`FilterCard`) the in-progress fill is one `.label` segment for everything reviewed over the gray rest, no delete / keep / store split; drawn with layers (`CAShapeLayer`s for the outline); `configure(deleted:kept:stored:total:reviewed:)`, `reset()`), `ReviewStampView` (the stamp on its own: a green capsule with a white check rotated −8° and wider than the capsule (it doesn't clip), or a dashed outline; attributes, all settable at any time: `status` (`.done` / `.notStarted`), `capsuleWidth` (nil fills the view), `checkSize` (nil is 2.2 × the capsule's width), `capsuleColor`, `checkColor` and `checkBorderColor`, the check's border: nil is the capsule's green in light mode and `.cardBackground` in dark mode, where the bright green alone doesn't hold a white check; a stamp on another surface passes that surface for dark mode, as `EmptyStateView` does with `.mainBackground`).
  - Controls and players: `SlideToConfirmButton`, `VideoPlayerController`.
  - `MonthLinkCardView` (`Purgio/Views`): a month's `MonthProgressRowView` in a tappable card with a chevron; `configure(title:monthKey:mediaType:liveTotal:)` shows the month's stored progress (false without a total; `liveTotal` for a month with no record yet), `onTap`. The empty Delete Bin and the months list's empty state use it.
  - `AccessStatusCardView` (`Purgio/Views`): how much of the library Purgio sees, as a card: a `LegendCapsule` mark beside the level's title (15pt semibold) over a wrapping text (13pt), and optionally a full-width gray `DynamicGlassButton` (`.regular`, 50pt) under them. `configure(status:text:buttonTitle:onButton:)`; `status` (`.full` green, `.limited` yellow, `.notAsked` gray, `.off` red) sets the color and the title, a nil `text` is the level's standard one, and `limitedText(itemCount:)` / `allowFullAccessTitle` are the limited level's. The mark, title and text are one VoiceOver element, the button its own. Reuse it wherever an access level shows (only MonthsList today).
  - `ActionRuleCapsuleView` (`Purgio/Components`): an undo action's mark, a 24×38 capsule in the action's color holding its symbol (trash / checkmark / archivebox, no circle) in the action's ink (`UndoAction.ActionType.displayInk`: black on yellow, white on red and green, in both appearances). `configure(type:color:)`, `symbol(for:)`. The Undo History rows and the detail sheet's title row use it.
  - `PhotoGrowPresenter` (`Purgio/Views`): grows an image out of a view into a large rounded photo over a blur on the window, and a tap anywhere shrinks it back. A plain class the host owns, not a singleton. `present(in:image:aspectRatio:sourceCornerRadius:maximumSide:accessibilityLabel:availableRect:sourceFrame:)`: `sourceFrame` returns the source's frame in window coordinates and is asked again when shrinking (the source can move; nil shrinks without animation); `availableRect` is the room (the safe area by default, `EdgePadding.content` kept clear). The blur animates to `.systemThinMaterial`, frame and corner radius spring (0.4 s, 0.75, 0.8) to `grownCornerRadius` (`CornerRadius.card` × 1.5), a light haptic; back in 0.3 s ease-in-out. With Reduce Motion a 0.25 s cross-fade. For VoiceOver the overlay is modal, the photo is one element and the escape gesture closes it. Closures: `onWillShow` / `onDidDismiss` (hide and show the source), `onDidShow` (the spring ended), `onWillDismiss` (remove what the host added), `onImageTap` (a tap on the photo, instead of shrinking). `showsCloseButton` adds a `CloseButton` in the safe area's top leading corner (a photo that would reach under it starts below it). The grown photo follows the window: it is placed again whenever the overlay lays out (rotation, cover ↔ inner display) or the host calls `relayout()` (the history sheet does, from `viewDidLayoutSubviews`, for fold changes), and `onLayout` lets the host move what it added. `overlayView` and `imageView` let the host add controls and a player layer; `setImage(_:)` swaps in a sharper image. The host calls `dismiss(animated: false)` when the source leaves its window. Used by `PrivacyShieldArtView` and `HistoryDetailBottomSheet`; grow a photo with it, never with a separate full-screen viewer.
  - Helpers: `UIViewController.replaceInNavigationStack(with:animated:)` (`Others/UIViewController+Navigation.swift`) swaps the top screen for another; `FilterType.continueTitle(monthKey:mediaType:)` (`FilterType+Route.swift`) is the end states' "Continue" title (no count: the "Keep going" list shows the progress), nil once the month is complete.
  - Views: `GradientView`, `EmptyStateView` (the empty and finished states, see **Empty and finished states**), `MonthNextStepsView` (their "Keep going in <month>" list: a label over a card of the month's open filters as `FilterCard` `.row`s, at most three, All Photos last; `configure(monthTitle:monthKey:mediaType:excluding:)` returns false when nothing is left or the key is a year; `onSelect`), `ReviewSplitCardView` (a finished month's split: a `SegmentedBarView` over delete / keep / store items, icon, count and name, the names hiding in `layoutSubviews` when the row is too narrow; one VoiceOver element; `configure(deleted:kept:stored:)`), `PaddingLabel`, `SoapBubble` (unused since the photo access sheet's redesign; only its file is left, and its `photo1…7` assets now feed `PrivacyShieldArtView`), `PrivacyShieldArtView` (the photo access sheet's art, board "Photo access sheet · frame, line and lock": a drawn phone of the device the app runs on, at real proportions, as large as fits inside the line's room (a 1pt `.systemGray2` metal band, a thin black bezel, true-size island and notch; the Duo cover nearly square along the hinge with its round camera, the inner display with the fold line, and the 84pt status strip down the right edge, or along the top while upright; partly folded (`FoldRegion.activeFold`), the inner phone shows folded: a snapshot of the flat art (`layer.render(in:)`, so it draws with shape layers, never masks) cut in two halves turned around the hinge in perspective, a book in the book pose and a laptop in the table pose; home button, notch, Dynamic Island, Duo cover, Duo inner upright or sideways, read from the window's safe area, size class and aspect on every layout pass, never the screen) holding the seven bundled sample photos as tiles (`photo1_large`…`photo7_large` in `AskPermissonBubble`, the old soap bubble's; never PhotoKit: it shows before access), each drawn already cut to its shape (`renderTile(at:)`, no mask): a tile corner in a screen corner takes the screen's radius minus its inset so it stays concentric, the rest a small radius; a tap on a photo (an easter egg: they're the developer's photos) grows it out of its tile into a large rounded square (420pt at most) over a blur on the window through `PhotoGrowPresenter`, and a tap anywhere shrinks it back; partly folded, the tap is traced through the tilted halves back to the flat art (`tileIndex(at:)`), the photo grows from where its half shows it, and the halves are redrawn without it while it's open; a 2pt `.systemGreen` line (one `CAShapeLayer`, round caps and joins) 20pt around the phone's frame, each corner the body's radius + 20 so it stays concentric (the Duo cover's hinge and outer corners too), an open path with a 36pt break at the bottom center, and a 21pt semibold `lock.fill` in `.systemGreen` centered on the line's bottom edge in the break, with nothing behind it; the line and the lock sit in the flat view the folded snapshot renders, so they fold with the phone (in the book pose the lock sits on the hinge; in the table pose the phone is sized from the folded drawing's real extent, perspective included (`layoutArtForTablePose`), so the laptop fills the bounds and its bottom line reaches their bottom edge, just above the fold); nothing else animates; hidden from VoiceOver), `ProgressOverviewContentView` (what both month-hub overview cards show, `init(style: .card / .display)`: a split `ReviewCapsuleView` with `alwaysShowsSplit` and, 16pt beside it (24 in `.display`), a column with two rows pushed apart: on top "Left" (13pt) over the number left (40pt heavy) with the percent reviewed (22pt heavy) over "8 / 92" (12pt) on the trailing side, and at the bottom Delete, Keep, Store spread across the column, each a colored trash / checkmark / archivebox icon, the count (15pt bold) and the name (13pt); in `layoutSubviews` the names hide, leaving icon + count, when the three items don't fit the row's own width (iPhone SE, long counts); `.display` uses 64 / 28pt numbers; "–", "–", "– / –" and zero counts while the total is 0; `accessibilitySummary` (`filterCards.overviewAccessibility`) is the host's one VoiceOver label; `update(with: ProgressOverviewState)`), `ProgressOverviewView` (MonthFilterCards' inner-display card: the `.display` content centered in the card, its capsule 42% of the card's height (at most 220pt) tall and a fifth of that wide; the content hugs its rows, so the card hands it `maximumContentWidth` in `layoutSubviews` to decide whether the names fit; one VoiceOver element; `update(with: ProgressOverviewState)`), `ProgressSummaryCardView` (MonthFilterCards' one-column overview card: the `.card` content with 18pt inner padding, a 22pt-wide capsule as tall as the content (128pt); `isCompact` (a short column, iPhone SE) drops to 12pt padding, a 32pt number and a content only as tall as its two rows, and `regularHeight` (164) is what the hub measures against; one VoiceOver element; `update(with: ProgressOverviewState)`), `ImpactTilesView` (Settings' split layouts: space saved / stored items / reviewed as three equal tiles, icon then number then a one-line title that shrinks to fit (a second line would push the cards under it off the fold and the baseline); `configure(spaceSaved:storedCount:reviewedCount:)`), `SettingsSupportCardView` (Settings' split layouts: the support text, the ink tip button (`.label` fill, red heart), and Rate | Feedback always side by side, a title wrapping to a second line when it doesn't fit half the card; `onTip`, `onRate`, `onFeedback`), `SettingsGroupView` + `SettingsGroupRowView` (Settings' split layouts: a grouped-list card of rows laid out like the cards: a colored icon glyph (no tile) and the title on one line, an optional subtitle under both and a `.toggle` / `.navigation(_:)` / `.value(_:_:)` / `.menu` / `.text` accessory, where the `Destination` sets the indicator: `.push` chevron right, `.sheet` chevron up, `.external` (leaves the app: the Settings app, GitHub) arrow up-right, and a menu shows the up-down chevron; `setRow(_:hidden:animated:)` keeps the first visible row's separator hidden; tappable and text rows are one VoiceOver element, toggle and menu rows label their control with the row's title), `ProgressiveBlurView` (over a scroll view's top edge, or its bottom with `edge = .bottom` (SimilarPhotos' bottom row): content scrolling under it blurs and fades into `fadeColor`; invisible at rest, `setContentOverlap(_:)` fades the blur in as content scrolls under it; touches pass through), plus the skeletons.
  - `StatItemView` is unused since the month rows moved to `MonthProgressRowView` (only its preview builds one). `CircularProgressView`, `MonthStatItemView`, `DecisionRingView` and `FilterCard`'s old `MiniProgressRing` badge are unused since the month hub moved to capsules (only their previews build them; `MiniProgressRing` is still MonthReview's nav bar ring).
  - `SimilarSetCardView` (`Screens/SimilarPhotos`): one similar set as a card: a header (a `ReviewStampView`, 12×32, dashed until the set is confirmed; "Set #N" over "4 photos · 14.2 MB"; a gray Store button that reads "Done" in store mode), the photos (`PhotoGridCell`, best first) in a sideways row sized from the card's own width in `layoutSubviews` (four across, three when four would be under 60pt, 60…120, 8pt gaps; `prepareLayout(forWidth:)` for self-sizing cells), and a footer with count chips and a gray Confirm. Confirmed, it collapses into one row: the stamp, "Kept 1 · 3 to the bin · 1 stored" and a plain Undo; `setConfirmed(_:)` swaps the constraint sets and the host animates. `configure(index:signature:assets:bestAssetId:states:sizes:isConfirmed:)` (the host owns the states and the sizes), `updateSizes(_:)`, `exitStoreModeIfNeeded()`, `fillsHeight` (centers the photos in extra height and shrinks them when it's short: the Duo's spotlight), closures `onConfirm`, `onUndo`, `onStatesChange`, `onInteraction`. The header is one VoiceOver element. Its Store button is hidden, not faded, when confirmed: a `DynamicGlassButton` resets its own alpha whenever its configuration updates.
  - `ScanCapsuleView` (`Screens/ProcessingLoading`): the filter loading screen's capsule, 60×250 by default, with `ReviewCapsuleView`'s rules (radius width / 2, gaps of about width / 12, a non-zero segment at least 3pt): it fills from the bottom with finds (`.systemBlue`), the other checked items (`.label`) and a `.systemGray5` track for what's left, no gap at the top when full; a dashed `.systemGray3` outline before the first result. No red or yellow: nothing is decided there. `configure(checked:found:total:animated:)`; the fills are views so the 0.25 s ease-out is a `UIView.animate` (set directly with Reduce Motion), only the outline is a layer.
  - `ScanMeterView` (`Screens/ProcessingLoading`): that capsule and, 34pt beside it, a 170pt column with the percent (56pt heavy, through a `.percent` `NumberFormatter`, so Turkish shows "%40"), "23 / 57 checked" and a three-row legend (finds, Checked, Left: a 6×14 mark, the name, the count trailing), with one centered line under them (the time left). `update(with: ScanMeterState, animated:)`; a nil `checked` is the starting look ("–" everywhere). `isCompact` is the short variant (44×170 capsule, 42pt percent). One VoiceOver element. Its line under the meter has the meter's width, so it wraps the same way after any earlier layout.
  - `PhotoGridCell` (`Screens/SimilarPhotos`): a set's thumbnail, radius 10. `applyState(_:)` takes a `SimilarPhotoState`: a 3pt border and an 18pt top-trailing badge in the state's color (keep green + checkmark, delete red + xmark, store yellow + archivebox); delete also shows a grayscale copy (`GrayscaleConverter`, cached per asset) at alpha 0.72.
  - `SimilarPhotoThumbnailView` (`Screens/SimilarPhotos`): the state look itself, hosted by `PhotoGridCell` and by the help sheet's sample: `image`, `grayscaleCacheKey`, `applyState(_:animated:)` (nil clears it; animated is a 0.15 s cross-dissolve), `startShake()` / `stopShake()`. Show a marked similar photo with it, never by copying the border and badge.
  - `SimilarHelpSampleCardView`, `SimilarHelpHintRowView`, `SimilarHelpTargetsView` (`Screens/SimilarPhotos`): the help sheet's parts (see **Similar photos → Help sheet**). The targets' bin and store box are the template images `.binLid` / `.binBody` and `.storeBoxLid` / `.storeBoxBody` (PDF, vector preserved), a lid over a body; each part's `center` is constrained to the point it turns or squashes around and its `layer.anchorPoint` is that point, so the transforms need no offsets.
  - `SimilarSummaryView` (`Screens/SimilarPhotos`): "**6** sets to check · 2 done" leading and "~73 MB to free" trailing ("–" until sizes are known); `configure(setsToCheck:done:bytesToFree:)`.
  - `StorageLedgerRowView` (`Screens/Home`): one row of the storage sheet's ledger: a `LegendCapsule` row mark (`rowWidth` × `rowHeight`) in the segment's color, the name (15pt semibold) over an optional count (12pt), and the size trailing (15pt bold, monospaced digits). `configure(color:name:count:size:reservesCountLine:)` (a nil count hides its line; `reservesCountLine` keeps its height so the row doesn't change size between states), `setVerticalPadding(_:)` (11 regular, 8 compact). One VoiceOver element: "name, count, size".
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
  - `tablePoseControlsLayout` (`TablePoseControlsLayout` raw value, `.trackpad` default; defined next to `MonthReviewViewController`)
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
- **Counts:** `assetCount(mediaType:)` is how many assets of a type the app can see (the picked ones with limited access), fetched off main; 0 without access.
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
- **`PhotoProcessor`** streams `ProcessingResult`: `.progress` (`ProcessingProgress`: `current`, `total` and `found`, the filter's finds so far), `.initialBatchReady([ReviewAsset])` (the first 50 when a month has more than 50, so the deck appears early), `.completed`, `.cancelled`. Check `Task.isCancelled`.

## Review model

- **Month keys** are `"yyyy-MM"` (`DateFormatterManager.monthKey(from:)`).
  - **Year keys** are `"year-YYYY"`. A year with fewer than `BulkYear.sparseYearThreshold` (50) items is reviewed as one session.
  - Year keys don't parse as month dates. `fetchPhotos(forMonthKey:)` falls back to `DateFormatterManager.yearDateRange(forYearKey:)` and fetches the whole year, so a deck opened before MonthFilterCards' year preload finishes isn't empty. `countBinAssets` still returns 0 for them. Prefer the preloaded year assets, and guard other month-only code with `hasPrefix("year-")`.
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
- **Total-count resync:** MonthsList and MonthFilterCards compare the live count with `originalTotalCount`. Year keys are resynced only by MonthFilterCards' `resyncYearTotal`, once its year preload finishes; a missing total is filled in.
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
  2. Otherwise, with access `.notDetermined`: present `AskPermissionBoardingViewController()` with `isModalInPresentation = true`. Granted or limited posts `.photoAuthorizationGranted` and dismisses. Denied shows an alert with Cancel and Open Settings. It also re-checks on `didBecomeActive`.
- `AskPermissionBoardingViewController(status: .noAction)` is the same screen as a read-only privacy sheet, with a `CloseButton` at the top leading corner (16pt from the safe area) and no Allow access. Settings' Privacy card opens it.
- **The photo access sheet** (board "Photo access sheet · frame, line and lock"): a page sheet with the large detent only and the grabber. It covers the tab bar, so its column spans the full width with 24pt sides; only rows the camera overlaps narrow (`updateOcclusionClearance`). One column: the header (28pt heavy title over the subtitle), `PrivacyShieldArtView` (354×330 on an iPhone 17, shrunk to the room so nothing scrolls) and three rows (an ink 22×36 capsule (`.label`) with the symbol in the opposite color, white in light mode and black in dark, then 15pt medium text) spread evenly above the ink Allow access (`ButtonSize.large`), 16pt above the safe area (20pt above the edge on a home-button phone). Short sheets (the view's own height `<= 700`) and the Duo cover take a 23pt title, 14pt rows, 20×32 capsules and a 50pt button. On the Duo's inner display it stays the one column, stacked top to bottom, everywhere but the table pose: held sideways (open and book pose; the short metrics, the button crossing the fold, a deliberate exception) and upright fully open (regular width over 700pt tall: 30pt title, 18pt rows, 26×44 capsules, the art up to 640×900 with 28pt above and below it (`artMargin`, in its holder) so it fills the room and crosses the fold line, which is fine since it isn't tappable). Only the table pose (a horizontal `FoldRegion.activeFold`, regular width) splits; folding into or out of it (the view's size unchanged) cross-dissolves the sheet over 0.35 s from a snapshot (`crossDissolveFromCurrentContent()`, since the views move between stacks), while a rotation or the first layout switches at once: the header at the raised half's top and the art as large as fits, centered in the room under it (the holder hugs the art at `.defaultHigh`, so only a stack pinned top and bottom stretches it), ending at the fold region; the rows and button on the base. The same views move between `singleStack`, `firstStack` and `secondStack` (`rebuildContent(for:)`).

### Home (`Screens/Home`)
- **Layout:** a vertical stack of `StorageAnalysisLiteView`, a row of Photos and Videos `FilterCard`s ("Browse by month"), and a `DashboardCard`. On the Duo's inner display it splits at the fold (see **iPhone Duo**).
- **Bar buttons:** `.luckyItem` on the left, `.helpItem` on the right (presents onboarding again).
- **Data:** `loadData()` returns early while access is `.notDetermined`. Otherwise it shows the cached storage data, calls `refreshIfNeeded()` and refreshes the dashboard. It observes the storage notifications.
- **Storage view tap:** presents `StorageAnalysisBottomSheet` (board "Storage analysis sheet · S1 Ledger on every size"). Ignored while iCloud Photos sync is on.
  - One column, no card around it: the title, the used figure (34pt heavy, monospaced) with "/ total" beside it (wrapping under it when they don't fit) over "Used", a `SegmentedBarView` (photos / videos / other, available as the track), a ledger card of `StorageLedgerRowView`s (Photos and Videos with plural counts, Other, Available; hairlines between), a separate Saved card (leaf, shown only while `spaceSavedBytes > 0`) and a footer with the last-analyzed text and a gray Refresh `DynamicGlassButton` (36pt) that calls `startAnalysis()`.
  - One layout in every state; values cross-dissolve (0.25 s). Scanning: "–" values, one gray segment growing with `.storageAnalysisDidUpdateProgress`, the progress text in the footer, Refresh disabled, Saved hidden. Idle: "Not analyzed yet" + Analyze Storage; error: Unable to analyze + Try Again.
  - A plain native sheet as tall as its content (iOS 16+ one custom detent from `fittedHeight`, `invalidateDetents()` when it changes; iOS 15 medium or large); scrolls only as a fallback. Compact metrics (22 / 28pt, tighter gaps) are picked after layout: a compact-width window `<= 700` tall, or on the Duo's inner display a horizontal `splittingFold` (the sheet sits below the fold) or a vertical `activeFold` (book pose). The column is capped at 560pt and centered; sideways fully open it may cross the fold line.
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
  - `.resumeMonth` → the month's hub through `MonthsListViewController.openHub(in:…)`
  - `.browsePhotos` / `.browseVideos` → the matching tab

  `navigateOnTab` selects the tab, pops to root, then pushes after 0.1 s.
- **Lucky picker** (`LuckyPickerSheetViewController`, 360pt detent):
  - A 2 s slot-machine shuffle (0.12 s ticks) picks a media type, an unfinished month and a filter.
  - Go pushes `MonthReviewViewController(filterContext:)` with `navigationSource = .luckyPicker`.
  - With no unfinished months, Go is disabled.

### Months list (`Screens/MonthsList`)
- One class, two tabs: `MonthsListViewController(mediaType:)`.
- **Empty and permission states** (board "Months list · no videos, every access level"; see **Empty and finished states**): one `EmptyStateView`, added once, shows instead of the table. `refreshState()` reads the access level after every auth change (`viewDidLoad`, `viewWillAppear`, `.photoAuthorizationGranted`, and `didBecomeActive` while a state shows) and never touches PhotoKit while it's `.notDetermined`; with access it runs `loadMonths()`, which resolves the state when this media type has no months. `this` is the tab's media type, `other` the other one:
  - **Full access, `this` empty, `other` not** (`.emptyThis`): the media symbol, "No videos yet", a "Meanwhile in Photos" label over a `MonthLinkCardView`, and "Review photos". The card is `other`'s newest month in progress (`DashboardCardManager.newestInProgressMonth(mediaType:)`, the empty Delete Bin's lookup), else its newest unfinished month or sparse-year session, else no card. The primary switches to `other`'s tab, pops to root and pushes that month's hub (Home's `navigateOnTab` pattern); without a card it only switches the tab.
  - **Full access, both empty** (`.emptyLibrary`): the photo-stack symbol, "Nothing to clean yet", the access card (`.full`), no button.
  - **Limited, items picked but none of `this`** (`.limitedNoneOfThis`): the media symbol, "No videos selected", the access card (`.limited`, the picked count, "Allow full access" → the Settings app), "Select videos".
  - **Limited, nothing picked** (`.limitedNothing`): `checkmark.rectangle.stack`, "Nothing selected yet", the same card with its no-items text, "Select photos & videos".
  - **`.notDetermined`** (`.notAsked`): `lock.rectangle.stack`, "Let Purgio see your library", the access card (`.notAsked`), "Allow access", which requests access and posts `.photoAuthorizationGranted` on a grant. Home's permission sheet usually covers this state.
  - **Denied or restricted** (`.off`): `video.slash` / `photo.slash`, "Purgio can't see your library", the access card (`.off`), "Open Settings".
  - Both "Select…" buttons call `presentLimitedLibraryPicker`, then `invalidateMonthBucketsCache()` and reload.
  - Hero names newer than iOS 15 go through `UIImage.availableSymbolName(_:)`, which falls back (`photo.stack` → `photo.on.rectangle.angled`, `checkmark.rectangle.stack` → `checkmark.rectangle`, `lock.rectangle.stack` → `lock.rectangle`, `photo.slash` → `eye.slash`).
  - **Bin:** `.emptyThis` and `.limitedNoneOfThis` keep it in a slot beside the primary (`trailingSlotWidth = BinSlot.compactWidth`) while it holds something, sent on layout, in `viewDidAppear` and from `onLayoutModeChange`; otherwise, and in the other states, it is suppressed. `.deleteBinCountDidChange` re-applies it. The filter bar item is disabled while a state shows.
- **Loading:** `loadMonths()` (a stored task, cancelled before it's replaced and in `viewWillDisappear`) runs on `viewWillAppear` through `refreshState()`, on `.photoLibraryDidChange` and after the limited picker. It shows `SkeletonMonthListView` only when there's no data yet and no state is on screen, and resyncs totals (see **Review model**).
- **Sections:** an inset-grouped table, one section per year.
  - A year with fewer than 50 items gets one `YearAggregateCell`, which opens the `year-YYYY` session. Otherwise each month gets a `MonthListCell`.
  - Both push `MonthFilterCardsViewController`.
  - Both cells are a card around `MonthProgressRowView` plus the chevron; each card rounds its own corners, so the cells drop the inset-grouped section look (`backgroundConfiguration = .clear()`, and no corner mask in `layoutSubviews`, which on iOS 26 cut the card's corners and the selection outline). The card is in one of three states ("complete" as everywhere; total = `originalTotalCount`, else the live count):
    - not started: a dashed capsule, "N photos/videos to review" (a year: "Jan, Jul · N items"), and the total over "left"
    - in progress: the split capsule, the delete / keep / store chips (zero counts hidden), and `total − reviewed` over "left"
    - done: the stamped capsule, "All caught up!" (years too) and a Done pill
  - The whole row is one VoiceOver element: "title, 21 of 29 reviewed, 8 left". `prepareForReuse` calls `reset()`.
  - The "left" caption is `monthCell.leftCount` with its number removed, which holds for English and Turkish; a new language may need its own `monthCell.leftCaption` key.
- **Filters:**
  - A status menu: All / Completed / In Progress / Not Started. A year menu, plus `.filterByYear`.
  - A reset button appears while a filter is active. Filters that match nothing reset themselves.
- **Bin button:** global `.count(DeleteBinStore.count)`; it opens the unfiltered bin. While the inner display's detail shows, the hub configures it instead (see below).
- **iPhone Duo inner display** (`updateDetailSplit()`, re-checked on every layout pass, only where `FoldRegion.splittingFold` crosses the view; a horizontal fold only in regular width and with rows to show): **list | detail.**
  - Sideways the table ends before the fold and `detailContainerView` starts after it. Upright (fully open and partly folded alike) the detail fills the raised half and stands still, ending at the gap; the table starts `listTopClearance` (10) below it with the rest of the gap as its top inset, and its rows scroll up under a `ProgressiveBlurView` (`listTopBlurView`, at least `EdgePadding.content` tall, fading in with `setContentOverlap(_:)`), as Settings' base does in the table pose. Three constraint sets (single, sideways, upright) swap only when the axis changes; the gap is `Spacer.foldGap` centered on the fold line while open and the whole fold region while folded.
  - The detail is an embedded `MonthFilterCardsViewController(…, isEmbedded: true)` child (`showDetail(at:)`, 0.25 s snapshot cross-dissolve). Its card taps push through the list's navigation controller as usual.
  - **Selection:** a row tap in the split shows its hub (selection haptic) and the row stays selected (`setSelected` outlines the card in `.label`, 2pt, fading the width on screen through `CALayer.setBorderWidth(_:animated:)`; a fill would hide the capsule's gray segment). Swapping one hub for another sets the old hub's `keepsBinPlacementOnDisappear`, so the bin stays in the slot the new hub takes over instead of jumping to its standard place and back. `ensureDetailSelection()` runs after every reload and when the split turns on: it keeps `selectedDetailKey` if the row is still listed, else picks the first unfinished row (the usual "complete" test), else the first row. Leaving the split removes the hub, deselects and gives the bin back to the list; the key is kept for next time.
  - **The hub is never full-screen while the list splits.** `MonthsListViewController.openHub(in:mediaType:title:key:yearSection:)` (`+Hub.swift`) is the one route to a month's hub from another screen (Home's resume rows and dashboard, the empty Delete Bin, the empty tab's "Review …"): it switches to the tab, pops to root and calls `selectDetail(key:)`; when the list then splits, the month is the detail, otherwise the hub is pushed. `selectDetail(key:)` selects and shows the row while split (resetting filters that hide it), else keeps the key. `absorbPushedHubs()` folds every non-embedded hub in the stack into the detail while the nav controller's view would split (`detailSplitFold(in:traitCollection:hasRows:)`): a hub on top pops to the list, one under a deck leaves the stack. `MainTabBarController` calls it on every layout pass (unfolding) and after every push or pop, retrying once a transition ends, and the list after its rows load. The hub's own fold split stays only as a fallback.
- On iOS 26 a top gradient covers the area above the safe area.

### Month filter cards (`Screens/MonthFilterCards`)
- **The hub for a month or year session.** Its title is the month (or year) alone; the selected Photos/Videos tab names the media type.
- **Embedded** (`isEmbedded: true`, MonthsList's inner-display detail): never splits at the fold; the same one column with a header row on top (the title, plus the year-details info button for year keys, since the nav bar is the list's) and the bottom row's bin slot. Above the fold (upright, the pane wider than tall) `updateEmbeddedDensity()` hides the overview card, since the selected row on the base shows its progress, and shows every card as a `.row` (two per line, sharing the height equally); the header stays and names the month. The month-scoped bin moves into the slot (`updateBinSlot()` checks that the list holding it is on top; pushed, the hub itself); `sessionKey` is the month or year key it shows.
- **One column** (phones, the Duo's cover display, Split View), filling the whole height: the overview card, tile row 1, tile row 2, the All Photos row, and a bottom row with the Continue pill and `binSlotView`.
  - **Overview card:** `ProgressSummaryCardView`, fed with the same clamped state as the inner display's overview.
  - **Heights:** the two tile rows share the leftover height equally and the All Photos row takes 0.6 of a tile row (`updateCardHeightConstraints`). Gaps are `Layout.cardSpacing` (10), or 8 when a tile row would be under 140pt at the regular gaps (iPhone SE), decided after layout from the column's own height (`updateCardSpacing()`). There too, when a tile row would be under 110pt beside the regular overview card, the overview goes compact (`summaryCardView.isCompact`) and the cards take the room.
  - **Bottom row:** the Continue pill (`DynamicGlassButton`, `ButtonSize.large`) and the bin's slot on Home's baseline, as wide as the bin's icon and count (`FloatingBinButton.slotWidth(forCount:)`: at least `BinSlot.compactWidth` (96), wider only when the count needs it, "99+" at most; re-sized whenever the hub configures the bin) with the pill taking the rest: `DuoEdgeConstraints` with `EdgePadding.content` sides and `standardBottom: Spacer.buttonBottom`. The pill reads "Continue" (no count: the overview card already shows what's left), "All caught up" and disabled once complete, and runs `allPhotosCardTapped()`. Its colors are resolved per appearance (`applyContinueButtonStyle()`, re-applied on trait changes) because the glass doesn't keep a dynamic title color legible.
  - **Bin slot:** every layout of the hub has one. The global bin moves into it through `setBinButtonPlacement(.slot(rect))`, sent from `viewDidLayoutSubviews` when the rect moves and again in `viewDidAppear`; `viewWillDisappear` restores `.standard`.
- **iPhone Duo inner display** (`updateFoldSplit()`, re-checked on every layout pass, only where `FoldRegion.splittingFold` crosses the view):
  - **The overview** is a `ProgressOverviewView` instead of the overview card; the All Photos card stays too, so it's clear what Continue resumes.
  - **Fed by `updateStats()`** through `updateProgressOverview(_:)`, before its year-key early return: the same clamped reviewed / deleted / kept / stored and the total from `ReviewProgressStore`. A total of 0 (a year before its preload finishes) shows a dashed capsule, "–" for the number left and the percent, "– / –" and zero counts; a complete session shows the full split, 0 left and 100%. `updateCardStatuses()` runs there too, so a year's cards have a status before the preload.
  - **Held sideways** (vertical fold): the overview filling its column with the pill below; on the other side All Photos and then the four filters, one `.row` per line sharing the height, then `binSlotView` spanning the column at `ButtonSize.large`, so the bin is as wide as the pill and on its baseline; there the bin shows its title (`showsTitle: true`).
  - **Upright** (horizontal fold, regular width only), fully open and partly folded: the overview fills the raised half; the base holds the All Photos row over the four filters' 2×2 tiles (the same 0.6 share; tiles that short use their tight arrangement), and the bottom row with the pill and `binSlotView` (sized to the bin's count, as in one column).
  - **The gap at the fold** is the custom spacing after the overview only, so folding moves just the gap: `cardSpacing` centered on the fold line while open, clearing the whole region while folded.
- **Cards:**
  - Photos: Similar & Duplicated | Largest First, Eyes Closed | Screenshots, All Photos.
  - Videos: Slow Motion | Largest First, Time-lapse | Screen Recordings, All Videos.
  - Styles: the four filters are `.tile`s and All Photos a `.row`; held sideways and in the short embedded pane every card is a `.row` (`applyCardStyles()`).
  - A card's capsule and status come from its finished flag, then from its filter key's own `ReviewProgressStore` record (`FilterType.applyStatus(to:monthKey:mediaType:)` → `FilterCard.setProgress`, shared with the end states' list); All Photos and Largest First read the main month key. A complete month completes every card. A complete card does nothing when tapped.
- **Routes** (`FilterType.makeViewController(…)` in `FilterType+Route.swift`, shared with the end states):
  - Similar → `SimilarPhotosViewController`
  - Largest and Eyes Closed → `ProcessingLoadingViewController(config: .largeFiles(mediaType:) / .eyesClosed())`
  - Everything else → `MonthReviewViewController(filterContext:)` directly
- **Year sessions:**
  - `preloadYearAssets()` fetches every `YYYY-` bucket once and hands the assets to each filter (`setSortedAssets`).
  - An info button opens `YearDetailSheet`. Its per-month percentages are **estimates**: the year's reviewed count spread in proportion to photo counts.
- **Bin button:** `.count`, refined with `countBinAssets(in: month)`. Its tap opens the bin filtered to this month (unfiltered for year keys).

### Processing loading (`Screens/ProcessingLoading`)
Board "Filter loading · K1·A on every size". The loading screen for the slow filters (Eyes Closed, Largest First), split into the view controller and `+Fold`.
- **Flow:** fetches the month (a year session hands its assets over), runs `config.processAssets`, then **replaces itself** in the stack with `MonthReviewViewController` + `setPreComputedAssets`, forwarding `navigationSource` and `isFilterResultMode`.
  - **Large files** removes processed assets first. **Eyes closed** (`isFilterResultMode = true`) doesn't.
  - `ProcessingConfig` carries the filter context, the finds row's name ("Found" / "Over 20 MB" for photos, "Over 150 MB" for videos; `.largeFiles(mediaType:)`) and the scope line's text.
  - `ProcessingProgress.found` (0 by default) is what the filter has turned up: closed-eye photos, or items over `LargeFile`'s size for their media type.
  - The scan starts once (`didStart`), so coming back from the bin doesn't restart it. A result that arrives while the bin is open over the screen is held (`completedAssets`) and handed over on the next `viewDidAppear`.
- **One column** (phones, the cover display, Split View), centered in the room above the bottom row, `.mainBackground`, the month as the nav title:
  - **The filter leads:** its glyph (`FilterType.cardIcon`, `.systemBlue`, thin, 58pt, no background), its name (`cardTitle`, 34pt heavy) and the scope line ("Looking for closed eyes in 57 photos in August 2025"; a year session names the year), 40pt above `ScanMeterView`.
  - **Bottom row** on Home's baseline (`DuoEdgeConstraints`, `EdgePadding.content`, `Spacer.buttonBottom`): a gray Cancel (`DynamicGlassButton`, `.regular`, `ButtonSize.large`) and the bin's slot (`FloatingBinButton.slotWidth(forCount:)`). The bin is configured as on the month hub: this month's count, a tap opens this month's bin.
  - **Short column** (the view's own height `<= 700`): glyph 44, name 28, the compact meter, 24pt between them, a 50pt row and the bin as tall as the row (`matchesHeight`). Nothing scrolls.
- **States:**
  - **Starting** (fetching, and before the first result): the dashed capsule, "–" numbers, "– / 57 checked" once the total is known, and "Getting photos ready". The scope line fades in with the total.
  - **Checking:** every `.progress` updates the meter. The time left (average per item so far) shows from 3 items on: "About N s left" under a minute, "About N min left" (rounded up) above.
  - **Done:** the full capsule with the final counts, "Opening the first photo…", Cancel disabled, a success haptic, then after 0.4 s the deck in a 0.25 s cross-dissolve. With no finds the deck opens on its own "No … here" state.
  - **Cancel** cancels the tasks and pops.
- **iPhone Duo inner display** (`updateFoldSplit()`, on every layout pass, where `FoldRegion.splittingFold` crosses the view; a horizontal fold only in regular width). Three constraint sets (`single`, `sideways`, `upright`) swap without animation; folding and unfolding within one springs (0.4 s, 0.75, 0.8). The gap is `Spacer.foldGap` centered on the fold line while open and the whole fold region while folded.
  - **Held sideways:** the filter (glyph 64, name 36) centered in the leading half; the meter centered in the trailing half with the bottom row under it.
  - **Upright:** the filter (glyph 72, name 40) centered on the raised half; the meter on the base above the bottom row. A base with under 292pt for the meter (the table pose) takes the compact one.
  - Everything lives in `contentView`, not in `view` itself, so `updateFoldSplit()` lays it out before the bin's slot is read.
- **VoiceOver:** the glyph is hidden; the name (header), the scope line, the meter as one element ("%40, 23 of 57 checked, 3 found, about 8 seconds left"), Cancel. It announces 25 / 50 / 75 % and the end, not every batch.

### Month review — the swipe deck (`Screens/MonthReview`)
- **Init:** `(monthTitle:monthKey:mediaType:filterContext:)`. `FilterContext` is `.none`, `.screenshots`, `.largeFiles`, `.eyesClosed`, `.screenRecordings`, `.slowMotion` or `.timeLapse`.
  - Filter mode is on when `preSortedAssets` (`setSortedAssets`) or `preComputedAssets` (`setPreComputedAssets`) is set.
  - `navigationSource` (`.manual` / `.dashboard` / `.luckyPicker`) changes the empty state's action.
  - Year sessions with `.none` set the title to the current asset's month.
- **Lifecycle:**
  - **First `viewDidAppear`:** starts the undo session (`SessionKey(monthKey, mediaType)`), builds 3 recycled `SwipeCardView`s and the pan gesture, and calls `loadPhotos()`.
  - **Returning from a child:** recomputes the bin increment, prunes undo actions for deleted assets, recalculates counts from the stores, then re-advances.
  - **`viewWillDisappear`:** saves progress, cancels loading and image requests, cleans up video. When popped, it also hides the bin button.
  - `saveProgress()` does nothing while `reviewAssets` is empty (still loading, or an empty deck), so leaving early never overwrites the stored record with zeros.
- **Loading:**
  1. Source assets: the pre-computed ones, else the pre-sorted ones, else `fetchPhotos(month)` (oldest first).
  2. Filter by subtype.
  3. Wrap each in a `ReviewAsset` through `PhotoProcessor`.
  4. Start index: the first unprocessed asset from index 0 (`firstUnprocessedIndex`), in both the early batch and the full list. With `skipICloudPhotos` on and internet off, iCloud-only assets are skipped too. The saved `currentIndex` is never the starting point: the asset array can change between sessions (imports sort in before it, real deletions shift it, skipped iCloud assets become reachable).
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
  - Every undo path finds the asset by `assetLocalIdentifier` (`deckIndex(of:)`), never by `UndoAction.index`, and recalculates the counts from the stores. When this deck doesn't hold the asset, its store entry is still reverted and the deck stays where it is.
  - **Undo button:** pops the last action, moves the deck back to its asset and reverts its store and stats.
  - **History button:** `UndoHistoryViewController` in a sheet (medium and large), through `UndoHistoryDelegate`:
    - `didPerformAction(newType:on:)` changes an action's type. It moves the asset between stores and album, but the deck position and the review count stay.
    - `didUndoActions` / `didUndoAll` remove the actions, revert everything (`revertUndoActions`), and move the deck back to the earliest undone asset it holds.
- **End states** (`+EndStates.swift`; `EmptyStateView` over the deck, see **Empty and finished states**). `isShowingEndState` is set once and guards a second show; the deck, gradients, stats label / pill, undo-history row and badge, table base, sideways grips and video controls fade out, the table-layout bar item goes, and the screen takes `.mainBackground`.
  - **Completion** (`showCompletionSummary`): saves, marks the progress key and the filter complete, then:
    - **Month complete** (no filter, or the main key is now complete): the stamp, "<Month> is done", `ReviewSplitCardView`, and a bottom row with the next older unfinished session of this media type (a month, or a sparse year's `year-YYYY`; found from the month buckets, "Back to months" until then or when there is none) beside the global bin in a 96pt slot. The primary replaces the deck with that session's All Photos deck (and drops this month's hub under it); the bin opens the unfiltered bin and removes the deck from the stack; the secondary is "Back to months".
    - **Back routes select the month on the list** (`selectDetail(key:)`): "Back to <month>" and "Back to months" the deck's month, the next session's deck its own month, so the Duo inner display lands on the list with that row as the detail.
    - **"Back to months"** (here and on "No photos") pops to the `MonthsListViewController` in the stack, not to the screen under the deck (the month's hub); a deck pushed from Home (Lucky, dashboard) switches to its media type's tab and pops to root instead.
    - **Filter complete, month not:** the stamp, "Nothing left in <filter>", the "Keep going" list, "Continue" and "Back to <month>".
  - **A filter found nothing** (`showEmptyState`, filter active): marks the filter finished; the stamp, "No <filter> here", the "Keep going" list, "Continue" (replaces the deck with the month's All Photos deck; hidden when the month is complete) and "Back to <month>" (pop). With the dashboard or Lucky source the secondary is "Try another month", which replaces the deck with a random other month.
  - **No photos:** a calendar symbol, "No Photos in <month>" and "Back to months".
  - A row of the list replaces the deck with that filter's screen (`replaceInNavigationStack(with:)`), forwarding `navigationSource`.
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
- **Stats pill:** on the inner display (regular width: upright, sideways, book and table pose) `ReviewStatsPillView` replaces the one-line stats label, sitting in the hidden label's slot and fed by `updateStats()` (`updateStatsPill`). `updateStatsPillVisibility()` switches it on every layout pass; the cover display keeps the label.
- **iPhone Duo inner display held sideways** (`+Landscape.swift`; regular width and `view.bounds.width > view.bounds.height`, re-checked on every layout pass; the cover display keeps the standard layout and the upright inner display the table layout (see below)):
  - **Switching** swaps constraint sets inside `UIView.performWithoutAnimation` and lays out at once, because the switch can land inside the push transition or the skeleton fade. `DuoEdgeConstraints.isEnabled = false` hands the standard edges over.
  - **Background** is `.mainBackground` (the grips and pills are white cards); otherwise `.systemBackground`.
  - **Grips:** an `ActionGripView` on each side, Store + Delete on the left and Store + Keep on the right. Gray segments with only the icon colored (yellow, red, green) and no counts. A grip tap calls `completeSwipe`, the same path as a swipe.
  - **Stats:** `ReviewStatsPillView`, as on every inner-display layout (see **Stats pill** below).
  - **Deck:**
    - Each photo card hugs its own aspect ratio inside the card area minus `Layout.landscapeDeckInset` (`applyCardSizing`, `CardHugConstraints`). Every card, the top one included, is clamped to `Layout.landscapeCardRatioRange` (9:16…16:9), so a card never changes shape as it comes to the top; an extreme photo is aspect-fit inside its card over the card's blurred backdrop, never cropped.
    - The cards behind fan out to alternate sides (`stackTransform`): 3.5° turn, less for wide photos, plus a sideways offset and a small scale step. All cards are opaque.
    - A video on top fills the card area; the cards behind tuck in without turning.
    - **Order change:** `completeSwipe` sets `isPromotingDeck`, so `deckCards` leaves out the departing card and the rest straighten, turn and resize into their new places during its 0.4 s fly-off. The card joining the back is sized for its photo first, then fades in from 0 and `Layout.deckEntryScale` (0.92) to full.
    - The cards behind the top one show the next assets still to review (`deckIndices(count:)`), never processed ones, so they don't hide when sorted assets sit in between. After a swipe, a card reassigned to an asset another card already shows reuses that image (`configureCard(_:at:placeholderImages:)`) until its own load finishes.
  - **Badges:** photos get a "date · size" chip at the bottom (`DateFormatterManager.dayMonthTime`); videos a date chip at the top plus the size badge. Only the top card shows its chip.
  - **Bottom row:** Undo and History become titled pills; the global bin button moves into `binSlotGuide` beside them through `setBinButtonPlacement(.slot(rect))` (see **Floating bin button**).
- **iPhone Duo table layout** (`+TablePose.swift`; `tableLayoutFold()`, read on every layout pass):
  - **When:** the table pose (upright inner display partly folded, `FoldRegion.activeFold` with `pose == .table`) and, board O2, the upright inner display fully open (`FoldRegion.splittingFold` horizontal, regular width, not sideways). The book pose, sideways, the cover display, Split View and the iPhone 17 don't use it.
  - **Switching:** `isTableLayoutActive` tracks it. Only turning it on or off swaps the constraint sets and shows or hides the base (`applyTableLayout(fold:isFolded:)` in `+Fold.swift`); folding and unfolding while it's on swap the split (`tableFoldedConstraints` / `tableOpenConstraints`, `updateTableSplitConstraints`), animate the deck to its new size (0.3 s) and switch the base's control and the bar item (`isTableLayoutFolded`, `updateTableControlsForFold`). Sideways ↔ upright hands over without animation in the same pass (`syncTableLayoutWithoutAnimation()`). The book-pose play button offset and the vertical undo/history split use the real pose.
  - **Top:** the stats pill (see **Stats pill**), then the deck. Partly folded (the raised half) it ends at `fold.minY − Layout.foldGap` (12); fully open it ends 12 above the base, which is `Layout.openTableBaseToDeckRatio` (0.3 / 0.7) of the deck's height, so the deck gets about 70%. The card keeps its own pan gesture.
  - **Deck:** the same fan as sideways (`usesFannedDeckLayout`: `isLandscapeDeckActive || isTableLayoutActive`): each photo card hugs its aspect ratio, the cards behind fan out, and a video on top fills the card area. Badges stay standard (no date chip). Turning the layout on or off, folding and unfolding re-size and re-fan the cards in the fold animation (`refreshCardsForLayoutChange`).
  - **Base:** `tableBaseGuide` runs down to the bottom row − 12, from `fold.maxY + 12` while partly folded (from the 30% split while fully open), with the card's side edges. It holds `tableBaseContainerView` with one of two controls (`currentTableControlsLayout`): fully open always the keys, since the card itself can be swiped there; partly folded the one chosen by `SettingsStore.tablePoseControlsLayout` (cross-dissolve, 0.25 s, on fold and unfold when the control changes; keys in both states only resize with the deck):
    - `.trackpad` (default, board T1): `TablePoseTrackpadView`. Its pan targets `handlePan`, which reads the drag in `view`, so the raised card moves exactly like a direct swipe (same thresholds, gradients, haptics, `completeSwipe`). Its pad shows a mini gray box at the top card's aspect ratio (the next one springs in from 0.7 scale) that follows the card's drag, turn and fly-off (`updateTablePosePreview()`, called from `handlePan`, `springBackTopCard`, `completeSwipe`, `layoutCards` and when the layout starts). Its sides are physical (forced left-to-right) because a drag's direction is.
    - `.keys` (board T4): `TablePoseKeysView`, Store over Delete | Keep, through `performGripAction` like the sideways grips. The two rows share the tray evenly; Store stops at `ActionGrip.storeSegmentHeight`.
  - **Layout bar item** (`.tableLayoutItem`): a single-selection menu ("Swipe area" / "Buttons") that saves the choice, cross-dissolves the controls (0.25 s) and plays a selection haptic. It shows only while partly folded (fully open has one choice): added when the table pose starts and removed when the device unfolds or the layout ends (never on every layout pass), after the filter progress ring, with `visibilityPriority` `.low` (the ring `.high`).
  - The base fades with the deck: hidden while the skeleton loads, on the empty state and on the completion summary. The grouped background (`.mainBackground`) applies here as sideways, so the white trays show.
  - Leaving the table layout or unfolding mid-drag cancels the trackpad's pan, and `handlePan` springs the card back (`springBackTopCard`) instead of completing a swipe.
  - `updateFoldLayout()` does nothing until `setupMainUI` has added the card: the push lays out before it, and recording the layout early would skip the first real switch (and crashed while folded).

### Similar photos (`Screens/SimilarPhotos`)
- **Inputs:** `(assets?, monthTitle?, monthKey?, mediaType)`.
  - With `assets` passed in (year sessions), it scans them as-is.
  - Otherwise it fetches the month and drops processed assets, except those `SimilarUndoStore` knows about.
  - With neither assets nor a month (dashboard), it scans the whole library.
- **Files:** the view controller is split into `+Layout` (compositional layout, bottom row, bin slot), `+Fold` (the Duo's inner display), `+Actions` (confirm, undo, progress) and `+EndStates`.
- **Model:** the view controller owns everything the cards show. `setStates` (set index → asset id → `SimilarPhotoState`) is the one record of the marks; `signatures` are the list's item ids; `sizesBySignature` holds each photo's bytes; `confirmedThisVisit` is what the finished state totals and "Undo all" reverts.
  - **Defaults:** the best photo is keep, all others delete.
  - **Sizes** are read once after the scan, off main (`PHAsset.resourceMetadata()` in a stored task, cancelled in `viewWillDisappear` and restarted in `viewDidAppear` when still missing), then the subtitles and the summary update on main. They show "–" until then.
- **The set card** is `SimilarSetCardView` (see **Design system**), in a self-sizing `SimilarSetCell`.
  - **Tap:** cycles keep ↔ delete.
  - **Store mode:** the card's Store button. Only one card at a time; the photos wiggle; it ends after 30pt of scroll. A tap toggles a photo between store and its default.
  - **Long-press (0.3 s):** a full-screen blurred preview on the card's `window`.
- **One column** (phones, the Duo's cover display, Split View): a `UICollectionView` with a compositional layout and a diffable data source, `.mainBackground` behind it.
  - The first item is the summary line (`SimilarSummaryCell`), then the sets 10pt apart. "To free" is the size of the photos marked delete in sets not yet confirmed.
  - The list's sides follow the safe area and the rail through `DuoEdgeConstraints` (`EdgePadding.content`); its cells span its width.
  - **Bottom row** on Home's baseline (`DuoEdgeConstraints`, `Spacer.buttonBottom`): an ink "Confirm all · N sets" (`.prominent`, `ButtonSize.large`; disabled without an unconfirmed set) and the bin's slot, as wide as `FloatingBinButton.slotWidth(forCount:)`. "Confirm all" asks first (the batch alert), then confirms every unconfirmed set.
  - The list runs to the bottom edge in every layout; a bottom content inset rests the last card 12pt above the row (`updateListInsets`), and cards scroll under the row behind a full-width bottom-edge `ProgressiveBlurView` (`listBottomBlurView`: the row's area plus a 28pt band above it), which fades in only while cards are under it (`updateBottomBlur`). No gradient fade.
  - **Short columns** (the view's own height `<= 700`: iPhone SE, the cover display, the inner display held sideways): 8pt gaps and 50pt bottom-row buttons; the bin takes the row's height (`.slot(rect, matchesHeight: true)`).
- **iPhone Duo inner display** (`updateFoldSplit()`, on every layout pass, where `FoldRegion.splittingFold` crosses the view; a horizontal fold only in regular width). Three constraint sets (`single`, `sideways`, `upright`) swap without animation; folding and unfolding within one springs (0.4 s, 0.75, 0.8). The gap is `Spacer.foldGap` centered on the fold line while open and the whole fold region while folded.
  - **Held sideways:** one scroll view, the sets in pairs (1 | 2, 3 | 4…), each row top-aligned. The section provider builds the two items' widths from the fold's x (`ListMetrics`), and the layout is invalidated when they change. The summary line spans the first column. The bottom row sits under the second column; both columns scroll under it and the blur, like the single column.
  - **Upright** (fully open and the table pose): the raised half holds a summary card and a spotlight `SimilarSetCardView` (`fillsHeight`) with the first unconfirmed set, and stands still. The base lists the other sets above the bottom row. Confirming the spotlight's set brings the next one up in a 0.25 s cross-dissolve.
  - The list's views sit in `listContentView`, not in `view` itself, so a constraint changed in `viewDidLayoutSubviews` brings no second pass: `updateFoldSplit()` lays `listContentView` out before frames are read (the columns' widths, the bin's slot).
- **Confirm a set:**
  - Updates the bin, kept and stored stores (and the album), `recordDeletion`, `recordReview`.
  - `batchSave` on `"<month>_similar"` and the main month key; `markSimilarReviewActivity`.
  - Saves to `SimilarUndoStore`, keyed by a **signature**: the sorted localIdentifiers joined with `|`. Sets are restored as confirmed by signature after a rescan, with the marks chosen then.
  - Then a success haptic, the card collapses with the spring (the snapshot `reconfigureItems` inside the animation re-measures the cell), and the summary and "Confirm all" update.
  - **Undo** reverses all of it (`revert(setsAt:)`) and the row expands back. Similar doesn't use `UndoHistoryManager`.
- **Help sheet** (`SimilarPhotosHelpSheet`, the "?" bar item; board "Similar photos · help sheet · keep, bin and store targets"): one page, local to the sheet (no PhotoKit, stores, stats or undo).
  - **Content:** the title and subtitle, a sample set (`SimilarHelpSampleCardView`: four drawn photos, Store pill, chips, Confirm), three hints (`SimilarHelpHintRowView`) and an ink "Got it". The sample works like the real card: tap switches keep ↔ delete, Store mode (the pill fills yellow and reads "Done") toggles store ↔ the photo's default.
  - **Idle loop:** until the card is touched, photo 2 hops through keep → delete → store every 1.4 s with the pill and chips in step. The first touch ends it for good and puts photo 2 back on keep; a touch on Confirm keeps the marks on screen, so what's confirmed is what was showing. No loop with Reduce Motion or VoiceOver.
  - **Confirm** (`+Confirm.swift`): the hints give way to `SimilarHelpTargetsView` (a Photos pile, the bin, the store box) in the same area; kept photos fly onto the pile and stay, stored and deleted ones drop behind a lid that opens only when something is coming; each target squashes and counts ("0", then "+N"); the card is stamped and the sheet closes. Steps are stored `DispatchWorkItem`s, cancelled by Got it and in `viewDidDisappear`. With Reduce Motion or VoiceOver there are no flights: cross-fades, counts, stamp, close.
  - **Size:** iOS 16+ a custom detent as tall as the content (`fittedHeight`, kept current with `invalidateDetents()`); iOS 15 `.medium` when the content fits, else `.large`. A sheet too short for its content takes 60pt photos and tighter gaps, measured in `viewDidLayoutSubviews`, once. The column spans the sheet's full width (it covers the tab bar and the side bar), 24pt a side, at most 420pt wide, centered; only rows the camera overlaps narrow, evenly on both sides (`updateOcclusionClearance`).
  - **Table pose:** the sheet takes the whole height; the header and the sample center above the fold, the hints (or targets) and Got it sit below it.
- **Bin button:** always `.count` with the month context (it opens the month's bin), in the bottom row's slot: sent from `viewDidLayoutSubviews` when the rect moves and in `viewDidAppear`; `viewWillDisappear` restores `.standard`. No wide morphs.
- **Results:** sets found → `markFilterNotFinished(.similar)`. None found → `markFilterFinished(.similar)` and the empty state: the stamp, "Every photo is one of a kind", how many photos were compared (the month's scanned assets; a whole-library scan sums the month buckets), the "Keep going" list without Similar, "Continue" (hidden without a month or when it's complete) and "Scan again" ("Try another month" for the dashboard and Lucky sources). The view is added once and hidden when a scan starts; the bin is suppressed.
- **Everything confirmed** (the last Confirm on this visit, or "Confirm all"): the stamp, "Every set is checked", "8 sets in August. ~73 MB waits in the bin until you empty it." (a library scan: "in your library"), an accessory with this visit's `ReviewSplitCardView` over `MonthNextStepsView` without Similar (month keys only), "Continue" (the month's All Photos deck; hidden when the month is complete) beside the bin in a `BinSlot.compactWidth` slot, and "Undo all", which reverts this visit's sets and shows the list again. Without "Continue", "Undo all" takes its place beside the bin. Reopening a month whose sets were all confirmed earlier shows the list of collapsed rows, not this state.

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
     - the cleaned-up state: the stamp, "All cleaned up", "N items went to Recently Deleted…", a card with "You freed" over the size (left out when the size is 0; no all-time figure, since `StatsStore` counts swipes), "Review another month" (Photos tab, pop to root) and "Done" (pop)
  4. **Failure:**
     - `PHPhotosErrorDomain` 3072 (the user cancelled the system dialog) is silent.
     - Other errors show an alert. Over 500 assets, it offers "Try in parts": chunks of 500.
     - A failed chunk offers Try again or "Report to developer" (`MFMailComposeViewController` to `zeynep.muslim@icloud.com` with the error, device, iOS and app version).
- **Empty bin:** a trash symbol, the bin's title and what the bin is for; a tappable card with `MonthProgressRowView` for the bin's own month while it has work left, else the newest month in progress that still exists in the month buckets, else none; "Review <month>" opens that month's hub on its tab ("Review photos" opens the Photos tab without one). The bar items are disabled and the floating bin is suppressed (`setBinButtonSuppressed`); both empty states sit on `.mainBackground`.

### Undo history (`Screens/UndoHistory`)
- **Both sheets are plain native sheets** (no `prefersEdgeAttachedInCompactHeight`, no `widthFollowsPreferredContentSizeWhenEdgeAttached`): the Duo's inner display held sideways gets the system's centered sheet (about 650pt), never an edge-to-edge one.
- **The list sheet** (`UndoHistoryViewController`, medium and large detents): the current session's actions, newest first, with a stats header (the item count, then colored delete / keep / store counts at both detents). On load it removes actions whose asset no longer exists, and it dismisses itself when the list is empty.
  - **Background:** solid on every iOS version: a `UIColor { … }` that resolves `.systemGroupedBackground` per appearance, with `isOpaque = true`, so the iOS 26 sheet doesn't turn it into glass. It resolves at the base level (black in dark mode): a sheet's elevated dark gray is the rows' own `.cardBackground`, and the card would disappear into it. The nav bar is transparent. Rows are `.cardBackground`, a selected row `.systemGray5`.
  - **Rows** (`UndoHistoryCell`): an `ActionRuleCapsuleView`, the action's title over its time, and a 60pt thumbnail. The multiple-selection circle is `.systemBlue` (green would read as Keep).
  - **Edges:** a `ProgressiveBlurView` on both, fading into the sheet's background and showing only while rows are under it (`updateTopBlur()`, `updateBottomBlur()`): the top one under the header (`EdgePadding.content` tall), the bottom one a band at the bottom edge (safe-area bottom + `Layout.blurBandHeight`) that also covers the toolbar in edit mode. The table uses no system edge effect, so nothing stacks on the blurs.
  - **Insets** (`updateListInsets()`): the title sits right under the nav bar; the first row rests 12pt under the stats label (the table's top content inset; the section header, the section footer and the table footer have no height), so rows scroll up under the top blur. The last row rests at the safe-area bottom (`EdgePadding.medium` above the edge on a home-button phone), or 12pt above the toolbar in edit mode.
- **Tapping a row** opens `HistoryDetailBottomSheet` (medium detent, solid `.systemBackground`): the media card, a title row (an `ActionRuleCapsuleView`, the action's title, its time) and Keep | Delete | Store.
  - **Media card:** a rounded card (`CornerRadius.card`) that hugs the asset's own aspect ratio (clamped to 9:16…16:9, aspect-fill inside), as large as fits the preview area and centered in it, sized in `viewDidLayoutSubviews` through stored constraints (`updateMediaCardSize`; below required priority, with required limits to the area, so a card sized for another layout never overflows). A video shows its poster with a play badge; nothing plays in the sheet. The whole card is the tap target ("Enlarge").
  - **Grow:** a tap grows the card through `PhotoGrowPresenter` to the asset's real aspect ratio inside the safe area (table pose: the raised half; book pose: the larger side of the fold), then the photo is upgraded to `.full`. A video loads into a `VideoPlayerController` once grown: its layer over the poster, and its controls centered under it, at most 560pt wide: `VideoPlayerController`'s `.bar` layout, one glass capsule with play, time, scrubber, duration and sound in a row, as wide as the video (360…560pt, never wider than the room). No button sits on the video; a tap on the video toggles play / pause, a tap outside or the close button stops it and shrinks the poster back. Folding or unfolding while it is open moves the video, its layer and its bar to the new room (`layoutGrownVideo`). In the table pose the photo or video stands on the raised half and the video's bar is centered on the base; in the book pose both keep to the larger side of the fold. A failed load leaves what is showing.
  - **Actions:** three `DynamicGlassButton`s with the toolbar's filled icons (`checkmark.circle.fill` / `trash.fill` / `archivebox.fill`); the chosen one is `.prominent` glass in its color with `displayInk` and can't be tapped (locked with `isUserInteractionEnabled`, since a disabled glass button dims), the others are `.regular` glass with the icon drawn in its color. A tap sets `selectedType`, restyles the segments and the title row (`applySegmentStyles(animated:)`, a 0.2 s cross-dissolve, none with Reduce Motion), plays a selection haptic, disables the buttons, and after 0.4 s the sheet closes and calls `onKeepTapped` / `onDeleteTapped` / `onStoreTapped`, exactly once even when the sheet is dragged away during the delay.
  - **Colors, ink and titles** come from `UndoAction.ActionType.displayColor` / `displayInk` / `displayTitle` (segments, capsules, rows, the toolbar's solid buttons).
  - **Duo:** one column on every display; its content spans the sheet's width and only rows the camera overlaps narrow (`updateOcclusionClearance`). In the centered sheet the middle segment may sit on the fold line while fully open (a deliberate exception, as on the photo access sheet).
- **Edit mode:** multi-select with a Keep / Delete / Store / Undo toolbar. Titles show only when the widest one fits a button of the toolbar's own width on one line (`shouldShowToolbarTitles`), icons only otherwise (the Duo's cover display, most phones), re-evaluated on every size change. In light mode the buttons are solid in the action's color with its `displayInk`; in dark mode clear glass with the glyph in the action's color.
- **"Undo all"** asks first.
- **Undo vs change type:**
  - **Undo** removes the action and puts the asset back in the deck.
  - **Changing an action's type** keeps the deck position and the review count.

### Settings (`Screens/Settings`)
One scroll view (iPhone 17, the Duo's cover display, Split View), top to bottom. Its content's sides follow the safe area and the rail through `DuoEdgeConstraints` (20pt, `EdgePadding.content`); the scroll view itself spans the full width.
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
- **iPhone Duo inner display** (`updateFoldSplit()`, re-checked on every layout pass, only where `FoldRegion.splittingFold` crosses the view; a horizontal fold only in regular width):
  - **Held sideways: two panes**, each its own vertical scroll view (`contentInsetAdjustmentBehavior = .never`, starting at the safe area's top), in a container that runs to the view's bottom edge, so nothing clips above it; a pane ending there gets a bottom content inset (`updatePaneInsets`) so its last card rests on Home's baseline (20pt on the rail, else 16pt above the safe area). The first pane fits its height exactly and doesn't bounce: its stack is at least the pane's height (`firstPaneFillHeight`) and `ImpactTilesView` (lowest vertical hugging) takes the slack; Rate | Feedback fit one line in Turkish thanks to 8pt side insets. The panes run from the device's top edge with the top safe area as their top inset, so they rest below the bar and scroll on up to the edge instead of being cut off under it; the bar doesn't track either pane (tracking one collapsed the title and moved both panes). The bar can take its height after the first layout, and with nothing pinned to the safe area's top that change alone doesn't lay out again, so `viewSafeAreaInsetsDidChange` calls `setNeedsLayout`. On iOS 26 the panes' `topEdgeEffect.style` is `.soft`, so rows fade out progressively under the title instead of under a solid band. `rebuildContent(for:)` runs only when the `SplitLayout` changes and moves the same view instances between the single column, the panes and the upright layout.
  - **The gap at the fold** (both orientations) is the section spacing (24) centered on the fold line while fully open, and clears the whole fold region while partly folded, so folding moves only the gap.
  - **Held sideways** (vertical fold, board S3t): left `ImpactTilesView`, `StorageAnalysisView`, then `SettingsSupportCardView` with no Support label (the card has its own title), the cards 10pt apart; right Photo Management, Features, Transparency & Safety and About as grouped rows (`SettingsGroupView`).
  - **Upright** (horizontal fold, board ST4), fully open and partly folded: the raised half holds `ImpactTilesView`, then Storage (47% of the row) | Support side by side, with no section labels (the cards carry their own titles), ending together (Storage sits in `storageCardSlot`, a card-colored wrapper that grows with the row, because stretching `StorageAnalysisView` would stretch one of its rows; the slot starts with `storageTitleRow`, an icon and "Your Storage" (`settings.storageCardTitle`) built like the support card's title row and level with it); the base holds the settings groups and About as grouped rows. `SplitLayout` picks how it scrolls (`.uprightScroll` / `.uprightPanes`), and `rebuildContent(for:)` runs when it changes:
    - **Fully open: one scroll view** (the single column's, which the bar tracks): `raisedHalfStack` sits at its top with a minimum height (`raisedHalfMinHeight`) reaching the gap before scrolling, the Storage | Support row taking the extra height, and the gap is the custom spacing after it; content taller than the space above the fold just pushes the base down.
    - **Partly folded (table pose): the raised half stands still, only the base scrolls.** The raised half is the first pane, ending at the gap (`firstPaneEdgeToHorizontalFold`) and filling it (`firstPaneFillHeight`); the second pane starts `baseTopClearance` (10) below it, with the rest of the gap as its top inset. A `ProgressiveBlurView` fills that inset: rows scrolling up blur and fade into the background, and the blur fades in only as far as they've scrolled under it (`setContentOverlap(_:)`), because the material's tint would show as a gray band at rest.
  - The single column's `ImpactStatsView`, `supportCard` and help rows, and its toggle/info cards, don't show in the split layouts.
  - **Grouped rows (board S3t)** replace the settings cards in both split layouts: Photo Management (Internet Access, Skip iCloud Photos with short subtitles), Features (Reminders, Schedule menu, App Language showing the current language, Store Feature), Transparency & Safety (Privacy First, View Source Code), About (Version from `CFBundleShortVersionString`). Rows and cards share one path per setting (`setInternetAccess`, `setSkipICloud`, `setReminders`) and the `update…State` methods sync both. Section labels sit 8pt above their card, groups 20pt apart.
- `scrollToInternetToggle()` scrolls whichever scroll view holds the toggle (the second pane while split) and pulses it. Its caller, MonthReview's `openSettingsTab()`, is currently unreachable.

### Tip jar (`TipJarViewController`, `TipJarManager`)
- **Products** (StoreKit 2, consumable, `Purgio/Services/TipProducts.storekit`), sorted by price:
  - `com.zeynepmuslim.purgio.tip.small` (0.99)
  - `com.zeynepmuslim.purgio.tip.medium` (2.99)
  - `com.zeynepmuslim.purgio.tip.large` (4.99)
- **Internet gate:** with internet off, the sheet shows a `SlideToConfirmButton` gate (85% threshold).
  - Confirming calls `SettingsStore.beginTemporaryInternetOverride()`. Closing the sheet calls `endTemporaryInternetOverride()`, and Settings briefly confirms that the setting is restored.
  - StoreKit traffic doesn't depend on the app's setting. The gate is a privacy courtesy.
- **Layout:** the heart beside the title and note, the three `TipTier` capsules (small 0.5, medium 0.75, large 1 of the capsule area), and a footer with the send button (or the gate's slider in its slot). Content scrolls above the footer, capped at 420pt wide.
  - **Detents:** medium, except large when the window is `<= 667` tall or on either Duo display (`isDuoDisplay`: regular width, or compact width with a horizontal safe area). A medium sheet whose content doesn't fit first tightens its gaps (`Layout.Tight`), then moves to large, once each (`growToLargeDetentIfNeeded`). At full height the icons sit above centered texts.
  - **Table pose:** the header above the fold, the picker or gate below it (`updateTableFoldLayout`).
- **Flow:** the middle tier is chosen when the sheet opens; tap another to change it, then "Send <price> tip".
  - **Success:** a red capsule with a heart and a check badge, "Tier · price" under the title, success haptic, a VoiceOver announcement; dismisses itself after 2 s.
  - **Cancelled or pending:** back to idle.
  - **Failure:** an alert.
- **Transactions:** `Transaction.updates` is verified and finished. Refunds are only logged.
- **Local testing:** the shared scheme doesn't attach the `.storekit` file. Select it under Edit Scheme → Run → Options.

## Empty and finished states

Board "Empty & finished states · A + B". Two rules: **the stamp means done and a dashed capsule means not started** (never use either as decoration), and **every state points somewhere**: when the month still has work, its open filters sit under the message, then the primary action.

- **`EmptyStateView`** (`Purgio/Views`) has two shapes:
  - `configure(icon:iconColor:title:message:actionTitle:onAction:…)`: the small centered stack. No screen uses it any more (only its previews); new states use the board layout.
  - `configure(hero:title:message:accessory:actionTitle:actionIcon:onAction:secondaryTitle:onSecondary:)`: the board layout.
    - **Hero:** `.stamp` (a `ReviewStampView`, 40×120 with a 10/12-wide capsule) or `.symbol(name)` (thin, 96pt, `.systemGray3`, no background). Title 26pt heavy, message 16pt `.secondaryLabel`, centered in the room above the actions.
    - **Actions column**, resting on Home's baseline (`DuoEdgeConstraints`, `EdgePadding.content` sides, `Spacer.buttonBottom`): the `accessory` view (full width, owns its height), the ink primary `DynamicGlassButton` (`ButtonSize.large`, optional leading icon) and a plain text secondary (44pt).
    - **Bin slot:** `trailingSlotWidth` reserves a slot beside the primary button; the host sends `trailingSlotFrameInWindow` to `setBinButtonPlacement(.slot(rect))` on layout (MonthReview's month-complete state; MonthsList's states that keep the bin). With a slot and a secondary but no primary (SimilarPhotos' finished state in a complete month), the secondary takes the primary's place beside the slot, so the bin still has a row.
    - **Short column:** in `layoutSubviews`, when the message group has under 280pt, the hero drops to 32×96 (symbol 72pt), the title to 22pt and the gaps tighten (iPhone SE, the Duo's cover display). Nothing scrolls, and the change never animates.
    - **Layout modes:** picked on every layout pass from `FoldRegion` (`currentMode()`), one stored constraint set each (`modeConstraints`):
      - `.column` (no `splittingFold`: phones, the cover display, Split View): the hero group centered in the room above the actions, the actions on the baseline.
      - `.openSideways` (vertical `splittingFold`, no `activeFold`): one group, the hero group right above the actions with 28pt between them, min(440, content width) wide and centered in the content area. It may cross the fold line (see **iPhone Duo**).
      - `.openUpright` (horizontal `splittingFold`, regular width, no `activeFold`): the hero group centered in the room above the actions (not on the device), at least 20pt above them, and the actions stay on the baseline. The centering sits just below the message's compression resistance, so a very tall actions column pushes the group up whole instead of squeezing its message out.
      - `.book` (vertical `activeFold`): the hero group centered in the leading half, the actions centered in the trailing half, both clearing the whole fold region.
      - `.table` (horizontal `activeFold`): the hero group centered in the raised half, ending at `fold.minY − Spacer.foldGap`; the actions on the baseline.
    - **Fold transition:** `updateLayoutMode()` swaps the sets only when the mode changes. `.openSideways` ↔ `.book` and `.openUpright` ↔ `.table` spring (0.4 s, damping 0.75, velocity 0.8, `.beginFromCurrentState`), the hero group and the actions each moving as one piece; a change of fold axis (rotation, cover ↔ inner display) and the first layout aren't animated. The fold's distances follow the hinge on every pass. `onLayoutModeChange` runs inside the spring once the new layout is in place: a host with a bin slot sends `trailingSlotFrameInWindow` again there and lays out the tab bar controller's view, so the bin moves with the row (MonthReview, MonthsList).
    - **Hosts** pin its sides to `view.safeAreaLayoutGuide` and its top and bottom to `view`, add it once, and call `update(railEdge:)` from `viewDidLayoutSubviews`. `hide(animated: true)` removes it from its superview; hosts that keep it use `hide(animated: false)`.
    - **VoiceOver:** the hero is hidden; title (header), message, accessory, primary, secondary, in that order.
- **The floating bin** would sit on the bottom row: hosts call `setBinButtonSuppressed(true)` while a state shows, or give it a slot.
- **The filter model is shared** (`Screens/MonthFilterCards/FilterType+Route.swift`, an extension of `MonthFilterStatusStore.FilterType`): `hubOrder(for:)`, `cardIcon` / `cardTitle` / `cardTint`, `sentenceName(mediaType:)` (lowercase `filterName.*` keys for use inside a sentence), `isComplete(monthKey:mediaType:)`, `applyStatus(to:monthKey:mediaType:)` (a complete month completes every card; else the finished flag, then the filter's own record; All Photos and Largest First read the main key) and `makeViewController(monthTitle:monthKey:mediaType:yearAssets:navigationSource:)`, the one route (Similar → `SimilarPhotosViewController`, Largest / Eyes Closed → `ProcessingLoadingViewController`, the rest → `MonthReviewViewController`). The hub and `MonthNextStepsView` both use it; don't route to a filter any other way. `ReviewProgressStore.isComplete(monthKey:mediaType:)` is the "complete" test as a call.
- **Where each state lives:** MonthReview (a filter found nothing, no photos, month complete, filter complete), SimilarPhotos (none found, every set checked), DeleteBin (empty, cleaned up), MonthsList (no months of this type, empty library, the access levels). See those screens.

## Floating bin button

There is **one global `FloatingBinButton`**, owned by `MainTabBarController` and added to its view. Screens never own a bin button.
- **Display modes:**
  - `.count(n)`: the plain bin count.
  - `.increment(n)`: "+n" during a review session.
  - `.wide`: "Delete All" / "Delete" on DeleteBin.
  - Morph with `morphToWide` / `morphToCompact`. Counts use a monospaced digit font. In a slot (`setFitsSlot(_:)`, set by `setBinButtonPlacement`) the side insets drop to `EdgePadding.small`, the title stays on one line and counts above 99 show "99+" (increments stay `compactFormatted`). `FloatingBinButton.slotWidth(forCount:)` measures the width a slot needs for a count, for screens that size the slot to the button. The `accessibilityIdentifier` is `floatingBinButton`.
- **Screens drive it through `FloatingBinButtonController`:**
  ```swift
  private var binController: FloatingBinButtonController? { tabBarController as? FloatingBinButtonController }
  binController?.configureBinButton(mode: .count(n), monthKey: monthKey, monthTitle: monthTitle,
                                    tapHandler: { [weak self] in self?.handleBinTap() })
  ```
  - Other methods: `configureWideBinButton(title:monthKey:monthTitle:tapHandler:)`, `showBinButton()`, `hideBinButton()`, `setBinButtonSuppressed(_:)` (hides the button while an empty or finished state's own bottom row takes its place; every push, pop and tab switch turns it off, so a screen suppresses again in `viewDidAppear`).
  - Configure it in `viewWillAppear`. MonthReview and SimilarPhotos hide it when they're popped.
- **Visibility:** hidden on the Home and Settings tabs, unless the top view controller is MonthReview, MonthFilterCards, ProcessingLoading, DeleteBin or SimilarPhotos (Lucky and dashboard pushes). It isn't updated during an animated transition.
- **Mode changes:**
  - `navigationController(willShow:)` morphs it to wide for DeleteBin. `didShow` morphs it back, except on DeleteBin.
  - A tab switch resets the handler, the month context, the mode (dropping `savedMode`, the mode saved for the screen under DeleteBin, which the new tab's `navigationController(didShow:)` would otherwise restore) and the placement in `tabBarController(_:shouldSelect:)`, before the switch, so the new tab's screens configure it afterwards (`didSelect` only updates visibility).
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
  - **Slot placement:** `setBinButtonPlacement(.slot(windowRect))` pins the button into a rect a screen hands over (MonthReview's sideways bottom row and its month-complete state's bottom row; MonthFilterCards' bottom row on every size: as wide as the bin's icon and count in a bottom row, the filters column's width sideways; SimilarPhotos' bottom row and its finished state's row; ProcessingLoading's bottom row); `.standard` restores the constraints above. `.slot(rect, matchesHeight: true)` also makes the button as tall as the slot (SimilarPhotos' 50pt row on short columns); otherwise it keeps `ButtonSize.large`. `.slot(rect, showsTitle: true)` puts the title before the count ("Bin · 14", "Bin" while empty; `floatingBin.*` keys) through `FloatingBinButton.setShowsTitle(_:)`; MonthFilterCards asks for it only sideways, where the slot spans the filters column. `.standard` turns it off. A tab switch (before it happens) and every push or pop (`navigationController(willShow:)`) reset it to `.standard`, so the screen sends its slot again once it is on top and whenever the rect moves.

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
  - `StorageAnalysisView`: the full card, in Settings.
  - `StorageAnalysisLiteView`: Home's compact version, whose header switches layout under 390pt.
  - **Legends** (`layoutLegendItems`): marks are `LegendCapsule`s. They lay out from the leading edge, by the card's own width (`CompactContentWidth.fullWidthCard`): the lite card packs a row that fits (3 regular, 2 compact); otherwise a grid of 2 columns (compact, or 4 items) or 3, five regular items as (2, 2, 1) equal thirds. An item wider than its column gets its own row at the end, and the legend is re-laid out when the card's width changes.
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
  - **Shared strings** alias `CommonStrings` (`Purgio/Others/Constants.swift`: `remove`, `cancel`, `delete`, `ok`, `keep`, `store`).
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
- **One undo stack per month and media type.** The session key is `(monthKey, mediaType)`, so every filter session of a month shares one stack, and the stack survives relaunches.
  - `UndoAction.index` points into the `reviewAssets` of the session that recorded it, so it is stale in other sessions and after the library changes. Never index with it: undo resolves the asset by `assetLocalIdentifier` (`deckIndex(of:)` in `MonthReviewViewController+UndoHistory.swift`) and leaves the deck where it is when the asset isn't in it.
- **Swipe undo doesn't remove an asset from the PhotoKit album.** History-sheet undo and Similar undo do.
- **`StatsStore` counts swipes, not deletions.** `recordDeletion` runs on a left swipe and is reversed by undo. Real deletion in DeleteBin doesn't touch it, and doesn't clean the kept and stored stores either.
- **Dashboard and Lucky routes skip ProcessingLoading.** `.largeFiles` and `.eyesClosed` from them show the month unsorted and unfiltered. Only MonthFilterCards goes through `ProcessingLoadingViewController`.
- **Reminders ignore the user's chosen time details.** The minute is `Int.random(0...59)` and weekly reminders use one random weekday; `reminderMinute` and `reminderWeekdays` are ignored.
- **Home:**
  - It doesn't reload after the permission grant: the sheet's dismissal doesn't trigger `viewWillAppear`, and Home doesn't observe `.photoAuthorizationGranted`.
  - The dashboard card only applies freshly generated content after the user has left Home once (`hasNavigatedAway`).
- **Hard-coded English user-facing strings:**
  - `FilterStatus` raw values in MonthsList's menu
  - "Skip" in `SwipeCardView` and `iCloudWarningSheet`
  - `MediaPreviewViewController` "Undo" and "Failed to load…"
  - `FloatingBinButton.morphToWide`'s "Delete All" (overridden immediately)
  - MonthReview's "Internet access enabled…" alert
  - the resume card's `formattedProgress`
  - Live Activity `statusMessage`s
  - `TipJarManager.StoreError`
  - the "Will Be Stored" album name
- **DeleteBin** prints `[BIN DEBUG]` / `[BIN SYNC]` lines in `numberOfItems` / `cellForItem` without `#if DEBUG`.
- **Screens outside the Duo work pin their horizontal edges to `view` instead of the safe area** (sheets, Onboarding; see **iPhone Duo**).
- **`PHPhotoLibraryPreventAutomaticLimitedAccessAlert` isn't set,** so iOS may show its own "select more photos" alert.
- **Storage analysis:**
  - The resume indices can point at different assets if the library changed in between.
  - `chunkSize = 500` is declared twice.
  - `cancelAnalysis()` and `performBasicOnlyAnalysis()` have no callers.
- **Cancelling a filter scan doesn't stop the work.** `PhotoProcessor`'s streams run in an inner `Task` that nobody cancels (no `onTermination`), so after Cancel on the loading screen the scan runs to its end unseen.
- **Unused `processing.*` strings** since the loading screen's redesign (rows kept in the CSV): `analyzingFileSizes`, `calculating`, `estimateRemaining`, `initializingDetector`, `loadingPhotos`, `scanningFaces`, `warmingUp`.
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
- **Shared extensions:** helpers go in `Others/Extension++.swift` (`Int.compactFormatted`, `Int.roundedPercent(of:)` (the percent every progress text shows: rounded, 1…99 while in progress), `Int64.formattedBytes()`, `UIView.spacer`, `UIImage.resized(to:)`, `UIImage.availableSymbolName(_:)` (the first SF Symbol name this iOS has, for symbols newer than iOS 15)). Type extensions go in `Type+Topic.swift`.
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
