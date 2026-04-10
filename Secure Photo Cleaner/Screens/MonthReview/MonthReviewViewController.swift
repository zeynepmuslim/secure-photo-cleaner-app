//
//  MonthReviewViewController.swift
//  Secure Photo Cleaner
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
    lazy var imageManager = PHCachingImageManager()
    let imageCache = ImageCacheService.shared

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

        view.backgroundColor = .systemBackground
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
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBinSpacerWidth(animated: false)
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
            imageManager.cancelImageRequest(requestID)
        }
        imageRequestIDs.removeAll()

        imageCache.stopCachingAllImages()

        cleanupVideo()

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
