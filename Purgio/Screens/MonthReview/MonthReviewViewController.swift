//
//  MonthReviewViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import AVFoundation
import Photos
import SwiftUI
import UIKit

private enum Strings {
    static func screenshotsTitle(month: String) -> String {
        String(format: NSLocalizedString("monthReview.screenshotsTitle", comment: "Screenshots filter title with month, e.g. 'Screenshots · January 2025'"), month)
    }
    static func largeFilesTitle(month: String, isVideo: Bool) -> String {
        let format = isVideo
            ? NSLocalizedString("monthReview.largeVideosTitle", comment: "Large videos filter title with month")
            : NSLocalizedString("monthReview.largePhotosTitle", comment: "Large photos filter title with month")
        return String(format: format, month)
    }
    static func eyesClosedTitle(month: String) -> String {
        String(format: NSLocalizedString("monthReview.eyesClosedTitle", comment: "Eyes closed filter title with month"), month)
    }
    static func screenRecordingsTitle(month: String) -> String {
        String(format: NSLocalizedString("monthReview.screenRecordingsTitle", comment: "Screen recordings filter title with month"), month)
    }
    static func slowMotionTitle(month: String) -> String {
        String(format: NSLocalizedString("monthReview.slowMotionTitle", comment: "Slow motion filter title with month"), month)
    }
    static func timeLapseTitle(month: String) -> String {
        String(format: NSLocalizedString("monthReview.timeLapseTitle", comment: "Time-lapse filter title with month"), month)
    }
}

enum FilterContext {
    case none
    case screenshots
    case largeFiles
    case eyesClosed
    case screenRecordings
    case slowMotion
    case timeLapse
}

/// Which control fills the base in the iPhone Duo table pose (see +TablePose).
/// Persisted in `SettingsStore.tablePoseControlsLayout`.
enum TablePoseControlsLayout: String {
    /// A swipe area that drives the raised card like a direct swipe.
    case trackpad
    /// A Store key over Delete and Keep keys.
    case keys
}

final class MonthReviewViewController: UIViewController {

    public var isFilterResultMode = false
    public var isSizeBadgeOpen = false
    var navigationSource: NavigationSource = .manual

    let cardContainerView = UIView()
    let statsLabel = UILabel()
    let bottomControlsStack = UIStackView()

    lazy var leftGradient = GradientView()
    lazy var rightGradient = GradientView()
    lazy var topGradient = GradientView()

    let undoButton = UIButton(type: .system)
    let historyButton = UIButton(type: .system)
    let historyBadge = UILabel()
    let binSpacerView = UIView() 

    let videoController = VideoPlayerController(configuration: .init(
        videoGravity: .resizeAspect,
        layerCornerRadius: 16,
        controlsAutoHide: true
    ))

    let loadingIndicator = UIActivityIndicatorView(style: .large)

    lazy var emptyStateView = EmptyStateView()

    var skeletonStack: SkeletonStackView?
    var skeletonStatsView: SkeletonStatsView?
    var navProgressRing: MiniProgressRing?

    let photoLibraryService = PhotoLibraryService.shared
    let deleteBinStore = DeleteBinStore.shared
    let progressStore = ReviewProgressStore.shared
    let statsStore = StatsStore.shared
    let willBeStoredStore = WillBeStoredStore.shared
    let historyManager = UndoHistoryManager.shared
    let haptics = HapticFeedbackManager.shared
    let settingsStore = SettingsStore.shared
    let imageCache = ImageCacheService.shared
    lazy var imageManager = PHCachingImageManager()

    var reviewAssets: [ReviewAsset] = []
    var currentIndex = 0
    var deletedCount = 0
    var keptCount = 0
    var storedCount = 0
    var originalTotalCount = 0
    var cardStack: [SwipeCardView] = []
    var imageRequestIDs: [String: PHImageRequestID] = [:]
    var loadingTask: Task<Void, Never>?

    var sessionIncrementCount = 0 // for delete swiping

    var binController: FloatingBinButtonController? {
        tabBarController as? FloatingBinButtonController
    }

    var preSortedAssets: [PHAsset]?
    var preComputedAssets: [ReviewAsset]?
    var isFilteredView: Bool {
        return preSortedAssets != nil || preComputedAssets != nil
    }
    var isNavigating = false

    var isShowingICloudWarning = false

    var historyBadgeWidthConstraint: NSLayoutConstraint!
    var binSpacerWidthConstraint: NSLayoutConstraint?

