//
//  StorageAnalysisBottomSheet.swift
//  Purgio
//
//  Created by ZeynepMüslim on 1.02.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let sheetTitle = NSLocalizedString("storageSheet.title", comment: "Storage analysis sheet title")
    static let analyzing = NSLocalizedString("storageSheet.analyzing", comment: "Analyzing progress label")
    static let refresh = NSLocalizedString("storageSheet.refresh", comment: "Refresh button on the storage sheet")
    static let used = NSLocalizedString("storageAnalysis.used", comment: "Used storage label")
    static let available = NSLocalizedString("storageAnalysis.available", comment: "Available storage label")
    static let saved = NSLocalizedString("storageAnalysis.saved", comment: "Saved storage label")
    static let photos = NSLocalizedString("storageAnalysis.photos", comment: "Photos label")
    static let videos = NSLocalizedString("storageAnalysis.videos", comment: "Videos label")
    static let other = NSLocalizedString("storageAnalysis.other", comment: "Other storage label")
    static let notAnalyzedYet = NSLocalizedString("storageAnalysis.notAnalyzedYet", comment: "Not yet analyzed message")
    static let analyzeStorage = NSLocalizedString("storageAnalysis.analyzeStorage", comment: "Analyze storage button")
    static let unableToAnalyze = NSLocalizedString("storageAnalysis.unableToAnalyze", comment: "Error when analysis fails")
    static let tryAgain = NSLocalizedString("storageAnalysis.tryAgain", comment: "Try again button")
    static let placeholder = "–"

    static func progressLabel(phase: String, progress: Int) -> String {
        String(format: NSLocalizedString("storageSheet.progressLabel", comment: "Progress label, e.g. 'Photos... 45%%'"), phase.capitalized, progress)
    }
    static func lastAnalyzed(date: String) -> String {
        String(format: NSLocalizedString("storageAnalysis.lastAnalyzed", comment: "Last analyzed date"), date)
    }
    static func lastAnalyzedStale(date: String) -> String {
        String(format: NSLocalizedString("storageAnalysis.lastAnalyzedStale", comment: "Stale analysis date with refresh hint"), date)
    }
    static func photoCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("storageSheet.photoCount", comment: "Photo count under the Photos row, e.g. '4,312 photos'"), count)
    }
    static func videoCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("storageSheet.videoCount", comment: "Video count under the Videos row, e.g. '286 videos'"), count)
    }
    static func totalOf(_ total: String) -> String {
        String(format: NSLocalizedString("storageSheet.totalOf", comment: "The device total beside the used figure, e.g. '/ 494.38 GB'"), total)
    }
    static func usedAccessibility(used: String, total: String) -> String {
        String(format: NSLocalizedString("storageSheet.usedAccessibility", comment: "VoiceOver, e.g. '468.77 GB of 494.38 GB used'"), used, total)
    }
}

/// Home's storage sheet, board "Storage analysis sheet · S1 Ledger on every size": the used
/// figure, a bar, a ledger of Photos / Videos / Other / Available, a Saved card and a footer with
/// Refresh. One layout in every state (only the values change), and the sheet is as tall as it.
final class StorageAnalysisBottomSheet: UIViewController {

    // MARK: - Layout

    private enum Layout {
        static let topPadding: CGFloat = 24
        static let bottomPadding = GeneralConstants.EdgePadding.content
        static let sidePadding = GeneralConstants.EdgePadding.content
        static let columnMaxWidth: CGFloat = 560
        static let cardSidePadding = GeneralConstants.EdgePadding.medium
        static let savedGap: CGFloat = 10
        static let refreshHeight: CGFloat = 36
        static let compactWindowHeight: CGFloat = 700
        static let progressAlpha: CGFloat = 0.55
        static let valueFade: TimeInterval = 0.25
    }

    /// Everything that differs between the regular and the compact sheet.
    private struct Metrics {
        let titleSize: CGFloat
        let figureSize: CGFloat
        let barHeight: CGFloat
        let figureToBar: CGFloat
        let barToLedger: CGFloat
        let rowPadding: CGFloat
        let savedPadding: CGFloat
        let ledgerToFooter: CGFloat

