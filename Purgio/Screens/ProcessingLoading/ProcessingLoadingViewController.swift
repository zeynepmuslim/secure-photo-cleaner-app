//
//  ProcessingLoadingViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let cancel = CommonStrings.cancel
    static let legendFound = NSLocalizedString("processing.legendFound", comment: "Meter legend: items the filter found")
    static let gettingReadyPhotos = NSLocalizedString("processing.gettingReadyPhotos", comment: "Before the first result, photos")
    static let gettingReadyVideos = NSLocalizedString("processing.gettingReadyVideos", comment: "Before the first result, videos")
    static let openingPhoto = NSLocalizedString("processing.openingPhoto", comment: "Done, the deck is about to open (photos)")
    static let openingVideo = NSLocalizedString("processing.openingVideo", comment: "Done, the deck is about to open (videos)")

    static func legendOverThreshold(_ size: String) -> String {
        String(format: NSLocalizedString("processing.legendOverThreshold", comment: "Meter legend: items over a size, e.g. 'Over 60 MB'"), size)
    }

    static func itemCount(_ count: Int, mediaType: PHAssetMediaType) -> String {
        let key = mediaType == .video ? "processing.itemCountVideos" : "processing.itemCountPhotos"
        return String.localizedStringWithFormat(NSLocalizedString(key, comment: "Item count inside the scope line"), count)
    }

    static func scopeEyesClosed(items: String, month: String) -> String {
        String(format: NSLocalizedString("processing.scopeEyesClosed", comment: "Scope line: items, then the month or year"), items, month)
    }

    static func scopeLargest(items: String, month: String) -> String {
        String(format: NSLocalizedString("processing.scopeLargest", comment: "Scope line: items, then the month or year"), items, month)
    }

    static func timeLeftSeconds(_ seconds: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString("processing.timeLeftSeconds", comment: "Time left under a minute"), seconds)
    }

    static func timeLeftMinutes(_ minutes: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString("processing.timeLeftMinutes", comment: "Time left, minutes rounded up"), minutes)
    }

    static func timeLeftSecondsAccessibility(_ seconds: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("processing.timeLeftSecondsAccessibility", comment: "VoiceOver: time left under a minute"), seconds)
    }

    static func timeLeftMinutesAccessibility(_ minutes: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("processing.timeLeftMinutesAccessibility", comment: "VoiceOver: time left in minutes"), minutes)
    }
}

// MARK: - Config

struct ProcessingConfig {
    let filterContext: FilterContext
    let isFilterResultMode: Bool
    /// The finds row's name in the meter's legend
    let findsTitle: String
    /// The line under the filter's name: the item count ("57 photos"), then the month or year
    let scopeText: (_ items: String, _ month: String) -> String
    let processAssets: ([PHAsset]) async -> AsyncStream<ProcessingResult>

    static func largeFiles(mediaType: PHAssetMediaType) -> ProcessingConfig {
        let highlightBytes = mediaType == .video
            ? GeneralConstants.LargeFile.videoHighlightBytes
            : GeneralConstants.LargeFile.photoHighlightBytes
        return ProcessingConfig(
            filterContext: .largeFiles,
            isFilterResultMode: false,
            findsTitle: Strings.legendOverThreshold(highlightBytes.formattedBytes()),
            scopeText: { Strings.scopeLargest(items: $0, month: $1) },
            processAssets: { assets in
                await PhotoProcessor.shared.processAssetsForLargeFiles(assets)
            }
        )
    }

    static func eyesClosed() -> ProcessingConfig {
        ProcessingConfig(
            filterContext: .eyesClosed,
            isFilterResultMode: true,
            findsTitle: Strings.legendFound,
            scopeText: { Strings.scopeEyesClosed(items: $0, month: $1) },
            processAssets: { assets in
                await PhotoProcessor.shared.processAssetsForEyesClosed(assets, progressInterval: 5)
            }
        )
    }
}