    enum Layout {
        /// Between the card and the bottom controls row (also the skeleton's bottom).
        static let cardToControlsGap: CGFloat = 20
        /// Between the undo, history and bin spacer in the standard bottom row.
        static let controlsSpacing: CGFloat = GeneralConstants.EdgePadding.medium
        /// Narrowest the split video capsules get before falling back to two equal halves
        /// (play + scrubber + time | mute + duration).
        static let videoLeadingCapsuleMinWidth: CGFloat = 160
        static let videoTrailingCapsuleMinWidth: CGFloat = 100
        /// Same gap in the iPhone Duo sideways layout (see +Landscape).
        static let landscapeCardToRowGap: CGFloat = 12
        /// Room the sideways card area keeps around a photo card so the cards behind it can fan out.
        static let landscapeDeckInset = NSDirectionalEdgeInsets(top: 10, leading: 34, bottom: 10, trailing: 34)
        /// Scale a card starts at as it fades in at the back of the deck.
        static let deckEntryScale: CGFloat = 0.92
        /// Width / height range every sideways photo card is shown in (9:16 to 16:9); a photo
        /// outside it is fitted inside the card over its blurred backdrop.
        static let landscapeCardRatioRange: ClosedRange<CGFloat> = (9.0 / 16.0)...(16.0 / 9.0)
        /// Clearance between the iPhone Duo fold and the content on either side of it (see +Fold, +TablePose).
        static let foldGap: CGFloat = 12
    }

    // iPhone Duo fold layout (see +Fold): constraint sets swapped by pose
    var flatLayoutConstraints: [NSLayoutConstraint] = []
    var tablePoseLayoutConstraints: [NSLayoutConstraint] = []
    var cardBottomToFoldConstraint: NSLayoutConstraint?
    var playPauseCenterXConstraint: NSLayoutConstraint?
    var undoHistoryEqualWidthConstraint: NSLayoutConstraint?
    var undoTrailingToFoldConstraint: NSLayoutConstraint?
    var currentFoldPose: FoldRegion.Pose = .flat
    var duoEdges: [DuoEdgeConstraints] = []
    /// Edges of the loading skeleton; cleared when it's removed.
    var skeletonDuoEdges: [DuoEdgeConstraints] = []
    var cardBottomToControlsConstraint: NSLayoutConstraint?
    var overlayPlayButtonConstraints: [NSLayoutConstraint] = []
    var videoControlsOverlayConstraints: [NSLayoutConstraint] = []
    var videoControlsSplitConstraints: [NSLayoutConstraint] = []

    // iPhone Duo inner display held sideways (see +Landscape)
    var isLandscapeDeckActive = false
    var hasSetupLandscapeViews = false
    let leftGrip: ActionGripView = {
        let grip = ActionGripView()
        grip.translatesAutoresizingMaskIntoConstraints = false
        return grip
    }()
    let rightGrip: ActionGripView = {
        let grip = ActionGripView()
        grip.translatesAutoresizingMaskIntoConstraints = false
        return grip
    }()
    let statsPill: ReviewStatsPillView = {
        let pill = ReviewStatsPillView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        return pill
    }()
    // Inner display: the stats as a capsule (see +Landscape, Stats Pill)
    var hasSetupStatsPill = false
    var statsLabelPillHeightConstraint: NSLayoutConstraint?
    let binSlotGuide = UILayoutGuide()
    var landscapeConstraints: [NSLayoutConstraint] = []
    var rowSplitConstraint: NSLayoutConstraint?
    var binSlotLeadingConstraint: NSLayoutConstraint?
    var rowEqualWidthConstraint: NSLayoutConstraint?
    var cardFillConstraints: [ObjectIdentifier: [NSLayoutConstraint]] = [:]
    var cardHugConstraints: [ObjectIdentifier: CardHugConstraints] = [:]
    var lastSentBinSlot: CGRect?
    /// True while the top card flies off: the cards behind already move into their new places.
    var isPromotingDeck = false
    var didRequestBarRelayoutForCamera = false

    // iPhone Duo table pose (see +TablePose): the controls on the base below the fold
    let tableBaseGuide = UILayoutGuide()
    let tableBaseContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    let tablePoseKeysView: TablePoseKeysView = {
        let keys = TablePoseKeysView()
        keys.translatesAutoresizingMaskIntoConstraints = false
        return keys
    }()
    let tablePoseTrackpadView: TablePoseTrackpadView = {
        let trackpad = TablePoseTrackpadView()
        trackpad.translatesAutoresizingMaskIntoConstraints = false
        return trackpad
    }()
    var tableLayoutBarItem: UIBarButtonItem?
    var tableBaseTopConstraint: NSLayoutConstraint?
    var hasSetupTablePoseViews = false

