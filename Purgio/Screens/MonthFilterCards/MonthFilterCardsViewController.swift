//
//  MonthFilterCardsViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 24.01.2026.
//

import Photos
import UIKit

private enum Strings {
    static let reviewed = NSLocalizedString("filterCards.reviewed", comment: "Reviewed progress label")
    static let delete = CommonStrings.delete
    static let keep = NSLocalizedString("filterCards.keep", comment: "Keep action label")
    static let store = NSLocalizedString("filterCards.store", comment: "Store action label")
    static let similarTitle = NSLocalizedString("filterCards.similarTitle", comment: "Similar & Duplicated filter title")
    static let similarSubtitle = NSLocalizedString("filterCards.similarSubtitle", comment: "Similar photos filter description")
    static let largestTitle = NSLocalizedString("filterCards.largestTitle", comment: "Largest first filter title")
    static let screenshotsTitle = NSLocalizedString("filterCards.screenshotsTitle", comment: "Screenshots filter title")
    static let screenshotsSubtitle = NSLocalizedString("filterCards.screenshotsSubtitle", comment: "Screenshots filter description")
    static let eyesClosedTitle = NSLocalizedString("filterCards.eyesClosedTitle", comment: "Eyes closed filter title")
    static let eyesClosedSubtitle = NSLocalizedString("filterCards.eyesClosedSubtitle", comment: "Eyes closed filter description")
    static let screenRecTitle = NSLocalizedString("filterCards.screenRecTitle", comment: "Screen recordings filter title")
    static let screenRecSubtitle = NSLocalizedString("filterCards.screenRecSubtitle", comment: "Screen recordings filter description")
    static let slowMotionTitle = NSLocalizedString("filterCards.slowMotionTitle", comment: "Slow motion filter title")
    static let slowMotionSubtitle = NSLocalizedString("filterCards.slowMotionSubtitle", comment: "Slow motion filter description")
    static let timeLapseTitle = NSLocalizedString("filterCards.timeLapseTitle", comment: "Time-lapse filter title")
    static let timeLapseSubtitle = NSLocalizedString("filterCards.timeLapseSubtitle", comment: "Time-lapse filter description")
    static let finished = NSLocalizedString("filterCards.finished", comment: "Finished state label")
    static func largestSubtitle(isVideo: Bool) -> String {
        isVideo
            ? NSLocalizedString("filterCards.largestSubtitleVideos", comment: "Largest videos filter description")
            : NSLocalizedString("filterCards.largestSubtitlePhotos", comment: "Largest photos filter description")
    }
    static func allPhotosTitle(isVideo: Bool) -> String {
        isVideo
            ? NSLocalizedString("filterCards.allVideosTitle", comment: "All videos filter title")
            : NSLocalizedString("filterCards.allPhotosTitle", comment: "All photos filter title")
    }
    static func allPhotosSubtitle(isVideo: Bool) -> String {
        isVideo
            ? NSLocalizedString("filterCards.allVideosSubtitle", comment: "All videos filter description")
            : NSLocalizedString("filterCards.allPhotosSubtitle", comment: "All photos filter description")
    }
}

final class MonthFilterCardsViewController: UIViewController {
    private let statsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressRingView: CircularProgressView = {
        let view = CircularProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: 16, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let progressImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        imageView.image = UIImage(systemName: "checkmark", withConfiguration: config)
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let statsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let reviewedStatView = MonthStatItemView()
    private let deletedStatView = MonthStatItemView()
    private let keptStatView = MonthStatItemView()
    private let storedStatView = MonthStatItemView()

    private let cardsContainerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let topRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        return stack
    }()