/// The loading screen for the slow filters (Eyes Closed, Largest First): the filter's glyph and
/// name lead, a capsule meter shows what's found, checked and left, and Cancel sits beside the
/// bin on Home's baseline. When the filter is done it replaces itself with the deck.
final class ProcessingLoadingViewController: UIViewController {

    enum SplitLayout {
        /// One column: phones, the cover display, Split View
        case single
        /// Inner display held sideways: the filter in the leading half, the meter in the trailing
        case sideways
        /// Inner display upright: the filter on the raised half, the meter on the base
        case upright
    }

    enum Layout {
        struct LeadMetrics {
            let glyphSize: CGFloat
            let nameSize: CGFloat
        }

        static let lead = LeadMetrics(glyphSize: 58, nameSize: 34)
        static let shortLead = LeadMetrics(glyphSize: 44, nameSize: 28)
        static let sidewaysLead = LeadMetrics(glyphSize: 64, nameSize: 36)
        static let uprightLead = LeadMetrics(glyphSize: 72, nameSize: 40)

        static let glyphToName: CGFloat = 12
        static let nameToScope: CGFloat = 6
        static let scopeFontSize: CGFloat = 15
        static let leadToMeter: CGFloat = 40
        static let shortLeadToMeter: CGFloat = 24
        /// The lead text never runs wider than this, so it wraps instead of spanning a wide pane
        static let maximumLeadWidth: CGFloat = 420
        static let contentToBottomRow: CGFloat = 12
        static let shortBottomRowSpacing: CGFloat = 8
        /// At or under this height of its own, the column is short (iPhone SE, the cover display)
        static let shortColumnHeight: CGFloat = 700
        /// What the regular meter needs (its 250pt capsule, the gap and one line under it); with
        /// less room on the base (the table pose), the upright meter takes its compact size
        static let regularMeterRoom: CGFloat = 292

        static let springDuration: TimeInterval = 0.4
        static let springDamping: CGFloat = 0.75
        static let springVelocity: CGFloat = 0.8

        /// The time left shows once this many items are done, so it doesn't jump at first
        static let minimumItemsForEstimate = 3
        static let handoverDelay: TimeInterval = 0.4
        static let handoverDissolve: TimeInterval = 0.25
        static let scopeFade: TimeInterval = 0.25
        static let announcedPercents = [25, 50, 75]
    }

    // MARK: - Views