    let monthTitle: String
    let monthKey: String
    let mediaType: PHAssetMediaType
    let filterContext: FilterContext
    let visibleCardCount = 3

    var compactMonthString: String {
        DateFormatterManager.shared.compactMonth(fromMonthKey: monthKey) ?? monthTitle
    }

    init(
        monthTitle: String, monthKey: String, mediaType: PHAssetMediaType = .image, filterContext: FilterContext = .none
    ) {
        self.monthTitle = monthTitle
        self.monthKey = monthKey
        self.mediaType = mediaType
        self.filterContext = filterContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = screenBackgroundColor
        navigationItem.largeTitleDisplayMode = .never

        switch filterContext {
        case .none:
            title = monthTitle
        case .screenshots:
            title = Strings.screenshotsTitle(month: compactMonthString)
        case .largeFiles:
            title = Strings.largeFilesTitle(month: compactMonthString, isVideo: mediaType == .video)
        case .eyesClosed:
            title = Strings.eyesClosedTitle(month: compactMonthString)
        case .screenRecordings:
            title = Strings.screenRecordingsTitle(month: compactMonthString)
        case .slowMotion:
            title = Strings.slowMotionTitle(month: compactMonthString)
        case .timeLapse:
            title = Strings.timeLapseTitle(month: compactMonthString)
        }

        setupSkeletonLoading()
    }

    var isLoadingPhotos: Bool = true
    var hasSetupUI = false
    var isAnimatingSwipe: Bool = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !hasSetupUI {
            hasSetupUI = true

            let sessionKey = SessionKey(monthKey: monthKey, mediaType: String(mediaType.rawValue))
            historyManager.startSession(with: sessionKey)

            haptics.prepareAll()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.setupMainUI()

                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.undoHistoryDidChange),
                    name: .undoHistoryDidChange,
                    object: nil
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.deleteBinCountDidChange),
                    name: .deleteBinCountDidChange,
                    object: nil
                )

                if self.cardStack.isEmpty {
                    self.setupCardsAndGestures()
                }

                if self.reviewAssets.isEmpty {
                    self.loadPhotos()
                }
            }
        }

        if hasSetupUI && !reviewAssets.isEmpty {
            advanceToFirstUnprocessedIndex()
            refreshStack()
        }

        // The tab bar controller resets the bin button's placement on every push and pop
        if isLandscapeDeckActive {
            lastSentBinSlot = nil
            view.setNeedsLayout()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateLandscapeDeckLayout()
        updateStatsPillVisibility()
        updateBinSpacerWidth(animated: false)
        let railEdge = DuoLayout.railEdge(tabBarController, in: view)
        (duoEdges + skeletonDuoEdges).forEach { $0.update(railEdge: railEdge) }
        updateFoldLayout()
        if usesFannedDeckLayout {
            applyCardSizing()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isMovingToParent {
            sessionIncrementCount = 0 // First entry - reset session counter
        } else { // Returning from child VC (e.g., DeleteBin)
            refreshSessionIncrementCountFromMonthBin()
            refreshHistoryBadgeFromManager()

            if hasSetupUI && !reviewAssets.isEmpty {
                recalculateCountsFromStores()
                updateStats()
                saveProgress()

                advanceToFirstUnprocessedIndex()
                refreshStack()
            } else if hasSetupUI && reviewAssets.isEmpty {
                loadPhotos()
            }
        }
        configureGlobalBinButton()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateBinSpacerWidth(animated: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveProgress()

        loadingTask?.cancel()

        for (_, requestID) in imageRequestIDs {
            imageCache.cancelRequest(requestID)
        }
        imageRequestIDs.removeAll()

        if isMovingFromParent {
            imageCache.stopCachingAllImages()
        }

        cleanupVideo()

        lastSentBinSlot = nil
        binController?.setBinButtonPlacement(.standard)

        if isMovingFromParent {
            binController?.hideBinButton()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("MonthReviewViewController received memory warning - cleaning up")
        cleanupVideo()
        imageCache.stopCachingAllImages()
        imageRequestIDs.removeAll()
    }

    func setSortedAssets(_ assets: [PHAsset]) {
        self.preSortedAssets = assets
    }

    func setPreComputedAssets(_ reviewAssets: [ReviewAsset]) {
        self.preComputedAssets = reviewAssets
    }
}

@available(iOS 17.0, *)
#Preview {
    UINavigationController(
        rootViewController: MonthReviewViewController(monthTitle: "January 2024", monthKey: "2024-01"))
}