    private let middleRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        return stack
    }()

    private let similarCard = FilterCard()
    private let largestCard = FilterCard()
    private let screenshotsCard = FilterCard()
    private let eyesClosedCard = FilterCard()
    private let screenRecordingsCard = FilterCard()
    private let slowMotionCard = FilterCard()
    private let timeLapseCard = FilterCard()
    private let allPhotosCard = FilterCard()

    private let photoLibraryService = PhotoLibraryService.shared

    private var binController: FloatingBinButtonController? {
        tabBarController as? FloatingBinButtonController
    }

    private var mediaTypeDebugName: String {
        switch mediaType {
        case .image:
            return "image"
        case .video:
            return "video"
        default:
            return "unknown(\(mediaType.rawValue))"
        }
    }

    private let monthTitle: String
    private let monthKey: String
    private let mediaType: PHAssetMediaType
    private let horizontalPadding: CGFloat = 16
    private let cardSpacing: CGFloat = 12
    private var binCountTask: Task<Void, Never>?

    init(monthTitle: String, monthKey: String, mediaType: PHAssetMediaType = .image) {
        self.monthTitle = monthTitle
        self.monthKey = monthKey
        self.mediaType = mediaType
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        let mediaSuffix = mediaType == .video
            ? NSLocalizedString("home.videosTitle", comment: "Videos label")
            : NSLocalizedString("home.photosTitle", comment: "Photos label")
        title = "\(monthTitle) · \(mediaSuffix)"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        setupUI()
        setupConstraint()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateStats()
        configureGlobalBinButton()
        checkForNewContentAndResetFinished()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            binCountTask?.cancel()
        }
    }

    private func setupUI() {
        reviewedStatView.configure(title: Strings.reviewed, color: .systemGray)
        deletedStatView.configure(title: Strings.delete, color: .systemRed)
        keptStatView.configure(title: Strings.keep, color: .systemGreen)
        storedStatView.configure(title: Strings.store, color: .systemYellow)

        statsContainerView.addSubview(progressRingView)
        statsContainerView.addSubview(progressLabel)
        statsContainerView.addSubview(progressImageView)
        statsContainerView.addSubview(statsStackView)

        [reviewedStatView, deletedStatView, keptStatView, storedStatView].forEach {
            statsStackView.addArrangedSubview($0)
        }

        view.addSubview(statsContainerView)

        configureCards()

        topRowStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        middleRowStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if mediaType == .video {
            topRowStack.addArrangedSubview(slowMotionCard)
            topRowStack.addArrangedSubview(largestCard)
            middleRowStack.addArrangedSubview(timeLapseCard)
            middleRowStack.addArrangedSubview(screenRecordingsCard)
            middleRowStack.isHidden = false
        } else {
            topRowStack.addArrangedSubview(similarCard)
            topRowStack.addArrangedSubview(largestCard)
            middleRowStack.addArrangedSubview(eyesClosedCard)
            middleRowStack.addArrangedSubview(screenshotsCard)
            middleRowStack.isHidden = false
        }

        cardsContainerStack.addArrangedSubview(topRowStack)
        cardsContainerStack.addArrangedSubview(middleRowStack)
        cardsContainerStack.addArrangedSubview(allPhotosCard)

        view.addSubview(cardsContainerStack)
    }

    private func setupConstraint() {
        let safeArea = view.safeAreaLayoutGuide
        let statsHeight: CGFloat = 80
        let bottomPadding: CGFloat = 16

        NSLayoutConstraint.activate([
            statsContainerView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 16),
            statsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalPadding),
            statsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalPadding),
            statsContainerView.heightAnchor.constraint(equalToConstant: statsHeight),

            progressRingView.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 16),
            progressRingView.centerYAnchor.constraint(equalTo: statsContainerView.centerYAnchor),
            progressRingView.widthAnchor.constraint(equalToConstant: 56),
            progressRingView.heightAnchor.constraint(equalToConstant: 56),

            progressLabel.centerXAnchor.constraint(equalTo: progressRingView.centerXAnchor),
            progressLabel.centerYAnchor.constraint(equalTo: progressRingView.centerYAnchor),

            progressImageView.centerXAnchor.constraint(equalTo: progressRingView.centerXAnchor),
            progressImageView.centerYAnchor.constraint(equalTo: progressRingView.centerYAnchor),
            progressImageView.widthAnchor.constraint(equalToConstant: 24),
            progressImageView.heightAnchor.constraint(equalToConstant: 24),

            statsStackView.leadingAnchor.constraint(equalTo: progressRingView.trailingAnchor, constant: 16),
            statsStackView.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -12),
            statsStackView.centerYAnchor.constraint(equalTo: statsContainerView.centerYAnchor),
            statsStackView.heightAnchor.constraint(equalToConstant: 50),

            cardsContainerStack.topAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: cardSpacing),
            cardsContainerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalPadding),
            cardsContainerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalPadding),
            cardsContainerStack.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -bottomPadding)
        ])
    }
    
    private func configureCards() {
        // Similar & Duplicated Card (photos only)
        similarCard.configure(
            icon: "photo.on.rectangle.angled",
            title: Strings.similarTitle,
            subtitle: Strings.similarSubtitle,
            tintColor: FilterCard.CardColor.similar
        )
        similarCard.addTarget(self, action: #selector(similarCardTapped), for: .touchUpInside)

        // Largest First Card
        largestCard.configure(
            icon: "doc.text.magnifyingglass",
            title: Strings.largestTitle,
            subtitle: Strings.largestSubtitle(isVideo: mediaType == .video),
            tintColor: mediaType == .image ? FilterCard.CardColor.largestPhoto : FilterCard.CardColor.largestVideo
        )
        largestCard.addTarget(self, action: #selector(largestCardTapped), for: .touchUpInside)

        // Screenshots Card (photos only)
        screenshotsCard.configure(
            icon: "camera.viewfinder",
            title: Strings.screenshotsTitle,
            subtitle: Strings.screenshotsSubtitle,
            tintColor: FilterCard.CardColor.screenshots
        )
        screenshotsCard.addTarget(self, action: #selector(screenshotsCardTapped), for: .touchUpInside)

        // Eyes Closed Card (photos only)
        eyesClosedCard.configure(
            icon: "eye.slash.fill",
            title: Strings.eyesClosedTitle,
            subtitle: Strings.eyesClosedSubtitle,
            tintColor: FilterCard.CardColor.eyesClosed
        )
        eyesClosedCard.addTarget(self, action: #selector(eyesClosedCardTapped), for: .touchUpInside)

        // Screen Recordings Card (videos only)
        screenRecordingsCard.configure(
            icon: "record.circle",
            title: Strings.screenRecTitle,
            subtitle: Strings.screenRecSubtitle,
            tintColor: FilterCard.CardColor.screenRecordings
        )
        screenRecordingsCard.addTarget(self, action: #selector(screenRecordingsCardTapped), for: .touchUpInside)

        // Slow Motion Card (videos only)
        slowMotionCard.configure(
            icon: "speedometer",
            title: Strings.slowMotionTitle,
            subtitle: Strings.slowMotionSubtitle,
            tintColor: FilterCard.CardColor.slowMotion
        )
        slowMotionCard.addTarget(self, action: #selector(slowMotionCardTapped), for: .touchUpInside)

        // Time-lapse Card (videos only)
        timeLapseCard.configure(
            icon: "clock.arrow.circlepath",
            title: Strings.timeLapseTitle,
            subtitle: Strings.timeLapseSubtitle,
            tintColor: FilterCard.CardColor.timeLapse
        )
        timeLapseCard.addTarget(self, action: #selector(timeLapseCardTapped), for: .touchUpInside)

        // All Photos/Videos Card
        allPhotosCard.configure(
            icon: mediaType == .video ? "video" : "photo.on.rectangle",
            title: Strings.allPhotosTitle(isVideo: mediaType == .video),
            subtitle: Strings.allPhotosSubtitle(isVideo: mediaType == .video),
            tintColor: mediaType == .video ? FilterCard.CardColor.allVideos : FilterCard.CardColor.allPhotos
        )
        allPhotosCard.addTarget(self, action: #selector(allPhotosCardTapped), for: .touchUpInside)
    }

    private func configureGlobalBinButton() {
        let binIds = DeleteBinStore.shared.loadAssetIds()

        binController?.configureBinButton(
            mode: .count(binIds.count),
            monthKey: monthKey,
            monthTitle: monthTitle,
            tapHandler: { [weak self] in
                self?.handleBinTap()
            }
        )

        guard !binIds.isEmpty else { return }

        binCountTask = Task {
            let count = await photoLibraryService.countBinAssets(
                withLocalIdentifiers: binIds,
                inMonthKey: monthKey
            )
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                if count != binIds.count {
                    self.binController?.configureBinButton(
                        mode: .count(count),
                        monthKey: self.monthKey,
                        monthTitle: self.monthTitle,
                        tapHandler: { [weak self] in self?.handleBinTap() }
                    )
                }
            }
        }
    }

    private func updateStats() {
        let progress = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)
//        #if DEBUG
//            debugLogProgressSnapshot(stage: "updateStats:start", progress: progress)
//        #endif

        if progress.originalTotalCount == 0 {
//            #if DEBUG
//                print(
//                    "[MonthFilterCards][Stats] totalCount missing -> fetching assets | monthKey=\(monthKey) mediaType=\(mediaTypeDebugName) reviewed=\(progress.reviewedCount) deleted=\(progress.deletedCount) kept=\(progress.keptCount) stored=\(progress.storedCount)"
//                )
//            #endif
            Task {
                let assets = await photoLibraryService.fetchPhotos(forMonthKey: monthKey, mediaType: mediaType)
                let count = assets.count
//                #if DEBUG
//                    print(
//                        "[MonthFilterCards][Stats] fetched assets count=\(count) for missing total | monthKey=\(self.monthKey) mediaType=\(self.mediaTypeDebugName)"
//                    )
//                #endif
                if count > 0 {
                    ReviewProgressStore.shared.saveProgress(
                        forMonthKey: monthKey,
                        mediaType: mediaType,
                        currentIndex: progress.currentIndex,
                        reviewedCount: progress.reviewedCount,
                        deletedCount: progress.deletedCount,
                        keptCount: progress.keptCount,
                        storedCount: progress.storedCount,
                        originalTotalCount: count
                    )
//                    #if DEBUG
//                        let updatedProgress = ReviewProgressStore.shared.getProgress(
//                            forMonthKey: self.monthKey, mediaType: self.mediaType)
//                        self.debugLogProgressSnapshot(
//                            stage: "updateStats:afterSaveMissingTotal", progress: updatedProgress)
//                    #endif
                    await MainActor.run {
                        self.updateStats()
                    }
                }
            }
        }

        let totalCount = progress.originalTotalCount > 0 ? progress.originalTotalCount : 1 // 1 is for division protection

        let rawPercentage =
            progress.originalTotalCount > 0
            ? Double(progress.reviewedCount) / Double(totalCount)
            : 0.0

        let percentage = min(1.0, max(0.0, rawPercentage))

        progressRingView.setProgress(CGFloat(percentage), animated: true)

        if percentage >= 1.0 {
            progressLabel.isHidden = true
            progressImageView.isHidden = false
        } else {
            progressLabel.isHidden = false
            progressImageView.isHidden = true
            progressLabel.text = "\(Int(percentage * 100))%"
        }

        let displayReviewed = min(progress.reviewedCount, totalCount)
        let displayDeleted = min(progress.deletedCount, displayReviewed)
        let displayKept = min(progress.keptCount, displayReviewed - displayDeleted)
        let displayStored = min(progress.storedCount, displayReviewed - displayDeleted - displayKept)
        reviewedStatView.setValue("\(displayReviewed)/\(totalCount)")
        deletedStatView.setValue(displayDeleted)
        keptStatView.setValue(displayKept)
        storedStatView.setValue(displayStored)

        //#if DEBUG
        //        if progress.originalTotalCount > 0 && progress.reviewedCount > progress.originalTotalCount {
        //            print("[MonthFilterCards][Stats][WARN] reviewedCount exceeds totalCount -> label can be >100% style (\(progress.reviewedCount)/\(totalCount)) | monthKey=\(monthKey) mediaType=\(mediaTypeDebugName)")
        //        }
        //        if progress.deletedCount + progress.keptCount + progress.storedCount > progress.reviewedCount {
        //            print("[MonthFilterCards][Stats][WARN] actionSum exceeds reviewedCount | actionSum=\(progress.deletedCount + progress.keptCount + progress.storedCount) reviewed=\(progress.reviewedCount) monthKey=\(monthKey) mediaType=\(mediaTypeDebugName)")
        //        }
        //        print("[MonthFilterCards][Stats] label values | reviewedLabel=\(progress.reviewedCount)/\(totalCount) deleted=\(progress.deletedCount) kept=\(progress.keptCount) stored=\(progress.storedCount) percentage=\(Int(percentage * 100))% monthKey=\(monthKey) mediaType=\(mediaTypeDebugName)")
        //#endif

        updateCardStatuses()
    }

//    #if DEBUG
//        private func debugLogProgressSnapshot(
//            stage: String,
//            progress: (
//                currentIndex: Int, reviewedCount: Int, deletedCount: Int, keptCount: Int, storedCount: Int,
//                originalTotalCount: Int
//            )
//        ) {
//            print(
//                "[MonthFilterCards][Stats] \(stage) | monthKey=\(monthKey) mediaType=\(mediaTypeDebugName) currentIndex=\(progress.currentIndex) reviewed=\(progress.reviewedCount) deleted=\(progress.deletedCount) kept=\(progress.keptCount) stored=\(progress.storedCount) total=\(progress.originalTotalCount)"
//            )
//        }
//    #endif

    // MARK: - Auto Reset Finished Tags
    private func checkForNewContentAndResetFinished() {
        let storedProgress = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)
        let storedTotal = storedProgress.originalTotalCount
        guard storedTotal > 0 else { return }

        Task {
            let assets = await photoLibraryService.fetchPhotos(forMonthKey: monthKey, mediaType: mediaType)
            let currentCount = assets.count
            guard currentCount != storedTotal else { return }

            // Count has changed (added or removed) — update stored total
            ReviewProgressStore.shared.saveProgress(
                forMonthKey: self.monthKey,
                mediaType: self.mediaType,
                currentIndex: storedProgress.currentIndex,
                reviewedCount: storedProgress.reviewedCount,
                deletedCount: storedProgress.deletedCount,
                keptCount: storedProgress.keptCount,
                storedCount: storedProgress.storedCount,
                originalTotalCount: currentCount
            )

            // Only reset finished badges when new content was added
            if currentCount > storedTotal {
                MonthFilterStatusStore.shared.clearAllFinishedFilters(monthKey: self.monthKey)
            }

            await MainActor.run {
                self.updateStats()
            }
        }
    }

    // MARK: - Card Status
    private func updateCardStatuses() {
        let progress = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)
        let isMainComplete = progress.originalTotalCount > 0 && progress.reviewedCount >= progress.originalTotalCount

        if isMainComplete {
            allPhotosCard.setStatus(.complete)
            largestCard.setStatus(.complete)
            if mediaType == .image {
                screenshotsCard.setStatus(.complete)
                eyesClosedCard.setStatus(.complete)
                similarCard.setStatus(.complete)
            } else {
                screenRecordingsCard.setStatus(.complete)
                slowMotionCard.setStatus(.complete)
                timeLapseCard.setStatus(.complete)
            }
            return
        }

        applyStatus(to: allPhotosCard, filter: .allContent, progressKey: monthKey)
        applyStatus(to: largestCard,   filter: .largeFiles,  progressKey: monthKey)

        if mediaType == .image {
            applyStatus(to: screenshotsCard, filter: .screenshots)
            applyStatus(to: eyesClosedCard,  filter: .eyesClosed)
            applyStatus(to: similarCard,     filter: .similar)
        } else {
            applyStatus(to: screenRecordingsCard, filter: .screenRecordings)
            applyStatus(to: slowMotionCard,       filter: .slowMotion)
            applyStatus(to: timeLapseCard,        filter: .timeLapse)
        }
    }

    private func applyStatus(to card: FilterCard, filter: MonthFilterStatusStore.FilterType, progressKey: String? = nil) {
        let key = progressKey ?? "\(monthKey)_\(filter.rawValue)"
        let progress = ReviewProgressStore.shared.getProgress(
            forMonthKey: key, mediaType: mediaType)
        if MonthFilterStatusStore.shared.isFilterFinished(monthKey: monthKey, filter: filter) {
            card.setStatus(.complete)
        } else if progress.originalTotalCount == 0 || progress.reviewedCount == 0 {
            card.setStatus(.notStarted)
        } else if progress.reviewedCount >= progress.originalTotalCount {
            card.setStatus(.complete)
        } else {
            let percent = Int(
                (Double(progress.reviewedCount) / Double(progress.originalTotalCount)) * 100)
            card.setStatus(.inProgress(percent: percent))
        }
    }

    private func isFilterComplete(_ filter: MonthFilterStatusStore.FilterType) -> Bool {
        let progress = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)
        let isMainComplete = progress.originalTotalCount > 0 && progress.reviewedCount >= progress.originalTotalCount
        if isMainComplete { return true }

        // Check individual filter status
        return MonthFilterStatusStore.shared.isFilterFinished(monthKey: monthKey, filter: filter)
    }

    // MARK: - Actions
    @objc private func handleBinTap() {
        let binVC = DeleteBinViewController()
        binVC.filterMonthKey = monthKey
        binVC.filterMonthTitle = monthTitle
        navigationController?.pushViewController(binVC, animated: true)
    }

    @objc private func similarCardTapped() {
        guard !isFilterComplete(.similar) else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let similarVC = SimilarPhotosViewController(monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType)
        navigationController?.pushViewController(similarVC, animated: true)
    }

    @objc private func largestCardTapped() {
        guard !isFilterComplete(.largeFiles) else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let loadingVC = ProcessingLoadingViewController(
            monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType, config: .largeFiles())
        navigationController?.pushViewController(loadingVC, animated: true)
    }

    @objc private func screenshotsCardTapped() {
        guard !isFilterComplete(.screenshots) else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let screenshotsVC = MonthReviewViewController(
            monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType, filterContext: .screenshots)
        navigationController?.pushViewController(screenshotsVC, animated: true)
    }

    @objc private func eyesClosedCardTapped() {
        guard !isFilterComplete(.eyesClosed) else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let loadingVC = ProcessingLoadingViewController(
            monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType, config: .eyesClosed())
        navigationController?.pushViewController(loadingVC, animated: true)
    }

    @objc private func screenRecordingsCardTapped() {
        guard !isFilterComplete(.screenRecordings) else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let recordingsVC = MonthReviewViewController(
            monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType, filterContext: .screenRecordings)
        navigationController?.pushViewController(recordingsVC, animated: true)
    }

    @objc private func slowMotionCardTapped() {
        guard !isFilterComplete(.slowMotion) else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let slowMotionVC = MonthReviewViewController(
            monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType, filterContext: .slowMotion)
        navigationController?.pushViewController(slowMotionVC, animated: true)
    }

    @objc private func timeLapseCardTapped() {
        guard !isFilterComplete(.timeLapse) else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let timeLapseVC = MonthReviewViewController(
            monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType, filterContext: .timeLapse)
        navigationController?.pushViewController(timeLapseVC, animated: true)
    }

    @objc private func allPhotosCardTapped() {
        guard !isFilterComplete(.allContent) else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let reviewVC = MonthReviewViewController(
            monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType, filterContext: .none)
        navigationController?.pushViewController(reviewVC, animated: true)
    }
}

@available(iOS 17.0, *)
#Preview {
    UINavigationController(
        rootViewController: MonthFilterCardsViewController(monthTitle: "January 2024", monthKey: "2024-01"))
}
