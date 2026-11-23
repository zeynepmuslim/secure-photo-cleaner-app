//
//  MonthFilterCardsViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 24.01.2026.
//

import Photos
import UIKit

private enum Strings {
    static let yearDetails = NSLocalizedString("filterCards.yearDetails", comment: "Year details bar button title")
    static let continueReview = NSLocalizedString("filterCards.continue", comment: "Continue button")
    static let allCaughtUp = NSLocalizedString("filterCards.allCaughtUp", comment: "Continue button once the session is complete")
}

final class MonthFilterCardsViewController: UIViewController {
    private typealias FilterType = MonthFilterStatusStore.FilterType

    private enum Layout {
        static let topPadding: CGFloat = 16
        /// Between the cards, the rows and the bottom row
        static let cardSpacing: CGFloat = 10
        /// The same gaps when the column is short (iPhone SE)
        static let compactCardSpacing: CGFloat = 8
        /// Below this tile height (at the regular gaps) the column counts as short
        static let comfortableTileHeight: CGFloat = 140
        /// Under this tile height at the regular sizes, the overview card goes compact (iPhone SE)
        static let regularOverviewMinimumTileHeight: CGFloat = 110
        /// The All Photos row's height as a share of a tile row's
        static let allPhotosRowShare: CGFloat = 0.6
    }

    /// The one-column overview card (phones, the Duo's cover display, Split View, embedded):
    /// the month's split capsule, the number left and the percent reviewed over the counts.
    private let summaryCardView = ProgressSummaryCardView()