    /// Holds everything; its sides and bottom follow the safe area and the tab rail.
    let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let glyphImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .systemBlue
        imageView.contentMode = .center
        imageView.isAccessibilityElement = false
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        return label
    }()

    private let scopeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.scopeFontSize)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let leadStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    let meterView: ScanMeterView = {
        let view = ScanMeterView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let cancelButton = DynamicGlassButton()

    /// Where the global bin sits (`setBinButtonPlacement(.slot)`)
    private let binSlotView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    let bottomRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.spacing = GeneralConstants.Spacer.bottomRowGap
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Where the filter's glyph, name and scope are centered
    let leadAreaGuide = UILayoutGuide()
    /// Where the meter is centered
    let meterAreaGuide = UILayoutGuide()
    /// The room above the bottom row
    let roomGuide = UILayoutGuide()
    /// One column: the lead and the meter as one group, centered in the room
    let pairGuide = UILayoutGuide()

    // MARK: - Layout state

    var duoEdges: [DuoEdgeConstraints] = []
    var singleConstraints: [NSLayoutConstraint] = []
    var sidewaysConstraints: [NSLayoutConstraint] = []
    var uprightConstraints: [NSLayoutConstraint] = []
    /// One column: between the lead and the meter
    var leadToMeterConstraint: NSLayoutConstraint?
    /// Sideways: where the leading half ends and the trailing half starts, from the content's leading edge
    var sidewaysLeadEndConstraint: NSLayoutConstraint?
    var sidewaysMeterStartConstraint: NSLayoutConstraint?
    var sidewaysBottomRowStartConstraint: NSLayoutConstraint?
    /// Upright: where the raised half ends and the base starts, from the content's top
    var uprightLeadEndConstraint: NSLayoutConstraint?
    var uprightMeterStartConstraint: NSLayoutConstraint?
    private var bottomRowHeightConstraint: NSLayoutConstraint?
    private var binSlotWidthConstraint: NSLayoutConstraint?

    var splitLayout: SplitLayout = .single
    var hasAppliedSplitLayout = false
    var isFoldActive = false
    private var appliedLeadMetrics: Layout.LeadMetrics?
    private var isShortRow = false
    private var lastSentBinSlot: CGRect?
    private var binSlotCount = 0
    private var binCountTask: Task<Void, Never>?

    // MARK: - State

    private let photoLibraryService = PhotoLibraryService.shared

    private let monthKey: String
    private let monthTitle: String
    private let mediaType: PHAssetMediaType
    private let config: ProcessingConfig
    private var assets: [PHAsset] = []
    private var shouldFetchAssets = false
    private var didStart = false
    private var fetchTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?
    private var startTime: Date?
    /// Items the filter checks; nil until the month is fetched
    private var totalCount: Int?
    private var lastProgress: ProcessingProgress?
    /// The finished result, held until this screen is on top (the bin can be open over it)
    private var completedAssets: [ReviewAsset]?
    private var handoverWorkItem: DispatchWorkItem?
    private var announcedPercentIndex = -1
    var navigationSource: NavigationSource = .manual

    private var filterType: MonthFilterStatusStore.FilterType {
        MonthFilterStatusStore.FilterType(filterContext: config.filterContext)
    }

    private var binController: FloatingBinButtonController? {
        tabBarController as? FloatingBinButtonController
    }

    // MARK: - Init

    init(monthTitle: String, monthKey: String, assets: [PHAsset], mediaType: PHAssetMediaType, config: ProcessingConfig)
    {
        self.monthTitle = monthTitle
        self.monthKey = monthKey
        self.assets = assets
        self.mediaType = mediaType
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    init(monthTitle: String, monthKey: String, mediaType: PHAssetMediaType, config: ProcessingConfig) {
        self.monthTitle = monthTitle
        self.monthKey = monthKey
        self.mediaType = mediaType
        self.config = config
        self.shouldFetchAssets = true
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        title = monthTitle
        navigationItem.largeTitleDisplayMode = .never

        setupUI()
        setupConstraint()

        if !shouldFetchAssets {
            // A year session hands its assets over: the total is known from the start
            assets = unprocessed(assets)
            setTotalCount(assets.count, animated: false)
        }
        refreshMeter(animated: false)

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleBinCountChange), name: .deleteBinCountDidChange, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureGlobalBinButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let railEdge = DuoLayout.railEdge(tabBarController, in: view)
        duoEdges.forEach { $0.update(railEdge: railEdge) }
        updateFoldSplit()
        updateBinSlot()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Every push and pop resets the bin to .standard; send the slot again now we're on top
        lastSentBinSlot = nil
        updateBinSlot()

        if completedAssets != nil {
            // The filter finished while the bin was open over this screen
            scheduleHandover()
        }
        guard !didStart else { return }
        didStart = true
        if shouldFetchAssets {
            fetchAssetsAndProcess()
        } else {
            startProcessing()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        handoverWorkItem?.cancel()
        handoverWorkItem = nil
        if lastSentBinSlot != nil {
            lastSentBinSlot = nil
            binController?.setBinButtonPlacement(.standard)
        }
        if isMovingFromParent {
            fetchTask?.cancel()
            processingTask?.cancel()
            binCountTask?.cancel()
            assets.removeAll()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(contentView)

        nameLabel.text = filterType.cardTitle(mediaType: mediaType)
        // Invisible until the item count is known; a space keeps its line
        scopeLabel.text = " "
        scopeLabel.alpha = 0

        leadStack.addArrangedSubview(glyphImageView)
        leadStack.addArrangedSubview(nameLabel)
        leadStack.addArrangedSubview(scopeLabel)
        leadStack.setCustomSpacing(Layout.glyphToName, after: glyphImageView)
        leadStack.setCustomSpacing(Layout.nameToScope, after: nameLabel)
        applyLeadMetrics(Layout.lead)

        cancelButton.configure(
            title: Strings.cancel,
            style: .regular,
            backgroundColor: .systemGray5,
            foregroundColor: .label,
            fontSize: 17,
            fontWeight: .bold)
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)

        bottomRowStack.addArrangedSubview(cancelButton)
        bottomRowStack.addArrangedSubview(binSlotView)

        contentView.addSubview(leadStack)
        contentView.addSubview(meterView)
        contentView.addSubview(bottomRowStack)
        [leadAreaGuide, meterAreaGuide, roomGuide, pairGuide].forEach { contentView.addLayoutGuide($0) }

        // VoiceOver reads the filter, then the meter, then Cancel
        contentView.accessibilityElements = [nameLabel, scopeLabel, meterView, cancelButton]
    }

    private func setupConstraint() {
        // Sides and bottom follow the safe area and, with the vertical rail, Home's rail padding
        let edges = DuoEdgeConstraints(
            item: contentView, in: view,
            standardLeading: GeneralConstants.EdgePadding.content,
            standardTrailing: GeneralConstants.EdgePadding.content,
            standardBottom: GeneralConstants.Spacer.buttonBottom)
        duoEdges = [edges]

        let rowHeight = bottomRowStack.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large)
        bottomRowHeightConstraint = rowHeight
        let slotWidth = binSlotView.widthAnchor.constraint(
            equalToConstant: FloatingBinButton.slotWidth(forCount: binSlotCount))
        binSlotWidthConstraint = slotWidth

        // The pair's centering gives way before anything is pushed out of the room
        let leadCenterY = leadStack.centerYAnchor.constraint(equalTo: leadAreaGuide.centerYAnchor)
        leadCenterY.priority = .defaultHigh
        let meterCenterY = meterView.centerYAnchor.constraint(equalTo: meterAreaGuide.centerYAnchor)
        meterCenterY.priority = .defaultHigh
        let leadWidthCap = leadStack.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maximumLeadWidth)
        // As wide as its area up to the cap: a definite width, so the texts wrap the same way
        // whatever width an earlier layout gave them
        let leadFillWidth = leadStack.widthAnchor.constraint(equalTo: leadAreaGuide.widthAnchor)
        leadFillWidth.priority = .defaultHigh

        NSLayoutConstraint.activate(edges.initialConstraints + [
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            bottomRowStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomRowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            rowHeight,
            slotWidth,

            roomGuide.topAnchor.constraint(equalTo: contentView.topAnchor),
            roomGuide.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            roomGuide.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            roomGuide.bottomAnchor.constraint(equalTo: bottomRowStack.topAnchor, constant: -Layout.contentToBottomRow),

            leadStack.centerXAnchor.constraint(equalTo: leadAreaGuide.centerXAnchor),
            leadCenterY,
            leadStack.topAnchor.constraint(greaterThanOrEqualTo: leadAreaGuide.topAnchor),
            leadStack.bottomAnchor.constraint(lessThanOrEqualTo: leadAreaGuide.bottomAnchor),
            leadStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadAreaGuide.leadingAnchor),
            leadStack.trailingAnchor.constraint(lessThanOrEqualTo: leadAreaGuide.trailingAnchor),
            leadWidthCap,
            leadFillWidth,

            meterView.centerXAnchor.constraint(equalTo: meterAreaGuide.centerXAnchor),
            meterCenterY,
            meterView.topAnchor.constraint(greaterThanOrEqualTo: meterAreaGuide.topAnchor),
            meterView.bottomAnchor.constraint(lessThanOrEqualTo: meterAreaGuide.bottomAnchor),
            meterView.leadingAnchor.constraint(greaterThanOrEqualTo: meterAreaGuide.leadingAnchor),
            meterView.trailingAnchor.constraint(lessThanOrEqualTo: meterAreaGuide.trailingAnchor)
        ])

        makeSplitConstraints()
    }

    // MARK: - Metrics

    private func applyLeadMetrics(_ metrics: Layout.LeadMetrics) {
        guard appliedLeadMetrics?.glyphSize != metrics.glyphSize || appliedLeadMetrics?.nameSize != metrics.nameSize
        else { return }
        appliedLeadMetrics = metrics
        let symbol = UIImage.SymbolConfiguration(pointSize: metrics.glyphSize, weight: .thin)
        glyphImageView.image = UIImage(systemName: filterType.cardIcon(mediaType: mediaType), withConfiguration: symbol)
        nameLabel.font = ThemeManager.Fonts.titleFont(size: metrics.nameSize, weight: .heavy)
    }

    /// Sizes for the layout the fold picked: the short column (the view's own height, one column
    /// only) shrinks everything; the Duo's halves get their own lead sizes.
    func applyMetrics(for layout: SplitLayout, meterRoom: CGFloat?) {
        let isShort = layout == .single
            && view.bounds.height > 0 && view.bounds.height <= Layout.shortColumnHeight

        switch layout {
        case .single: applyLeadMetrics(isShort ? Layout.shortLead : Layout.lead)
        case .sideways: applyLeadMetrics(Layout.sidewaysLead)
        case .upright: applyLeadMetrics(Layout.uprightLead)
        }

        // A base too short for the regular meter (the table pose) takes the compact one
        let isMeterCompact = isShort || (meterRoom.map { $0 < Layout.regularMeterRoom } ?? false)
        if meterView.isCompact != isMeterCompact {
            meterView.isCompact = isMeterCompact
        }

        let leadToMeter = isShort ? Layout.shortLeadToMeter : Layout.leadToMeter
        if let constraint = leadToMeterConstraint, constraint.constant != leadToMeter {
            constraint.constant = leadToMeter
        }

        guard isShort != isShortRow else { return }
        isShortRow = isShort
        bottomRowHeightConstraint?.constant =
            isShort ? GeneralConstants.ButtonSize.mediumLarge : GeneralConstants.ButtonSize.large
        bottomRowStack.spacing = isShort ? Layout.shortBottomRowSpacing : GeneralConstants.Spacer.bottomRowGap
    }

    // MARK: - Bin slot

    /// The bin shows this month's count and opens this month's bin, as on the month's hub.
    private func configureGlobalBinButton() {
        binCountTask?.cancel()
        let binIds = DeleteBinStore.shared.loadAssetIds()
        applyBinCount(binIds.count)
        binController?.showBinButton()

        guard !binIds.isEmpty, !monthKey.hasPrefix("year-") else { return }
        binCountTask = Task { [weak self] in
            guard let self else { return }
            let count = await self.photoLibraryService.countBinAssets(
                withLocalIdentifiers: binIds, inMonthKey: self.monthKey)
            guard !Task.isCancelled, count != binIds.count else { return }
            await MainActor.run { self.applyBinCount(count) }
        }
    }

    private func applyBinCount(_ count: Int) {
        binSlotCount = count
        let width = FloatingBinButton.slotWidth(forCount: count)
        if let constraint = binSlotWidthConstraint, constraint.constant != width {
            constraint.constant = width
            view.setNeedsLayout()
        }
        binController?.configureBinButton(
            mode: .count(count),
            monthKey: monthKey,
            monthTitle: monthTitle,
            tapHandler: { [weak self] in self?.handleBinTap() })
    }

    /// Hands the bottom row's slot to the global bin whenever it moves.
    private func updateBinSlot() {
        guard binSlotView.window != nil, navigationController?.topViewController === self else { return }
        let slot = binSlotView.convert(binSlotView.bounds, to: nil)
        guard slot.width > 0, slot.height > 0, slot != lastSentBinSlot else { return }
        lastSentBinSlot = slot
        binController?.setBinButtonPlacement(.slot(slot, matchesHeight: isShortRow))
    }

    private func handleBinTap() {
        let binVC = DeleteBinViewController()
        if !monthKey.hasPrefix("year-") {
            binVC.filterMonthKey = monthKey
            binVC.filterMonthTitle = monthTitle
        }
        navigationController?.pushViewController(binVC, animated: true)
    }

    // MARK: - Notifications

    @objc private func handleBinCountChange() {
        guard view.window != nil, navigationController?.topViewController === self else { return }
        configureGlobalBinButton()
    }

    // MARK: - Data Loading

    /// Eyes Closed checks every photo; Largest First leaves out what's already sorted.
    private func unprocessed(_ assets: [PHAsset]) -> [PHAsset] {
        guard !config.isFilterResultMode else { return assets }
        let binnedSet = Set(DeleteBinStore.shared.loadAssetIds())
        let keptSet = Set(KeptAssetsStore.shared.loadAssetIds())
        let storedSet = Set(WillBeStoredStore.shared.loadAssetIds())
        return assets.filter { asset in
            let id = asset.localIdentifier
            return !binnedSet.contains(id) && !keptSet.contains(id) && !storedSet.contains(id)
        }
    }

    private func fetchAssetsAndProcess() {
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            let fetchedAssets = await self.photoLibraryService.fetchPhotos(
                forMonthKey: self.monthKey, mediaType: self.mediaType)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                // The stores are main-thread only
                self.assets = self.unprocessed(fetchedAssets)
                self.startProcessing()
            }
        }
    }

    private func startProcessing() {
        let validAssets = unprocessed(assets)
        setTotalCount(validAssets.count, animated: true)
        refreshMeter(animated: false)
        startTime = Date()

        processingTask?.cancel()
        processingTask = Task { [weak self] in
            guard let stream = await self?.config.processAssets(validAssets) else { return }

            for await result in stream {
                guard !Task.isCancelled else { return }
                switch result {
                case .progress(let progress):
                    await MainActor.run { self?.handleProgress(progress) }
                case .completed(let resultAssets):
                    await MainActor.run { self?.handleCompletion(resultAssets) }
                case .initialBatchReady, .cancelled:
                    break
                }
            }
        }
    }

    // MARK: - States

    /// The scope line names how many items the filter checks, once that's known.
    private func setTotalCount(_ count: Int, animated: Bool) {
        totalCount = count
        scopeLabel.text = config.scopeText(Strings.itemCount(count, mediaType: mediaType), monthTitle)
        guard scopeLabel.alpha < 1 else { return }
        if animated, view.window != nil {
            UIView.animate(withDuration: Layout.scopeFade) { self.scopeLabel.alpha = 1 }
        } else {
            scopeLabel.alpha = 1
        }
    }

    private func handleProgress(_ progress: ProcessingProgress) {
        guard completedAssets == nil else { return }
        lastProgress = progress
        totalCount = progress.total
        refreshMeter(animated: true)
        announceProgressIfNeeded(checked: progress.current, total: progress.total)
    }

    /// Starting (nothing checked yet), checking, or done, from what's been reported so far.
    private func refreshMeter(animated: Bool) {
        let gettingReady = mediaType == .video ? Strings.gettingReadyVideos : Strings.gettingReadyPhotos
        var state = ScanMeterState(
            checked: nil, found: 0, total: totalCount, findsTitle: config.findsTitle,
            footnote: gettingReady, footnoteAccessibility: gettingReady)

        if let completedAssets {
            let total = totalCount ?? 0
            // With nothing to check there's nothing to fill: the starting look, about to hand over
            state.checked = total > 0 ? total : nil
            state.found = config.isFilterResultMode ? completedAssets.count : (lastProgress?.found ?? 0)
            let opening = mediaType == .video ? Strings.openingVideo : Strings.openingPhoto
            state.footnote = opening
            state.footnoteAccessibility = opening
        } else if let progress = lastProgress, progress.current > 0 {
            state.checked = progress.current
            state.found = progress.found
            state.total = progress.total
            if let timeLeft = timeLeft(for: progress) {
                state.footnote = timeLeft.text
                state.footnoteAccessibility = timeLeft.accessibility
            }
        }
        meterView.update(with: state, animated: animated)
    }

    /// The average time per item so far, times what's left; nil until enough items are done.
    private func timeLeft(for progress: ProcessingProgress) -> (text: String, accessibility: String)? {
        guard let startTime, progress.current >= Layout.minimumItemsForEstimate else { return nil }
        let average = Date().timeIntervalSince(startTime) / Double(progress.current)
        let seconds = max(1, Int((average * Double(progress.total - progress.current)).rounded(.up)))
        if seconds < 60 {
            return (Strings.timeLeftSeconds(seconds), Strings.timeLeftSecondsAccessibility(seconds))
        }
        let minutes = Int((Double(seconds) / 60).rounded(.up))
        return (Strings.timeLeftMinutes(minutes), Strings.timeLeftMinutesAccessibility(minutes))
    }

    /// VoiceOver hears the quarters, not every batch.
    private func announceProgressIfNeeded(checked: Int, total: Int) {
        guard UIAccessibility.isVoiceOverRunning, checked < total else { return }
        let percent = checked.roundedPercent(of: total)
        guard let index = Layout.announcedPercents.lastIndex(where: { percent >= $0 }),
              index > announcedPercentIndex else { return }
        announcedPercentIndex = index
        UIAccessibility.post(
            notification: .announcement, argument: ScanMeterView.percentText(checked: checked, total: total))
    }

    private func handleCompletion(_ resultAssets: [ReviewAsset]) {
        guard completedAssets == nil else { return }
        completedAssets = resultAssets
        refreshMeter(animated: true)
        cancelButton.isEnabled = false

        guard navigationController?.topViewController === self else { return }
        HapticFeedbackManager.shared.success()
        UIAccessibility.post(notification: .announcement, argument: meterView.accessibilityLabel)
        scheduleHandover()
    }

    /// The full capsule stays up for a moment, then the deck takes this screen's place.
    private func scheduleHandover() {
        handoverWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.navigateToResults()
        }
        handoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.handoverDelay, execute: workItem)
    }

    // MARK: - Actions

    @objc private func handleCancel() {
        fetchTask?.cancel()
        processingTask?.cancel()
        navigationController?.popViewController(animated: true)
    }

    private func navigateToResults() {
        guard let filteredReviewAssets = completedAssets,
              let navigationController, navigationController.topViewController === self else { return }
        handoverWorkItem = nil

        let reviewVC = MonthReviewViewController(
            monthTitle: monthTitle,
            monthKey: monthKey,
            mediaType: mediaType,
            filterContext: config.filterContext
        )

        reviewVC.setPreComputedAssets(filteredReviewAssets)
        reviewVC.navigationSource = navigationSource

        if config.isFilterResultMode {
            reviewVC.isFilterResultMode = true
        }

        UIView.transition(
            with: navigationController.view, duration: Layout.handoverDissolve,
            options: [.transitionCrossDissolve, .allowUserInteraction]
        ) {
            self.replaceInNavigationStack(with: reviewVC, animated: false)
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

private struct ProcessingLoadingPreview: UIViewControllerRepresentable {
    let config: ProcessingConfig
    let mediaType: PHAssetMediaType

    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(
            rootViewController: ProcessingLoadingViewController(
                monthTitle: "August 2025", monthKey: "2025-08", assets: [], mediaType: mediaType, config: config))
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

@available(iOS 17.0, *)
#Preview("Eyes Closed") {
    ProcessingLoadingPreview(config: .eyesClosed(), mediaType: .image)
}

@available(iOS 17.0, *)
#Preview("Largest First, videos") {
    ProcessingLoadingPreview(config: .largeFiles(mediaType: .video), mediaType: .video)
}
#endif