        static let regular = Metrics(
            titleSize: 24, figureSize: 34, barHeight: 16, figureToBar: 12, barToLedger: 16,
            rowPadding: 11, savedPadding: 12, ledgerToFooter: 14)
        static let compact = Metrics(
            titleSize: 22, figureSize: 28, barHeight: 14, figureToBar: 10, barToLedger: 12,
            rowPadding: 8, savedPadding: 10, ledgerToFooter: 12)
    }

    // MARK: - Views

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isScrollEnabled = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.sheetTitle
        label.textColor = .label
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        return label
    }()

    /// The figure, "/ total" and "Used" as one VoiceOver element.
    private let figureGroup: UIView = {
        let view = UIView()
        view.isAccessibilityElement = true
        return view
    }()

    private let figureRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let figureLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let totalLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let usedCaption: UILabel = {
        let label = UILabel()
        label.text = Strings.used
        label.font = ThemeManager.Fonts.regularCaption
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let storageBar: SegmentedBarView = {
        let bar = SegmentedBarView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.barBackgroundColor = .storageAvailable
        bar.separatorColor = .mainBackground
        bar.isAccessibilityElement = false
        bar.accessibilityElementsHidden = true
        return bar
    }()

    private let ledgerCard: UIView = makeCard()

    private let ledgerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let photosRow = StorageLedgerRowView()
    private let videosRow = StorageLedgerRowView()
    private let otherRow = StorageLedgerRowView()
    private let availableRow = StorageLedgerRowView()
    private var ledgerRows: [StorageLedgerRowView] { [photosRow, videosRow, otherRow, availableRow] }

    private let savedCard: UIView = {
        let card = makeCard()
        card.isAccessibilityElement = true
        return card
    }()

    private let savedIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let imageView = UIImageView(image: UIImage(systemName: "leaf", withConfiguration: config))
        imageView.tintColor = .storageSavedLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        return imageView
    }()

    private let savedTitleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.saved
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let savedValueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        label.textColor = .storageSavedLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let footerRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private let refreshButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()

    // MARK: - State

    private let storageManager = StorageAnalysisManager.shared
    private let statsStore = StatsStore.shared

    private var barHeightConstraint: NSLayoutConstraint?
    private var savedTopConstraint: NSLayoutConstraint?
    private var savedBottomConstraint: NSLayoutConstraint?

    private var isCompact = false
    private var didApplyMetrics = false
    private var fittedHeight: CGFloat = 0
    private var isUpdatingLayout = false
    private var needsDetentRefresh = false
    /// The last progress (0–100) and phase from `.storageAnalysisDidUpdateProgress`.
    private var scanProgress: Int = 0
    private var scanPhase: String?
    private var refreshTitle = Strings.refresh

    #if DEBUG
        private var previewState: StorageAnalysisState?
    #endif

    // MARK: - Lifecycle

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        configureSheet()
    }

    #if DEBUG
        /// Shows a fixed state without the manager (previews).
        convenience init(previewState: StorageAnalysisState, progress: Int = 0) {
            self.init(nibName: nil, bundle: nil)
            self.previewState = previewState
            self.scanProgress = progress
        }
    #endif

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraint()
        applyMetrics(.regular)
        seedProgress()
        render(animated: false)
        setupNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The presenter's window is known here: pick the metrics before the first measurement,
        // so the detent the sheet presents at is already the right one.
        updateMetricsIfNeeded()
        configureDetents()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // A height that changed while the sheet was coming up is applied once it has settled.
        guard needsDetentRefresh else { return }
        needsDetentRefresh = false
        applyDetentChange(animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !isUpdatingLayout else { return }
        isUpdatingLayout = true
        defer { isUpdatingLayout = false }

        // The hinge update can land late: re-check on every pass, switch without animation.
        UIView.performWithoutAnimation {
            updateMetricsIfNeeded()
            updateFigureAxis()
            contentStack.layoutIfNeeded()
        }
        updateFittedHeight()
    }

    // MARK: - Setup

    private func configureSheet() {
        modalPresentationStyle = .pageSheet
        guard let sheet = sheetPresentationController else { return }
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        // The detent must be in place before the presentation lays out: set later, the sheet
        // keeps the default large detent's position (seen on iOS 18). Its height is measured
        // the first time the system asks, when the presenter's window is known.
        if #available(iOS 16.0, *) {
            sheet.detents = [
                .custom(identifier: .init("storageSheet.content")) { [weak self] context in
                    guard let self else { return nil }
                    if self.fittedHeight <= 0 { self.measureInitialHeight() }
                    return min(self.fittedHeight, context.maximumDetentValue)
                }
            ]
        } else {
            sheet.detents = [.medium()]
        }
    }

    private static func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .cardBackground
        card.layer.cornerRadius = GeneralConstants.CornerRadius.card
        card.layer.cornerCurve = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private static func makeHairline() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return line
    }

    private func setupUI() {
        view.backgroundColor = .mainBackground

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        figureRow.addArrangedSubview(figureLabel)
        figureRow.addArrangedSubview(totalLabel)
        figureGroup.addSubview(figureRow)
        figureGroup.addSubview(usedCaption)

        for (index, row) in ledgerRows.enumerated() {
            if index > 0 { ledgerStack.addArrangedSubview(Self.makeHairline()) }
            ledgerStack.addArrangedSubview(row)
        }
        ledgerCard.addSubview(ledgerStack)

        savedCard.addSubview(savedIcon)
        savedCard.addSubview(savedTitleLabel)
        savedCard.addSubview(savedValueLabel)

        footerRow.addArrangedSubview(statusLabel)
        footerRow.addArrangedSubview(refreshButton)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        contentStack.setCustomSpacing(8, after: titleLabel)
        [titleLabel, figureGroup, storageBar, ledgerCard, savedCard, footerRow]
            .forEach { contentStack.addArrangedSubview($0) }
    }

    private func setupConstraint() {
        let safeArea = view.safeAreaLayoutGuide
        let frameGuide = scrollView.frameLayoutGuide
        let contentGuide = scrollView.contentLayoutGuide

        let fillWidth = contentStack.widthAnchor.constraint(
            equalTo: frameGuide.widthAnchor, constant: -2 * Layout.sidePadding)
        fillWidth.priority = .defaultHigh

        let barHeight = storageBar.heightAnchor.constraint(equalToConstant: Metrics.regular.barHeight)
        barHeightConstraint = barHeight

        let savedTop = savedTitleLabel.topAnchor.constraint(equalTo: savedCard.topAnchor, constant: Metrics.regular.savedPadding)
        let savedBottom = savedTitleLabel.bottomAnchor.constraint(
            equalTo: savedCard.bottomAnchor, constant: -Metrics.regular.savedPadding)
        savedTopConstraint = savedTop
        savedBottomConstraint = savedBottom

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),

            contentGuide.widthAnchor.constraint(equalTo: frameGuide.widthAnchor),

            // One column, as wide as the sheet allows up to 560pt, centered
            contentStack.topAnchor.constraint(equalTo: contentGuide.topAnchor, constant: Layout.topPadding),
            contentStack.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -Layout.bottomPadding),
            contentStack.centerXAnchor.constraint(equalTo: frameGuide.centerXAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: frameGuide.leadingAnchor, constant: Layout.sidePadding),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.columnMaxWidth),
            fillWidth,

            figureRow.topAnchor.constraint(equalTo: figureGroup.topAnchor),
            figureRow.leadingAnchor.constraint(equalTo: figureGroup.leadingAnchor),
            figureRow.trailingAnchor.constraint(lessThanOrEqualTo: figureGroup.trailingAnchor),
            usedCaption.topAnchor.constraint(equalTo: figureRow.bottomAnchor, constant: 2),
            usedCaption.leadingAnchor.constraint(equalTo: figureGroup.leadingAnchor),
            usedCaption.trailingAnchor.constraint(lessThanOrEqualTo: figureGroup.trailingAnchor),
            usedCaption.bottomAnchor.constraint(equalTo: figureGroup.bottomAnchor),

            barHeight,

            ledgerStack.topAnchor.constraint(equalTo: ledgerCard.topAnchor),
            ledgerStack.bottomAnchor.constraint(equalTo: ledgerCard.bottomAnchor),
            ledgerStack.leadingAnchor.constraint(equalTo: ledgerCard.leadingAnchor, constant: Layout.cardSidePadding),
            ledgerStack.trailingAnchor.constraint(equalTo: ledgerCard.trailingAnchor, constant: -Layout.cardSidePadding),

            savedIcon.leadingAnchor.constraint(equalTo: savedCard.leadingAnchor, constant: Layout.cardSidePadding),
            savedIcon.centerYAnchor.constraint(equalTo: savedTitleLabel.centerYAnchor),
            savedTitleLabel.leadingAnchor.constraint(equalTo: savedIcon.trailingAnchor, constant: 10),
            savedTop,
            savedBottom,
            savedValueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: savedTitleLabel.trailingAnchor, constant: 12),
            savedValueLabel.trailingAnchor.constraint(equalTo: savedCard.trailingAnchor, constant: -Layout.cardSidePadding),
            savedValueLabel.centerYAnchor.constraint(equalTo: savedTitleLabel.centerYAnchor),

            refreshButton.heightAnchor.constraint(equalToConstant: Layout.refreshHeight)
        ])
    }

    private func setupNotifications() {
        let center = NotificationCenter.default
        for name in [Notification.Name.storageAnalysisDidStart, .storageAnalysisDidFetchBasicInfo,
                     .storageAnalysisDidComplete, .storageAnalysisDidFail, .storageAnalysisDidPause] {
            center.addObserver(self, selector: #selector(storageStateChanged(_:)), name: name, object: nil)
        }
        center.addObserver(
            self, selector: #selector(handleProgressUpdate(_:)), name: .storageAnalysisDidUpdateProgress, object: nil)
    }

    // MARK: - Metrics

    /// Compact: a short phone (iPhone SE, the Duo's cover display), or a Duo inner display where
    /// the sheet gets little room (upright: below the fold; book pose: the leading half).
    private func shouldUseCompactMetrics() -> Bool {
        let window = view.window ?? presentingViewController?.view.window
        let windowHeight = window?.bounds.height ?? view.bounds.height
        if traitCollection.horizontalSizeClass == .compact, windowHeight <= Layout.compactWindowHeight {
            return true
        }
        if #available(iOS 27.1, *), let presenterView = presentingViewController?.view {
            if let fold = FoldRegion.splittingFold(in: presenterView), fold.width > fold.height,
               presenterView.traitCollection.horizontalSizeClass == .regular {
                return true
            }
            if let fold = FoldRegion.activeFold(in: presenterView), fold.height > fold.width {
                return true
            }
        }
        return false
    }

    private func applyMetrics(_ metrics: Metrics) {
        didApplyMetrics = true
        titleLabel.font = ThemeManager.Fonts.titleFont(size: metrics.titleSize, weight: .heavy)
        figureLabel.font = .monospacedDigitSystemFont(ofSize: metrics.figureSize, weight: .heavy)
        barHeightConstraint?.constant = metrics.barHeight
        contentStack.setCustomSpacing(metrics.figureToBar, after: figureGroup)
        contentStack.setCustomSpacing(metrics.barToLedger, after: storageBar)
        contentStack.setCustomSpacing(metrics.ledgerToFooter, after: savedCard)
        // Saved hidden: the stack skips it, so the footer's gap also follows the ledger
        contentStack.setCustomSpacing(savedCard.isHidden ? metrics.ledgerToFooter : Layout.savedGap, after: ledgerCard)
        ledgerRows.forEach { $0.setVerticalPadding(metrics.rowPadding) }
        savedTopConstraint?.constant = metrics.savedPadding
        savedBottomConstraint?.constant = -metrics.savedPadding
    }

    private var currentMetrics: Metrics { isCompact ? .compact : .regular }

    private func updateMetricsIfNeeded() {
        let compact = shouldUseCompactMetrics()
        guard compact != isCompact || !didApplyMetrics else { return }
        isCompact = compact
        applyMetrics(currentMetrics)
    }

    /// "/ total" sits beside the figure while both fit one line, else under it.
    private func updateFigureAxis() {
        let width = figureGroup.bounds.width
        guard width > 0 else { return }
        let needed = figureLabel.intrinsicContentSize.width + figureRow.spacing + totalLabel.intrinsicContentSize.width
        let axis: NSLayoutConstraint.Axis = needed <= width ? .horizontal : .vertical
        guard figureRow.axis != axis else { return }
        figureRow.axis = axis
        figureRow.alignment = axis == .horizontal ? .firstBaseline : .leading
        figureRow.spacing = axis == .horizontal ? 6 : 2
    }

    // MARK: - Sheet size

    private var hostWindow: UIWindow? {
        view.window ?? presentingViewController?.view.window
    }

    /// iOS 16+: one detent as tall as the content. iOS 15: medium when the content fits it, else large.
    /// The first measurement, at the presenter's window width with the metrics for it.
    private func measureInitialHeight() {
        loadViewIfNeeded()
        updateMetricsIfNeeded()
        let windowWidth = hostWindow?.bounds.width ?? view.bounds.width
        let width = min(Layout.columnMaxWidth, windowWidth - 2 * Layout.sidePadding)
        fittedHeight = contentHeight(forWidth: width)
    }

    /// iOS 15 has no custom detent: medium when the content fits it, else large.
    private func configureDetents() {
        if fittedHeight <= 0 { measureInitialHeight() }
        guard #unavailable(iOS 16.0), let sheet = sheetPresentationController else { return }
        sheet.detents = legacyDetents(windowSize: hostWindow?.bounds.size ?? view.bounds.size)
    }

    private func legacyDetents(windowSize: CGSize) -> [UISheetPresentationController.Detent] {
        let bottomInset = hostWindow?.safeAreaInsets.bottom ?? 0
        return fittedHeight <= windowSize.height / 2 - bottomInset ? [.medium()] : [.large()]
    }

    /// The column's height from the sheet's top to the bottom safe area.
    private func contentHeight(forWidth width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let stackHeight = contentStack.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        return (Layout.topPadding + stackHeight + Layout.bottomPadding).rounded(.up)
    }

    /// Keeps the detent on the content's real height once the column has its width.
    private func updateFittedHeight() {
        let width = contentStack.bounds.width
        guard width > 0 else { return }
        let height = contentHeight(forWidth: width)

        // Fallback only: scroll when even the compact content doesn't fit
        let available = view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        let needsScroll = height > available + 0.5
        scrollView.isScrollEnabled = needsScroll
        scrollView.alwaysBounceVertical = needsScroll

        guard abs(height - fittedHeight) > 0.5 else { return }
        fittedHeight = height
        // Invalidating mid-presentation can leave the sheet stopped short of its place (iOS 18)
        guard view.window != nil, !isBeingPresented else {
            needsDetentRefresh = true
            return
        }
        applyDetentChange(animated: true)
    }

    private func applyDetentChange(animated: Bool) {
        guard let sheet = sheetPresentationController else { return }
        let change: () -> Void
        if #available(iOS 16.0, *) {
            change = { sheet.invalidateDetents() }
        } else {
            let detents = legacyDetents(windowSize: hostWindow?.bounds.size ?? view.bounds.size)
            change = { sheet.detents = detents }
        }
        if animated {
            sheet.animateChanges(change)
        } else {
            change()
        }
    }

    // MARK: - Rendering

    private var currentState: StorageAnalysisState {
        #if DEBUG
            if let previewState { return previewState }
        #endif
        return storageManager.currentState
    }

    /// Opened mid-scan: start the bar where the scan already is.
    private func seedProgress() {
        if case .loading = currentState, let progress = storageManager.currentProgress {
            scanProgress = Int(progress.overallProgress * 100)
        } else if case .loadingWithBasicInfo = currentState, let progress = storageManager.currentProgress {
            scanProgress = Int(progress.overallProgress * 100)
        }
    }

    /// Fills every value for the state. The layout stays; only the Saved card shows or hides.
    private func render(animated: Bool) {
        let apply = { [self] in applyValues(for: currentState) }
        if animated, view.window != nil {
            UIView.transition(
                with: contentStack, duration: Layout.valueFade, options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: apply)
        } else {
            apply()
        }
        view.setNeedsLayout()
    }

    private func applyValues(for state: StorageAnalysisState) {
        let dash = Strings.placeholder
        var isLoading = false

        switch state {
        case .loaded(let data):
            setFigure(used: data.usedBytes, total: data.totalDeviceBytes)
            configureLoadedBar(data)
            if data.iCloudPhotosSyncOn {
                photosRow.configure(color: .photo100, name: Strings.photos, count: nil, size: dash, reservesCountLine: true)
                videosRow.configure(color: .video100, name: Strings.videos, count: nil, size: dash, reservesCountLine: true)
                otherRow.configure(color: .storageOther, name: Strings.other, count: nil, size: dash)
            } else {
                photosRow.configure(
                    color: .photo100, name: Strings.photos, count: Strings.photoCount(data.photosCount),
                    size: Self.format(data.photosBytes))
                videosRow.configure(
                    color: .video100, name: Strings.videos, count: Strings.videoCount(data.videosCount),
                    size: Self.format(data.videosBytes))
                otherRow.configure(color: .storageOther, name: Strings.other, count: nil, size: Self.format(data.otherBytes))
            }
            availableRow.configure(
                color: .storageAvailable, name: Strings.available, count: nil, size: Self.format(data.availableBytes))
            let saved = statsStore.spaceSavedBytes
            setSavedVisible(saved > 0, bytes: saved)
            let date = data.formattedLastAnalysis
            setStatus(data.isStale ? Strings.lastAnalyzedStale(date: date) : Strings.lastAnalyzed(date: date))
            refreshTitle = Strings.refresh

        case .loading, .loadingWithBasicInfo:
            isLoading = true
            if case .loadingWithBasicInfo(let total, let available) = state {
                setFigure(used: total - available, total: total)
                availableRow.configure(color: .storageAvailable, name: Strings.available, count: nil, size: Self.format(available))
            } else {
                setFigure(used: nil, total: nil)
                availableRow.configure(color: .storageAvailable, name: Strings.available, count: nil, size: dash)
            }
            configureProgressBar(animated: false)
            setPlaceholderMediaRows()
            setSavedVisible(false, bytes: 0)
            updateProgressStatus()
            refreshTitle = Strings.refresh

        case .idle:
            setEmptyValues()
            setStatus(Strings.notAnalyzedYet)
            refreshTitle = Strings.analyzeStorage

        case .error:
            setEmptyValues()
            setStatus(Strings.unableToAnalyze)
            refreshTitle = Strings.tryAgain
        }

        configureRefreshButton()
        refreshButton.isEnabled = !isLoading
    }

    private static func format(_ bytes: Int64) -> String {
        bytes.formattedBytes(allowedUnits: [.useGB, .useMB])
    }

    private func setFigure(used: Int64?, total: Int64?) {
        let usedText = used.map(Self.format) ?? Strings.placeholder
        let totalText = total.map(Self.format) ?? Strings.placeholder
        figureLabel.text = usedText
        totalLabel.text = Strings.totalOf(totalText)
        figureGroup.accessibilityLabel = Strings.usedAccessibility(used: usedText, total: totalText)
    }

    private func setPlaceholderMediaRows() {
        let dash = Strings.placeholder
        photosRow.configure(color: .photo100, name: Strings.photos, count: nil, size: dash, reservesCountLine: true)
        videosRow.configure(color: .video100, name: Strings.videos, count: nil, size: dash, reservesCountLine: true)
        otherRow.configure(color: .storageOther, name: Strings.other, count: nil, size: dash)
    }

    private func setEmptyValues() {
        setFigure(used: nil, total: nil)
        storageBar.configure(segments: [], animated: false)
        setPlaceholderMediaRows()
        availableRow.configure(color: .storageAvailable, name: Strings.available, count: nil, size: Strings.placeholder)
        setSavedVisible(false, bytes: 0)
    }

    private func setSavedVisible(_ visible: Bool, bytes: Int64) {
        let value = Self.format(bytes)
        savedValueLabel.text = value
        savedCard.accessibilityLabel = "\(Strings.saved), \(value)"
        if savedCard.isHidden == visible { savedCard.isHidden = !visible }
        contentStack.setCustomSpacing(visible ? Layout.savedGap : currentMetrics.ledgerToFooter, after: ledgerCard)
    }

    private func setStatus(_ text: String, emphasized: Bool = false) {
        statusLabel.text = text
        statusLabel.font = emphasized ? ThemeManager.Fonts.semiboldCaption : ThemeManager.Fonts.regularCaption
    }

    private func updateProgressStatus() {
        if let scanPhase {
            setStatus(Strings.progressLabel(phase: scanPhase, progress: scanProgress), emphasized: true)
        } else {
            setStatus(Strings.analyzing, emphasized: true)
        }
    }

    private func configureLoadedBar(_ data: StorageAnalysisData) {
        guard data.totalDeviceBytes > 0 else {
            storageBar.configure(segments: [], animated: false)
            return
        }
        let total = CGFloat(data.totalDeviceBytes)
        let shares: [(UIColor, Int64)] = [
            (.photo100, data.photosBytes),
            (.video100, data.videosBytes),
            (.storageOther, data.otherBytes),
            (.storageAvailable, data.availableBytes)
        ]
        let segments = shares
            .filter { $0.1 > 0 }
            .map { SegmentedBarView.Segment(color: $0.0, percentage: CGFloat($0.1) / total) }
        storageBar.configure(segments: segments, animated: true)
    }

    /// One gray segment growing with the scan; the rest is the track.
    private func configureProgressBar(animated: Bool) {
        let share = CGFloat(min(max(scanProgress, 0), 100)) / 100
        guard share > 0 else {
            storageBar.configure(segments: [], animated: false)
            return
        }
        let fill = UIColor.secondaryLabel.withAlphaComponent(Layout.progressAlpha)
        let segments: [SegmentedBarView.Segment] = share >= 1
            ? [.init(color: fill, percentage: 1)]
            : [.init(color: fill, percentage: share), .init(color: .clear, percentage: 1 - share)]
        storageBar.configure(segments: segments, animated: animated)
    }

    private func configureRefreshButton() {
        refreshButton.configure(
            title: refreshTitle,
            systemImage: "arrow.clockwise",
            style: .regular,
            backgroundColor: .systemGray5,
            foregroundColor: .label,
            fontSize: 15,
            fontWeight: .semibold,
            iconSize: 13,
            contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
        refreshButton.accessibilityLabel = refreshTitle
    }

    // MARK: - Actions

    @objc private func refreshTapped() {
        HapticFeedbackManager.shared.impact(intensity: .light)
        storageManager.startAnalysis()
    }

    // MARK: - Notifications

    @objc private func storageStateChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if notification.name == .storageAnalysisDidStart {
                self.scanProgress = 0
                self.scanPhase = nil
            }
            self.render(animated: true)
        }
    }

    @objc private func handleProgressUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let phase = userInfo["phase"] as? String,
              let progress = userInfo["progress"] as? Int
        else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.currentState.isLoading else { return }
            self.scanPhase = phase
            self.scanProgress = progress
            // The bar rebuilds its segments, so it isn't animated on every chunk
            self.configureProgressBar(animated: false)
            self.updateProgressStatus()
        }
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    private enum PreviewData {
        static let loaded = StorageAnalysisData(
            photosCount: 4312, photosBytes: 12_400_000_000,
            videosCount: 286, videosBytes: 31_800_000_000,
            totalDeviceBytes: 494_380_000_000, availableBytes: 25_610_000_000,
            lastAnalysisDate: Date().addingTimeInterval(-3600))
    }

    @available(iOS 17.0, *)
    #Preview("Loaded") {
        StorageAnalysisBottomSheet(previewState: .loaded(PreviewData.loaded))
    }

    @available(iOS 17.0, *)
    #Preview("Scanning") {
        StorageAnalysisBottomSheet(
            previewState: .loadingWithBasicInfo(totalBytes: 494_380_000_000, availableBytes: 25_610_000_000),
            progress: 40)
    }

    @available(iOS 17.0, *)
    #Preview("Not analyzed") {
        StorageAnalysisBottomSheet(previewState: .idle)
    }
#endif