    /// The two tile rows, then All Photos (All Photos first on the upright inner display).
    private let cardsContainerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.cardSpacing
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let topRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Layout.cardSpacing
        stack.distribution = .fillEqually
        return stack
    }()

    private let middleRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Layout.cardSpacing
        stack.distribution = .fillEqually
        return stack
    }()

    /// The tile rows share the height equally and All Photos takes a share of one; rebuilt with
    /// the content, since they tie views that move between stacks.
    private var cardHeightConstraints: [NSLayoutConstraint] = []
    private var appliedAllPhotosRowShare: CGFloat?

    // One column: the overview card, the cards and the bottom row. On the iPhone Duo inner
    // display it splits at the fold like Home: the overview on one side, the cards on the other.
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.cardSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let overviewStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.cardSpacing
        return stack
    }()

    /// Held sideways: All Photos and the four filters, one per row.
    private let filtersStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.cardSpacing
        stack.distribution = .fillEqually
        return stack
    }()

    /// The inner display's progress card: the big split capsule, the number left and the counts.
    private let progressOverviewView: ProgressOverviewView = {
        let view = ProgressOverviewView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow - 1, for: .vertical)
        return view
    }()

    /// The resume pill: "Continue · 8 left".
    private let continueButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.setContentHuggingPriority(.required, for: .vertical)
        return button
    }()
    /// The bottom row: Continue, then the global bin's slot.
    private let bottomRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.spacing = Layout.cardSpacing
        return stack
    }()

    /// Held sideways: the filter cards with the full-width bin slot under them, so the bin
    /// lines up with Continue in the other column.
    private let filtersColumnStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.cardSpacing
        return stack
    }()

    /// Holds the place of the global bin button, which `setBinButtonPlacement(.slot)` moves here.
    private let binSlotView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }()
    private var lastSentBinSlot: CGRect?
    /// A fixed width beside Continue; sideways (inactive) the slot spans the filters column.
    private var binSlotWidthConstraint: NSLayoutConstraint?
    /// The count the bin was last configured with; the bottom row's slot hugs it.
    private var binSlotCount = 0

    private enum EmbeddedHeader {
        static let titleFontSize: CGFloat = 22
        static let spacing: CGFloat = 8
        static let infoIconPointSize: CGFloat = 17
    }

    /// Embedded in MonthsList's detail pane the nav bar is the list's, so the hub names its
    /// month (and, for a year, offers the details sheet) in a header row of its own.
    private let embeddedHeaderStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = EmbeddedHeader.spacing
        return stack
    }()

    private let embeddedTitleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: EmbeddedHeader.titleFontSize, weight: .bold)
        label.textColor = .textPrimary
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var embeddedInfoButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: EmbeddedHeader.infoIconPointSize, weight: .medium)
        button.setImage(UIImage(systemName: "info.circle", withConfiguration: config), for: .normal)
        button.tintColor = .textPrimary
        button.accessibilityLabel = Strings.yearDetails
        button.addTarget(self, action: #selector(infoButtonTapped), for: .touchUpInside)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()

    private var continueButtonTitle: String?
    private var continueButtonSymbol: String?

    private var overviewEdgeToFoldConstraint: NSLayoutConstraint?
    /// Axis the content is split along at the fold; nil means the single column.
    private var foldSplitAxis: NSLayoutConstraint.Axis?
    private var hasBuiltContent = false

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
    /// Gaps between the cards: `Layout.cardSpacing`, or the compact value in a short column
    private var appliedCardSpacing = Layout.cardSpacing
    /// The cards one per line instead of tiles: sideways, and in the short embedded pane
    private var usesRowCards = false
    private var duoEdges: [DuoEdgeConstraints] = []
    private var binCountTask: Task<Void, Never>?
    private var preloadedYearAssets: [PHAsset]?
    private var yearSection: YearSection?
    /// Shown as MonthsList's detail pane on the iPhone Duo inner display: one column with a
    /// header and a bottom row (Continue + the global bin's slot), never split at the fold.
    let isEmbedded: Bool
    /// Set by the months list before it swaps this embedded hub for another month's: the new
    /// hub's bin slot is in the same place, so disappearing leaves the bin where it is
    var keepsBinPlacementOnDisappear = false

    init(
        monthTitle: String, monthKey: String, mediaType: PHAssetMediaType = .image, yearSection: YearSection? = nil,
        isEmbedded: Bool = false
    ) {
        self.monthTitle = monthTitle
        self.monthKey = monthKey
        self.mediaType = mediaType
        self.yearSection = yearSection
        self.isEmbedded = isEmbedded
        super.init(nibName: nil, bundle: nil)
    }

    /// The month or year key this hub shows.
    var sessionKey: String { monthKey }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        // The selected Photos/Videos tab already names the media type; keep the title short
        title = monthTitle
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        setupUI()
        setupConstraint()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
                (self: MonthFilterCardsViewController, _: UITraitCollection) in
                self.applyContinueButtonStyle()
            }
        }

        if monthKey.hasPrefix("year-") {
            if isEmbedded {
                embeddedInfoButton.isHidden = false
            } else {
                setupInfoButton()
            }
            preloadYearAssets()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateStats()
        configureGlobalBinButton()
        checkForNewContentAndResetFinished()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyContinueButtonStyle()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Every push and pop resets the bin to .standard; send the slot again now we're on top
        lastSentBinSlot = nil
        updateBinSlot()
        if isEmbedded {
            // In the list's detail pane the hub can appear before the pane's layout (fold gap,
            // rail edges) settles, and before a tab switch resets the bin (mode, month, handler,
            // placement). Configure the bin and send the slot again once both have happened.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.view.window != nil else { return }
                self.view.layoutIfNeeded()
                self.configureGlobalBinButton()
                self.lastSentBinSlot = nil
                self.updateBinSlot()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Embedded and replaced by another month's hub, the bin stays in the slot the new hub
        // takes over, so it doesn't jump to its standard place and back
        if lastSentBinSlot != nil {
            lastSentBinSlot = nil
            if !keepsBinPlacementOnDisappear {
                binController?.setBinButtonPlacement(.standard)
            }
        }
        if isMovingFromParent {
            binCountTask?.cancel()
        }
    }

    private func setupUI() {
        configureCards()
        continueButton.addTarget(self, action: #selector(allPhotosCardTapped), for: .touchUpInside)

        embeddedTitleLabel.text = monthTitle
        embeddedInfoButton.isHidden = true
        embeddedHeaderStack.addArrangedSubview(embeddedTitleLabel)
        embeddedHeaderStack.addArrangedSubview(embeddedInfoButton)

        view.addSubview(contentStack)
    }

    /// The four filter cards in reading order (two rows of two in the grid).
    private var filterCards: [FilterCard] {
        FilterType.hubOrder(for: mediaType).filter { $0 != .allContent }.map { card(for: $0) }
    }

    private func card(for filter: FilterType) -> FilterCard {
        switch filter {
        case .allContent: return allPhotosCard
        case .similar: return similarCard
        case .largeFiles: return largestCard
        case .screenshots: return screenshotsCard
        case .eyesClosed: return eyesClosedCard
        case .screenRecordings: return screenRecordingsCard
        case .slowMotion: return slowMotionCard
        case .timeLapse: return timeLapseCard
        }
    }

    /// Splits the screen at the fold when one crosses the view (inactive included, so the
    /// groups don't jump when the device folds), the same way Home does. A vertical fold puts
    /// the overview and the filters side by side; a horizontal one stacks them.
    private func updateFoldSplit() {
        // The detail pane sits on one side of the fold already: one column
        if isEmbedded {
            if !hasBuiltContent { rebuildContent(splitAlong: nil) }
            updateEmbeddedDensity()
            return
        }
        var fold = FoldRegion.splittingFold(in: view)
        // A horizontal fold only splits the inner display (regular width); compact keeps one column
        if let candidate = fold, candidate.width >= candidate.height,
           traitCollection.horizontalSizeClass != .regular {
            fold = nil
        }
        let axis: NSLayoutConstraint.Axis? = fold.map { $0.height > $0.width ? .horizontal : .vertical }
        if !hasBuiltContent || axis != foldSplitAxis {
            rebuildContent(splitAlong: axis)
        }

        guard let fold = fold, let axis = axis else { return }
        let foldStart = axis == .horizontal ? fold.minX : fold.minY
        let foldLength = axis == .horizontal ? fold.width : fold.height
        let foldCenter = foldStart + foldLength / 2
        // Fully open, the groups keep the regular card spacing, centered on the fold line.
        // Folded, they clear the whole region.
        let isFolded = FoldRegion.activeFold(in: view) != nil
        let spacing = isFolded ? max(Layout.cardSpacing, foldLength) : Layout.cardSpacing
        let overviewEdge = foldCenter - spacing / 2
        if overviewEdgeToFoldConstraint?.constant != overviewEdge {
            overviewEdgeToFoldConstraint?.constant = overviewEdge
        }
        // Only the gap at the fold changes; the base's own spacing stays
        if contentStack.customSpacing(after: overviewStack) != spacing {
            contentStack.setCustomSpacing(spacing, after: overviewStack)
        }
    }

    /// Embedded above the fold (the upright inner display) the pane is wider than tall and too
    /// short for the overview card and tiles. The selected row on the base shows its progress,
    /// so the cards take that room, one per line; the header still names the month.
    private func updateEmbeddedDensity() {
        guard view.bounds.height > 0 else { return }
        let isShortPane = view.bounds.width > view.bounds.height
        if summaryCardView.isHidden != isShortPane {
            summaryCardView.isHidden = isShortPane
        }
        if usesRowCards != isShortPane {
            usesRowCards = isShortPane
            applyCardStyles()
        }
    }

    /// The screen picks each card's style: tiles in the 2×2 grid over the All Photos row, and
    /// every card as a row where they're one per line or the pane is short.
    private func applyCardStyles() {
        filterCards.forEach { $0.setStyle(usesRowCards ? .row : .tile) }
        allPhotosCard.setStyle(.row)
        // Rows share the height equally; under tiles All Photos takes a share of a tile row
        updateCardHeightConstraints(allPhotosRowShare: usesRowCards ? 1 : Layout.allPhotosRowShare)
    }

    private func updateCardHeightConstraints(allPhotosRowShare share: CGFloat) {
        let inGrid = topRowStack.superview === cardsContainerStack && allPhotosCard.superview === cardsContainerStack
        guard inGrid else {
            NSLayoutConstraint.deactivate(cardHeightConstraints)
            cardHeightConstraints = []
            appliedAllPhotosRowShare = nil
            return
        }
        guard appliedAllPhotosRowShare != share else { return }
        appliedAllPhotosRowShare = share
        NSLayoutConstraint.deactivate(cardHeightConstraints)
        cardHeightConstraints = [
            middleRowStack.heightAnchor.constraint(equalTo: topRowStack.heightAnchor),
            allPhotosCard.heightAnchor.constraint(equalTo: topRowStack.heightAnchor, multiplier: share)
        ]
        NSLayoutConstraint.activate(cardHeightConstraints)
    }

    /// A short column (iPhone SE) tightens its gaps. Decided after layout from the column's own
    /// height: how tall a tile row would be at the regular gaps.
    private func updateCardSpacing() {
        var spacing = Layout.cardSpacing
        if foldSplitAxis == nil, !isEmbedded {
            let height = contentStack.bounds.height
            // The overview card's regular height, not its current one, so going compact
            // doesn't change the answer
            let summaryHeight = ProgressSummaryCardView.regularHeight
            guard height > 0 else { return }
            // Overview, two tile rows, All Photos and the bottom row: four gaps
            let cardsHeight = height - summaryHeight - 4 * Layout.cardSpacing - GeneralConstants.ButtonSize.large
            let tileHeight = cardsHeight / (2 + Layout.allPhotosRowShare)
            if tileHeight < Layout.comfortableTileHeight {
                spacing = Layout.compactCardSpacing
            }
            // The cards get the room the overview gives up
            let isCompact = tileHeight < Layout.regularOverviewMinimumTileHeight
            if summaryCardView.isCompact != isCompact {
                summaryCardView.isCompact = isCompact
            }
        }
        guard spacing != appliedCardSpacing else { return }
        appliedCardSpacing = spacing
        [contentStack, cardsContainerStack, topRowStack, middleRowStack, bottomRowStack].forEach {
            $0.spacing = spacing
        }
    }

    private func rebuildContent(splitAlong axis: NSLayoutConstraint.Axis?) {
        hasBuiltContent = true
        foldSplitAxis = axis
        overviewEdgeToFoldConstraint?.isActive = false
        overviewEdgeToFoldConstraint = nil
        NSLayoutConstraint.deactivate(cardHeightConstraints)
        cardHeightConstraints = []
        appliedAllPhotosRowShare = nil
        [contentStack, overviewStack, filtersStack, filtersColumnStack, cardsContainerStack, topRowStack,
         middleRowStack, bottomRowStack]
            .flatMap { $0.arrangedSubviews }
            .forEach { $0.removeFromSuperview() }

        // Sideways the slot spans the filters column instead
        binSlotWidthConstraint?.isActive = axis != .horizontal
        updateBinSlotWidth()

        let cards = filterCards
        let fillGridRows = { [topRowStack, middleRowStack] in
            topRowStack.addArrangedSubview(cards[0])
            topRowStack.addArrangedSubview(cards[1])
            middleRowStack.addArrangedSubview(cards[2])
            middleRowStack.addArrangedSubview(cards[3])
        }
        contentStack.spacing = appliedCardSpacing

        guard let axis = axis else {
            // One column filling the height: the overview, the tile rows, All Photos, and
            // Continue with the bin's slot along the bottom, so the bin covers no card
            fillGridRows()
            contentStack.axis = .vertical
            cardsContainerStack.addArrangedSubview(topRowStack)
            cardsContainerStack.addArrangedSubview(middleRowStack)
            cardsContainerStack.addArrangedSubview(allPhotosCard)
            bottomRowStack.addArrangedSubview(continueButton)
            bottomRowStack.addArrangedSubview(binSlotView)
            if isEmbedded {
                // The list's detail pane names its month in a header of its own
                contentStack.addArrangedSubview(embeddedHeaderStack)
            }
            contentStack.addArrangedSubview(summaryCardView)
            contentStack.addArrangedSubview(cardsContainerStack)
            contentStack.addArrangedSubview(bottomRowStack)
            usesRowCards = isEmbedded && summaryCardView.isHidden
            applyCardStyles()
            return
        }

        contentStack.axis = axis
        contentStack.addArrangedSubview(overviewStack)
        if axis == .horizontal {
            // Held sideways: the progress card fills the column, Continue below it.
            // Side by side each half is too narrow for two tiles: one card per row,
            // All Photos first, and the bin's slot as wide as Continue under them
            overviewStack.addArrangedSubview(progressOverviewView)
            overviewStack.addArrangedSubview(continueButton)
            ([allPhotosCard] + cards).forEach { filtersStack.addArrangedSubview($0) }
            filtersColumnStack.addArrangedSubview(filtersStack)
            filtersColumnStack.addArrangedSubview(binSlotView)
            contentStack.addArrangedSubview(filtersColumnStack)
        } else {
            // Upright: the progress card above the fold, All Photos over the filter tiles on
            // the base, and Continue with the global bin's slot along the bottom
            overviewStack.addArrangedSubview(progressOverviewView)
            fillGridRows()
            cardsContainerStack.addArrangedSubview(allPhotosCard)
            cardsContainerStack.addArrangedSubview(topRowStack)
            cardsContainerStack.addArrangedSubview(middleRowStack)
            bottomRowStack.addArrangedSubview(continueButton)
            bottomRowStack.addArrangedSubview(binSlotView)
            contentStack.addArrangedSubview(cardsContainerStack)
            contentStack.addArrangedSubview(bottomRowStack)
        }
        usesRowCards = axis == .horizontal
        applyCardStyles()

        let edgeToFold = axis == .horizontal
            ? overviewStack.trailingAnchor.constraint(equalTo: view.leadingAnchor)
            : overviewStack.bottomAnchor.constraint(equalTo: view.topAnchor)
        edgeToFold.isActive = true
        overviewEdgeToFoldConstraint = edgeToFold
    }

    /// On the vertical rail the card in the device's bottom corner follows its curve, as on Home.
    private func updateCardCorners() {
        let isVerticalRail = DuoLayout.isVerticalRail(tabBarController)
        // The cards' frames are only final once the stacks are laid out
        contentStack.layoutIfNeeded()
        (filterCards + [allPhotosCard]).forEach { $0.updateCardCorners(followingDeviceCorner: isVerticalRail) }
    }

    private func setupConstraint() {
        let safeArea = view.safeAreaLayoutGuide

        // Side and bottom edges follow Home's vertical-rail padding on iPhone Duo; the bottom
        // row (Continue and the bin's slot) sits on Home's baseline
        let contentEdges = DuoEdgeConstraints(
            item: contentStack, in: view,
            standardLeading: GeneralConstants.EdgePadding.content,
            standardTrailing: GeneralConstants.EdgePadding.content,
            standardBottom: GeneralConstants.Spacer.buttonBottom)
        duoEdges = [contentEdges]
        NSLayoutConstraint.activate(contentEdges.initialConstraints)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: Layout.topPadding),
            continueButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),
            binSlotView.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large)
        ])
        binSlotWidthConstraint = binSlotView.widthAnchor.constraint(
            equalToConstant: FloatingBinButton.slotWidth(forCount: binSlotCount))
        updateFoldSplit()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateFoldSplit()
        let railEdge = DuoLayout.railEdge(tabBarController, in: view)
        duoEdges.forEach { $0.update(railEdge: railEdge) }
        updateCardSpacing()
        updateCardCorners()
        updateBinSlot()
    }

    /// The global bin sits in a slot: in the bottom row beside Continue, or sideways full width
    /// under the filters, level with Continue. The slot is sent again only when it moves
    /// (folding, the rail, a size change).
    private func updateBinSlot() {
        guard binSlotView.window != nil else {
            if lastSentBinSlot != nil {
                lastSentBinSlot = nil
                binController?.setBinButtonPlacement(.standard)
            }
            return
        }
        // Embedded, the list that holds this hub is the one on top
        // (pushed, `parent` is the navigation controller itself)
        guard navigationController?.topViewController === (isEmbedded ? parent : self) else { return }
        let slot = binSlotView.convert(binSlotView.bounds, to: nil)
        guard slot.width > 0, slot.height > 0, slot != lastSentBinSlot else { return }
        lastSentBinSlot = slot
        // Sideways the slot spans the filters column, so the button has room for its title
        binController?.setBinButtonPlacement(.slot(slot, showsTitle: foldSplitAxis == .horizontal))
    }
    
    /// Icons, titles and tints come from the shared filter model (FilterType+Route).
    private func configureCards() {
        for filter in FilterType.hubOrder(for: mediaType) {
            let card = card(for: filter)
            card.configure(
                icon: filter.cardIcon(mediaType: mediaType),
                title: filter.cardTitle(mediaType: mediaType),
                tintColor: filter.cardTint(mediaType: mediaType),
                style: filter == .allContent ? .row : .tile)
            card.addTarget(self, action: #selector(filterCardTapped(_:)), for: .touchUpInside)
        }
    }

    /// In the bottom row the slot is as wide as the bin's icon and count ("99+" at most), and
    /// Continue takes the rest. Sideways the slot spans the filters column instead.
    private func updateBinSlotWidth() {
        let width = FloatingBinButton.slotWidth(forCount: binSlotCount)
        guard let constraint = binSlotWidthConstraint, constraint.constant != width else { return }
        constraint.constant = width
        view.setNeedsLayout()
    }

    private func configureGlobalBinButton() {
        binCountTask?.cancel()
        let binIds = DeleteBinStore.shared.loadAssetIds()
        binSlotCount = binIds.count
        updateBinSlotWidth()

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
                    self.binSlotCount = count
                    self.updateBinSlotWidth()
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
        // Before the early return below, so a year key still waiting for its preload shows "–"
        updateProgressOverview(progress)
        updateCardStatuses()

        if progress.originalTotalCount == 0 {
            // Year keys can't be parsed as dates, skip the fetch fallback and wait for preloadYearAssets() to complete
            guard !monthKey.hasPrefix("year-") else {
                #if DEBUG
                print("[MonthFilterCards] year key detected, skipping fetchPhotos fallback for \(monthKey)")
                #endif
                return
            }
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
    }

    /// Feeds the overview cards and the Continue pill: reviewed never passes the total, and
    /// delete + keep + store never pass reviewed. A total of 0 (a year before its preload) shows "–".
    private func updateProgressOverview(
        _ progress: (
            currentIndex: Int, reviewedCount: Int, deletedCount: Int, keptCount: Int, storedCount: Int,
            originalTotalCount: Int
        )
    ) {
        let total = max(0, progress.originalTotalCount)
        let reviewed = min(progress.reviewedCount, total)
        let deleted = min(progress.deletedCount, reviewed)
        let kept = min(progress.keptCount, reviewed - deleted)
        let stored = min(progress.storedCount, reviewed - deleted - kept)
        let state = ProgressOverviewState(
            reviewed: reviewed, total: total, deleted: deleted, kept: kept, stored: stored,
            isVideo: mediaType == .video)
        summaryCardView.update(with: state)
        progressOverviewView.update(with: state)
        updateContinueButton(for: state)
    }

    private func updateContinueButton(for state: ProgressOverviewState) {
        let title: String
        // The overview card already shows what's left, so the pill only says what it does
        if state.isComplete {
            title = Strings.allCaughtUp
        } else {
            title = Strings.continueReview
        }
        continueButton.isEnabled = !state.isComplete
        let symbol = state.isComplete ? "checkmark" : "play.fill"
        guard title != continueButtonTitle || symbol != continueButtonSymbol else { return }
        continueButtonTitle = title
        continueButtonSymbol = symbol
        applyContinueButtonStyle()
    }

    /// A .label pill with .systemBackground text (black on white in dark mode). The colors are
    /// resolved for the current appearance: the glass doesn't keep a dynamic title color legible.
    private func applyContinueButtonStyle() {
        guard let title = continueButtonTitle, let symbol = continueButtonSymbol else { return }
        continueButton.configure(
            title: title,
            systemImage: symbol,
            style: .prominent,
            backgroundColor: UIColor.label.resolvedColor(with: traitCollection),
            foregroundColor: UIColor.systemBackground.resolvedColor(with: traitCollection),
            fontSize: 16,
            fontWeight: .bold,
            iconSize: 14,
            iconWeight: .bold)
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

        guard !monthKey.hasPrefix("year-") else {
            #if DEBUG
            print("[MonthFilterCards] skipping checkForNewContent for year key \(monthKey)")
            #endif
            return
        }
        let storedProgress = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)
        let storedTotal = storedProgress.originalTotalCount
        guard storedTotal > 0 else { return }

        Task {
            let assets = await photoLibraryService.fetchPhotos(forMonthKey: monthKey, mediaType: mediaType)
            let currentCount = assets.count
            guard currentCount != storedTotal else { return }

            if currentCount > storedTotal {
                // Content added. update total and reopen finished filters for review.
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
                await MainActor.run {
                    MonthFilterStatusStore.shared.clearAllFinishedFilters(monthKey: self.monthKey)
                    self.updateStats()
                }
            } else if currentCount == 0 && storedProgress.reviewedCount >= storedTotal {
                // Library become zero after complete review
                await MainActor.run {
                    for filter in MonthFilterStatusStore.filters(for: self.mediaType) {
                        MonthFilterStatusStore.shared.markFilterFinished(monthKey: self.monthKey, filter: filter)
                    }
                    self.updateStats()
                }
            } else {
                // Library smaller but not empty
                let newTotal = currentCount
                let newReviewed = min(storedProgress.reviewedCount, newTotal)
                let newDeleted = min(storedProgress.deletedCount, newReviewed)
                let newKept = min(storedProgress.keptCount, max(0, newReviewed - newDeleted))
                let newStored = min(storedProgress.storedCount, max(0, newReviewed - newDeleted - newKept))
                let newCurrentIndex = min(storedProgress.currentIndex, newTotal)
                ReviewProgressStore.shared.saveProgress(
                    forMonthKey: self.monthKey,
                    mediaType: self.mediaType,
                    currentIndex: newCurrentIndex,
                    reviewedCount: newReviewed,
                    deletedCount: newDeleted,
                    keptCount: newKept,
                    storedCount: newStored,
                    originalTotalCount: newTotal
                )
                await MainActor.run {
                    self.updateStats()
                }
            }
        }
    }

    // MARK: - Card Status

    /// The status rules live in FilterType+Route, shared with the end states' "Keep going" list.
    private func updateCardStatuses() {
        for filter in FilterType.hubOrder(for: mediaType) {
            filter.applyStatus(to: card(for: filter), monthKey: monthKey, mediaType: mediaType)
        }
    }

    // MARK: - Year Info Button

    private func setupInfoButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        let image = UIImage(systemName: "info.circle", withConfiguration: config)
        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(infoButtonTapped))
        button.title = Strings.yearDetails
        button.tintColor = .textPrimary
        navigationItem.rightBarButtonItem = button
    }

    @objc private func infoButtonTapped() {
        guard let item = buildFreshYearItem() else { return }
        let sheet = YearDetailSheet(yearItem: item)
        present(sheet, animated: true)
    }

    private func buildFreshYearItem() -> YearItem? {
        guard let section = yearSection else { return nil }
        let yearProgress = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)
        let freshMonths = preloadedYearAssets.map { monthItems(for: section, from: $0) } ?? section.months
        return YearItem(
            year: section.year,
            key: monthKey,
            months: freshMonths,
            currentTotalCount: section.totalItemCount,
            reviewedCount: yearProgress.reviewedCount,
            deletedCount: yearProgress.deletedCount,
            keptCount: yearProgress.keptCount,
            storedCount: yearProgress.storedCount,
            originalTotalCount: yearProgress.originalTotalCount,
            mediaType: mediaType
        )
    }

    /// Each month's real progress inside the year: its assets counted in the bin, kept and
    /// will-be-stored stores ("processed" is global, so a year session's swipes show per month).
    /// Main thread only, as the stores are.
    private func monthItems(for section: YearSection, from assets: [PHAsset]) -> [MonthItem] {
        let formatter = DateFormatterManager.shared
        let assetsByMonth = Dictionary(grouping: assets) { asset in
            asset.creationDate.map { formatter.monthKey(from: $0) } ?? ""
        }
        let bin = DeleteBinStore.shared
        let kept = KeptAssetsStore.shared
        let stored = WillBeStoredStore.shared

        return section.months.map { month in
            guard let monthAssets = assetsByMonth[month.key] else { return month }
            var deleted = 0, keptCount = 0, storedCount = 0
            for asset in monthAssets {
                let id = asset.localIdentifier
                if bin.hasAssetId(id) {
                    deleted += 1
                } else if kept.hasAssetId(id) {
                    keptCount += 1
                } else if stored.hasAssetId(id) {
                    storedCount += 1
                }
            }
            return MonthItem(
                title: month.title,
                key: month.key,
                currentPhotoCount: monthAssets.count,
                reviewedCount: deleted + keptCount + storedCount,
                keptCount: keptCount,
                deletedCount: deleted,
                storedCount: storedCount,
                originalTotalCount: monthAssets.count,
                mediaType: month.mediaType
            )
        }
    }

    // MARK: - Year Session Support

    private func preloadYearAssets() {
        guard let year = monthKey.components(separatedBy: "-").last else { return }
        Task { [weak self] in
            guard let self else { return }
            let buckets = await self.photoLibraryService.loadMonthBuckets(mediaType: self.mediaType)
            let yearBuckets = buckets.filter { $0.key.hasPrefix(year + "-") }
            guard !yearBuckets.isEmpty else { return }

            let assets: [PHAsset] = await withTaskGroup(of: [PHAsset].self) { group in
                for bucket in yearBuckets {
                    group.addTask { [weak self] in
                        guard let self else { return [] }
                        return await self.photoLibraryService.fetchPhotos(
                            forMonthKey: bucket.key, mediaType: self.mediaType)
                    }
                }
                var combined: [PHAsset] = []
                for await batch in group { combined.append(contentsOf: batch) }
                return combined.sorted {
                    ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
                }
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.preloadedYearAssets = assets
                #if DEBUG
                print("[MonthFilterCards] year assets preloaded: \(assets.count) assets for \(self.monthKey)")
                #endif
                self.resyncYearTotal(liveCount: assets.count)
                self.updateStats()
            }
        }
    }

    /// Year keys get the same total-count resync as months (`checkForNewContentAndResetFinished`, which
    /// skips them): a missing total is filled in, a grown year reopens its finished filters, and a
    /// shrunk year clamps its counts. Runs on main once the year's assets are preloaded.
    private func resyncYearTotal(liveCount: Int) {
        guard liveCount > 0 else { return }
        let stored = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)
        guard liveCount != stored.originalTotalCount else { return }

        if stored.originalTotalCount == 0 || liveCount > stored.originalTotalCount {
            ReviewProgressStore.shared.saveProgress(
                forMonthKey: monthKey, mediaType: mediaType,
                currentIndex: stored.currentIndex,
                reviewedCount: stored.reviewedCount,
                deletedCount: stored.deletedCount,
                keptCount: stored.keptCount,
                storedCount: stored.storedCount,
                originalTotalCount: liveCount
            )
            if stored.originalTotalCount > 0 {
                MonthFilterStatusStore.shared.clearAllFinishedFilters(monthKey: monthKey)
            }
        } else {
            let newReviewed = min(stored.reviewedCount, liveCount)
            let newDeleted = min(stored.deletedCount, newReviewed)
            let newKept = min(stored.keptCount, max(0, newReviewed - newDeleted))
            let newStored = min(stored.storedCount, max(0, newReviewed - newDeleted - newKept))
            ReviewProgressStore.shared.saveProgress(
                forMonthKey: monthKey, mediaType: mediaType,
                currentIndex: min(stored.currentIndex, liveCount),
                reviewedCount: newReviewed,
                deletedCount: newDeleted,
                keptCount: newKept,
                storedCount: newStored,
                originalTotalCount: liveCount
            )
        }
        #if DEBUG
        print("[MonthFilterCards] resynced \(monthKey) total \(stored.originalTotalCount) → \(liveCount)")
        #endif
    }

    // MARK: - Actions

    // For year sessions, preloadedYearAssets is passed directly to each filter
    // to avoid redundant per-filter fetches. For regular months it stays nil
    // and each VC fetches its own assets.

    @objc private func handleBinTap() {
        let binVC = DeleteBinViewController()
        if !monthKey.hasPrefix("year-") {
            binVC.filterMonthKey = monthKey
            binVC.filterMonthTitle = monthTitle
        }
        navigationController?.pushViewController(binVC, animated: true)
    }

    @objc private func filterCardTapped(_ sender: FilterCard) {
        guard let filter = FilterType.hubOrder(for: mediaType).first(where: { card(for: $0) === sender }) else {
            return
        }
        open(filter)
    }

    @objc private func allPhotosCardTapped() {
        open(.allContent)
    }

    /// A complete card does nothing. The route itself is shared (FilterType+Route).
    private func open(_ filter: FilterType) {
        guard !filter.isComplete(monthKey: monthKey, mediaType: mediaType) else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let destination = filter.makeViewController(
            monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType, yearAssets: preloadedYearAssets)
        navigationController?.pushViewController(destination, animated: true)
    }
}

@available(iOS 17.0, *)
#Preview {
    UINavigationController(
        rootViewController: MonthFilterCardsViewController(monthTitle: "January 2024", monthKey: "2024-01"))
}
