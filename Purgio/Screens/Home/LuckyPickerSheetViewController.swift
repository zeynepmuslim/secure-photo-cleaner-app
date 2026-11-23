//
//  LuckyPickerSheetViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 27.01.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let title              = NSLocalizedString("luckyPicker.title", comment: "I Feel Lucky sheet title")
    static let shuffleAgain       = NSLocalizedString("luckyPicker.shuffleAgain", comment: "Shuffle again button")
    static let media              = NSLocalizedString("luckyPicker.media", comment: "Media section label")
    static let month              = NSLocalizedString("luckyPicker.month", comment: "Month section label")
    static let filter             = NSLocalizedString("luckyPicker.filter", comment: "Filter section label")
    static let noMonthsAvailable  = NSLocalizedString("luckyPicker.noMonthsAvailable", comment: "No months available message")
    static let noMonth            = NSLocalizedString("luckyPicker.noMonth", comment: "No month placeholder")
    static let mediaOptionPhotos  = NSLocalizedString("luckyPicker.photos", comment: "Photos media option")
    static let mediaOptionVideos  = NSLocalizedString("luckyPicker.videos", comment: "Videos media option")
    static let filterAll          = NSLocalizedString("luckyPicker.filterAll", comment: "All filter option")
    static let screenshots        = NSLocalizedString("luckyPicker.screenshots", comment: "Screenshots filter option")
    static let largePhotos        = NSLocalizedString("luckyPicker.largePhotos", comment: "Large photos filter option")
    static let largeVideos        = NSLocalizedString("luckyPicker.largeVideos", comment: "Large videos filter option")
    static let eyesClosed         = NSLocalizedString("luckyPicker.eyesClosed", comment: "Eyes closed filter option")
    static let screenRecordings   = NSLocalizedString("luckyPicker.screenRecordings", comment: "Screen recordings filter option")
    static let slowMotion         = NSLocalizedString("luckyPicker.slowMotion", comment: "Slow motion filter option")
    static let timeLapse          = NSLocalizedString("luckyPicker.timeLapse", comment: "Time-lapse filter option")
    static let columnHint         = NSLocalizedString("luckyPicker.columnHint", comment: "VoiceOver hint for a wheel column")
    static func goToButton(media: String, monthTitle: String) -> String {
        String(format: NSLocalizedString("luckyPicker.goToButton", comment: "Go to button, e.g. 'Go to Photos · January 2025'"), media, monthTitle)
    }
}

final class LuckyPickerSheetViewController: UIViewController {

    struct MonthOption {
        let key: String
        let title: String
        let totalCount: Int
    }

    /// The wheel's columns, in the order a pick depends on: a month belongs to a media type,
    /// a filter to a month.
    private enum Column: Int, CaseIterable {
        case media
        case month
        case filter
    }

    /// How likely each choice is, against `√items left`. The targeted filters have a real count
    /// and get a boost; Largest First and Eyes Closed can't be counted without a scan, so they
    /// take a fixed share of the month.
    private enum Weights {
        static let targetedBoost: Double = 1.5
        static let largestShare: Double = 0.5
        static let eyesClosedShare: Double = 0.35
    }

    struct FilterOption {
        let title: String
        let context: FilterContext
        let systemImageName: String
    }

    enum MediaOption: Int, CaseIterable {
        case photos
        case videos

        var title: String {
            switch self {
            case .photos:
                return Strings.mediaOptionPhotos
            case .videos:
                return Strings.mediaOptionVideos
            }
        }

        var mediaType: PHAssetMediaType {
            switch self {
            case .photos:
                return .image
            case .videos:
                return .video
            }
        }
    }

    var onSelect: ((PHAssetMediaType, String, FilterContext) -> Void)?

    /// The column's height from the sheet's top to the bottom safe area; the sheet's detent.
    private(set) var fittedHeight: CGFloat = 0

    // MARK: - Layout

    private struct Metrics: Equatable {
        let topPadding: CGFloat
        let sidePadding: CGFloat
        let bottomPadding: CGFloat
        let headerToWheel: CGFloat
        let wheelToActions: CGFloat
        let columnSpacing: CGFloat
        let wheelHeight: CGFloat
        let rowFontSize: CGFloat
        let shuffleHeight: CGFloat
        let goHeight: CGFloat
        let isNarrow: Bool

        static func make(isCompact: Bool, isNarrow: Bool) -> Metrics {
            Metrics(
                topPadding: isCompact ? 22 : 26,
                sidePadding: isCompact ? GeneralConstants.EdgePadding.medium : GeneralConstants.EdgePadding.content,
                bottomPadding: isCompact ? GeneralConstants.EdgePadding.medium : GeneralConstants.EdgePadding.content,
                headerToWheel: isCompact ? 12 : 16,
                wheelToActions: isCompact ? GeneralConstants.EdgePadding.medium : GeneralConstants.EdgePadding.content,
                columnSpacing: isNarrow ? 6 : 8,
                wheelHeight: isCompact ? 150 : 180,
                rowFontSize: isNarrow ? 15 : (isCompact ? 16 : 17),
                shuffleHeight: isCompact ? GeneralConstants.ButtonSize.medium : GeneralConstants.ButtonSize.mediumLarge,
                goHeight: isCompact ? GeneralConstants.ButtonSize.mediumLarge : GeneralConstants.ButtonSize.large,
                isNarrow: isNarrow)
        }
    }

    private enum Layout {
        static let columnMaxWidth: CGFloat = 560
        static let narrowRowWidth: CGFloat = 360
        static let compactWindowHeight: CGFloat = 700
        static let legacyLargeWindowHeight: CGFloat = 667
        static let actionSpacing: CGFloat = 8
        static let labelsToWheel: CGFloat = 2
        /// Shuffle's and Go's content insets
        static let buttonInsets = NSDirectionalEdgeInsets(
            top: 8, leading: GeneralConstants.EdgePadding.medium,
            bottom: 8, trailing: GeneralConstants.EdgePadding.medium)
        /// Tall enough for a pick that wraps to two lines
        static let wheelRowHeight: CGFloat = 44
        /// Gap between a wheel value and its column's edges (narrow rows: 4)
        static let wheelRowInset: CGFloat = 6
        static let narrowWheelRowInset: CGFloat = 4
        /// Room the system wheel keeps between and beside its columns
        static let wheelColumnGaps: CGFloat = 24
        /// How far the wheel reaches past the column on each side, so its gray selection band
        /// (inset inside the wheel) spans the column like the buttons under it
        static let wheelBandOverhang: CGFloat = 10
        /// Month and Filter widths against Media's (1 : 1.15 : 1.35; narrow 1.15 : 1.1 : 1.25)
        static let regularWeights: (month: CGFloat, filter: CGFloat) = (1.15, 1.35)
        static let narrowWeights: (month: CGFloat, filter: CGFloat) = (1.1 / 1.15, 1.25 / 1.15)
    }

    // MARK: - Views

    private let actionButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityTraits = .button
        return button
    }()

    private let shuffleButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        // "dice" needs SF Symbols 4; iOS 15 falls back to the die
        let dice = UIImage(systemName: "dice", withConfiguration: symbolConfig)
            ?? UIImage(systemName: "die.face.5", withConfiguration: symbolConfig)
        button.configure(
            title: Strings.shuffleAgain,
            image: dice,
            style: .regular,
            backgroundColor: .cardBackground,
            foregroundColor: .label,
            fontSize: 16,
            fontWeight: .semibold,
            contentInsets: Layout.buttonInsets
        )
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.attributedText = NSAttributedString(
            string: Strings.title,
            attributes: [
                .font: ThemeManager.Fonts.titleFont(size: 24, weight: .heavy),
                .foregroundColor: UIColor.label,
                .kern: -0.3
            ])
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        return label
    }()

    /// The header over the wheel, pinned to the top; the free height goes under it.
    private let topStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        return stack
    }()

    /// A blue band over the wheel's own gray one, faded in for a moment when a spin lands
    private let pickFlashView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .luckyPickFlash
        view.layer.cornerRadius = Layout.wheelRowHeight / 2
        view.layer.cornerCurve = .continuous
        view.alpha = 0
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }()
    /// Bumped by every flash and reset, so a stale step of an earlier flash does nothing
    private var flashGeneration = 0
    /// The spin's and the flash's timed steps; cancelled by the next spin and in `viewWillDisappear`
    private var pendingSpinSteps: [DispatchWorkItem] = []

    /// Holds the wheel, which reaches `wheelBandOverhang` past it on each side
    private let wheelHolder: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Media, Month and Filter over the wheel's columns
    private let columnLabelsRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        return stack
    }()

    private let mediaLabel = ColumnTitleView(title: Strings.media)
    private let monthLabel = ColumnTitleView(title: Strings.month)
    private let filterLabel = ColumnTitleView(title: Strings.filter)

    /// The system wheel, one column per choice. It shows the pick; it isn't for choosing:
    /// `wheelTouchView` over it turns a tap or a swipe on a column into a roll of that column.
    private let pickerView: UIPickerView = {
        let picker = UIPickerView()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.isUserInteractionEnabled = false
        // Its intrinsic 320pt width would otherwise set the column's
        picker.setContentHuggingPriority(.defaultLow, for: .horizontal)
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return picker
    }()

    private let actionsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.actionSpacing
        return stack
    }()

    /// The rows of each wheel column (media, month, filter), and the one at rest in the window
    private var wheelRows: [[String]] = [
        [" ", Strings.mediaOptionPhotos, Strings.mediaOptionVideos], [" ", "—", " "], [" ", "—", " "]
    ]
    private var appliedColumnWidths: [CGFloat] = []
    private var wheelHeightConstraint: NSLayoutConstraint?

    private let columnGuide = UILayoutGuide()

    private var metrics: Metrics?
    private var columnWidthConstraint: NSLayoutConstraint?
    private var columnLeadingConstraint: NSLayoutConstraint?
    private var columnTrailingConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var wheelToActionsConstraint: NSLayoutConstraint?
    private var shuffleHeightConstraint: NSLayoutConstraint?
    private var goHeightConstraint: NSLayoutConstraint?
    private var regularWeightConstraints: [NSLayoutConstraint] = []
    private var narrowWeightConstraints: [NSLayoutConstraint] = []
    private var needsDetentRefresh = false

    /// A row of the column whose sides inset only where the camera overlaps it (`updateOcclusionClearance`)
    private struct OcclusionRow {
        let row: UIView
        let leading: NSLayoutConstraint
        let trailing: NSLayoutConstraint
    }
    private var occlusionRows: [OcclusionRow] = []

    private let photoLibraryService = PhotoLibraryService.shared
    private let reviewProgressStore = ReviewProgressStore.shared

    private var photoMonths: [MonthOption] = []
    private var videoMonths: [MonthOption] = []
    private var cachedAvailablePhotoMonths: [MonthOption]?
    private var cachedAvailableVideoMonths: [MonthOption]?
    private var selectedMedia: MediaOption = .photos
    private var selectedMonth: MonthOption?
    private var selectedFilter: FilterOption = FilterOption(
        title: Strings.filterAll,
        context: .none,
        systemImageName: "square.grid.2x2"
    )
    /// The wheel is turning; Go and Shuffle wait for it
    private var isSpinning = false
    /// The month buckets are in; a spin asked for before that starts once they are
    private var hasLoadedMonths = false
    private var isSpinPending = false
    /// Loads the month buckets and the subtype counts; cancelled when the sheet goes away
    private var loadMonthsTask: Task<Void, Never>?
    /// Items of each targeted filter's subtype per month key (screenshots, slow motion, …)
    private var subtypeCounts: [FilterContext: [String: Int]] = [:]
    private var wheelColumnElements: [WheelColumnElement] = []
    private var panStartColumn: Column?

    /// A transparent layer over the wheel: a tap or a vertical swipe on a column rolls it.
    private let wheelTouchView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    private lazy var wheelPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleWheelPan(_:)))
    private lazy var wheelTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleWheelTap(_:)))

    private let photoFilters: [FilterOption] = [
        FilterOption(title: Strings.filterAll, context: .none, systemImageName: "square.grid.2x2"),
        FilterOption(title: Strings.screenshots, context: .screenshots, systemImageName: "camera.viewfinder"),
        FilterOption(title: Strings.largePhotos, context: .largeFiles, systemImageName: "arrow.up.arrow.down"),
        FilterOption(title: Strings.eyesClosed, context: .eyesClosed, systemImageName: "eye.slash")
    ]

    private let videoFilters: [FilterOption] = [
        FilterOption(title: Strings.filterAll, context: .none, systemImageName: "square.grid.2x2"),
        FilterOption(title: Strings.screenRecordings, context: .screenRecordings, systemImageName: "record.circle"),
        FilterOption(title: Strings.slowMotion, context: .slowMotion, systemImageName: "slowmo"),
        FilterOption(title: Strings.timeLapse, context: .timeLapse, systemImageName: "timelapse"),
        FilterOption(title: Strings.largeVideos, context: .largeFiles, systemImageName: "arrow.up.arrow.down")
    ]

    // MARK: - Lifecycle

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        configureSheet()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyBlurredBackground()
        setupUI()
        setupConstraint()
        loadMonths()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
                (self: LuckyPickerSheetViewController, _: UITraitCollection) in
                self.updateActionButtonTitle()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        spin(Set(Column.allCases))
        // A height that changed while the sheet was coming up is applied once it has settled
        guard needsDetentRefresh else { return }
        needsDetentRefresh = false
        applyDetentChange(animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        loadMonthsTask?.cancel()
        cancelSpinSteps()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let window = hostWindow
        applyMetricsIfNeeded(
            isCompact: isCompactLayout(sizeClass: traitCollection.horizontalSizeClass, window: window),
            isNarrow: columnLabelsRow.bounds.width > 0
                ? columnLabelsRow.bounds.width < Layout.narrowRowWidth
                : (metrics?.isNarrow ?? false))
        updateWheelColumnWidths()
        alignColumnLabelsToWheel()
        updateWheelAccessibilityFrames()
        updateOcclusionClearance()
        updateFittedHeight()
    }

    /// Insets a row evenly on both sides by how far the Duo's camera reaches into it.
    private func updateOcclusionClearance() {
        var cameras: [CGRect] = []
        if #available(iOS 27.1, *) {
            cameras = view.reservedRegions(kind: .occlusion).map(\.frame)
        }
        let column = columnGuide.layoutFrame
        var changed = false
        for entry in occlusionRows {
            let frame = CGRect(x: column.minX, y: entry.row.frame.minY, width: column.width, height: entry.row.frame.height)
            var inset: CGFloat = 0
            if frame.width > 0 {
                for camera in cameras where camera.intersects(frame) {
                    // How far the camera reaches into the row from the edge it sits on
                    let overlap = camera.midX > frame.midX ? frame.maxX - camera.minX : camera.maxX - frame.minX
                    inset = max(inset, min(overlap, frame.width / 4))
                }
            }
            guard entry.leading.constant != inset else { continue }
            entry.leading.constant = inset
            entry.trailing.constant = -inset
            changed = true
        }
        if changed { view.setNeedsLayout() }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard #unavailable(iOS 17.0) else { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateActionButtonTitle()
        }
    }

    // MARK: - Setup

    private func configureSheet() {
        modalPresentationStyle = .pageSheet
        guard let sheet = sheetPresentationController else { return }
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        // The detent is set before the presentation lays out; its height is measured
        // the first time the system asks, when the presenter's window is known.
        if #available(iOS 16.0, *) {
            sheet.detents = [
                .custom(identifier: .init("luckyPicker.content")) { [weak self] context in
                    guard let self else { return nil }
                    if self.fittedHeight <= 0 { self.measureInitialHeight() }
                    return min(self.fittedHeight, context.maximumDetentValue)
                }
            ]
        } else {
            sheet.detents = [.medium()]
        }
    }

    /// A blurred sheet: a material fills it edge to edge, so Home shows through only as color.
    /// On iOS 26 a thin material keeps the sheet's own glass edge; before it, the regular one.
    private func applyBlurredBackground() {
        view.backgroundColor = .clear
        let style: UIBlurEffect.Style
        if #available(iOS 26.0, *) {
            style = .systemThinMaterial
        } else {
            style = .systemMaterial
        }
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: style))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)
        // Decoration only, so it spans the full width (see iPhone Duo → safe-area exceptions)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupUI() {
        actionButton.addTarget(self, action: #selector(handleGoTap), for: .touchUpInside)
        shuffleButton.addTarget(self, action: #selector(handleShuffleTap), for: .touchUpInside)

        pickerView.dataSource = self
        pickerView.delegate = self

        wheelHolder.addSubview(pickerView)
        wheelHolder.addSubview(pickFlashView)

        columnLabelsRow.addArrangedSubview(mediaLabel)
        columnLabelsRow.addArrangedSubview(monthLabel)
        columnLabelsRow.addArrangedSubview(filterLabel)

        topStack.addArrangedSubview(titleLabel)
        topStack.addArrangedSubview(columnLabelsRow)
        topStack.addArrangedSubview(wheelHolder)
        topStack.setCustomSpacing(Layout.labelsToWheel, after: columnLabelsRow)

        actionsStack.addArrangedSubview(shuffleButton)
        actionsStack.addArrangedSubview(actionButton)

        view.addLayoutGuide(columnGuide)
        view.addSubview(topStack)
        view.addSubview(actionsStack)
        view.addSubview(wheelTouchView)

        actionButton.isEnabled = false
        shuffleButton.isEnabled = false

        setupWheelInteraction()
        updateActionButtonTitle()
    }

    private func setupConstraint() {
        let safe = view.safeAreaLayoutGuide
        let regular = Metrics.make(isCompact: false, isNarrow: false)

        let leading = columnGuide.leadingAnchor.constraint(
            greaterThanOrEqualTo: view.leadingAnchor, constant: regular.sidePadding)
        let trailing = columnGuide.trailingAnchor.constraint(
            lessThanOrEqualTo: view.trailingAnchor, constant: -regular.sidePadding)
        // The sheet covers the tab bar and the Duo's side bar, so the column spans its full
        // width (like the tip jar and the help sheet); only rows the camera overlaps narrow.
        // As wide as the room allows, up to the cap
        let width = columnGuide.widthAnchor.constraint(
            equalTo: view.widthAnchor, constant: -2 * regular.sidePadding)
        width.priority = .defaultHigh
        let top = topStack.topAnchor.constraint(equalTo: safe.topAnchor, constant: regular.topPadding)
        let bottom = actionsStack.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -regular.bottomPadding)
        // The free height goes above the actions; a sheet shorter than its content squeezes it
        let gap = actionsStack.topAnchor.constraint(
            greaterThanOrEqualTo: topStack.bottomAnchor, constant: regular.wheelToActions)
        gap.priority = .defaultHigh
        let shuffleHeight = shuffleButton.heightAnchor.constraint(equalToConstant: regular.shuffleHeight)
        let goHeight = actionButton.heightAnchor.constraint(equalToConstant: regular.goHeight)

        columnLeadingConstraint = leading
        columnTrailingConstraint = trailing
        columnWidthConstraint = width
        topConstraint = top
        bottomConstraint = bottom
        wheelToActionsConstraint = gap
        let wheelHeight = pickerView.heightAnchor.constraint(equalToConstant: regular.wheelHeight)
        wheelHeightConstraint = wheelHeight
        shuffleHeightConstraint = shuffleHeight
        goHeightConstraint = goHeight

        regularWeightConstraints = [
            monthLabel.widthAnchor.constraint(equalTo: mediaLabel.widthAnchor, multiplier: Layout.regularWeights.month),
            filterLabel.widthAnchor.constraint(equalTo: mediaLabel.widthAnchor, multiplier: Layout.regularWeights.filter)
        ]
        narrowWeightConstraints = [
            monthLabel.widthAnchor.constraint(equalTo: mediaLabel.widthAnchor, multiplier: Layout.narrowWeights.month),
            filterLabel.widthAnchor.constraint(equalTo: mediaLabel.widthAnchor, multiplier: Layout.narrowWeights.filter)
        ]

        NSLayoutConstraint.activate([
            leading, trailing, width, top, bottom, gap, shuffleHeight, goHeight, wheelHeight,
            columnGuide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            columnGuide.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.columnMaxWidth),

            pickerView.topAnchor.constraint(equalTo: wheelHolder.topAnchor),
            pickerView.bottomAnchor.constraint(equalTo: wheelHolder.bottomAnchor),
            pickerView.leadingAnchor.constraint(equalTo: wheelHolder.leadingAnchor, constant: -Layout.wheelBandOverhang),
            pickerView.trailingAnchor.constraint(equalTo: wheelHolder.trailingAnchor, constant: Layout.wheelBandOverhang),
            // The system band spans the column, so the flash does too
            pickFlashView.leadingAnchor.constraint(equalTo: wheelHolder.leadingAnchor),
            pickFlashView.trailingAnchor.constraint(equalTo: wheelHolder.trailingAnchor),
            pickFlashView.centerYAnchor.constraint(equalTo: pickerView.centerYAnchor),
            pickFlashView.heightAnchor.constraint(equalToConstant: Layout.wheelRowHeight),

            wheelTouchView.topAnchor.constraint(equalTo: pickerView.topAnchor),
            wheelTouchView.bottomAnchor.constraint(equalTo: pickerView.bottomAnchor),
            wheelTouchView.leadingAnchor.constraint(equalTo: pickerView.leadingAnchor),
            wheelTouchView.trailingAnchor.constraint(equalTo: pickerView.trailingAnchor)
        ] + regularWeightConstraints)

        occlusionRows = [topStack, actionsStack].map { row in
            OcclusionRow(
                row: row,
                leading: row.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
                trailing: row.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor))
        }
        NSLayoutConstraint.activate(occlusionRows.flatMap { [$0.leading, $0.trailing] })

        applyMetrics(regular)
    }

    // MARK: - Metrics

    private var hostWindow: UIWindow? {
        view.window ?? presentingViewController?.view.window
    }

    /// Compact: a compact-width window up to 700pt tall (iPhone SE, the Duo's cover display),
    /// or the book pose, where the sheet floats in the leading half.
    private func isCompactLayout(sizeClass: UIUserInterfaceSizeClass, window: UIWindow?) -> Bool {
        let windowHeight = window?.bounds.height ?? view.bounds.height
        if sizeClass == .compact && windowHeight <= Layout.compactWindowHeight { return true }
        if #available(iOS 27.1, *), let foldView = presentingViewController?.view ?? window,
           FoldRegion.pose(for: FoldRegion.activeFold(in: foldView)) == .book {
            return true
        }
        return false
    }

    private func applyMetricsIfNeeded(isCompact: Bool, isNarrow: Bool) {
        let next = Metrics.make(isCompact: isCompact, isNarrow: isNarrow)
        guard next != metrics else { return }
        applyMetrics(next)
    }

    private func applyMetrics(_ next: Metrics) {
        let previous = metrics
        metrics = next

        topConstraint?.constant = next.topPadding
        bottomConstraint?.constant = -next.bottomPadding
        columnLeadingConstraint?.constant = next.sidePadding
        columnTrailingConstraint?.constant = -next.sidePadding
        columnWidthConstraint?.constant = -2 * next.sidePadding
        wheelToActionsConstraint?.constant = next.wheelToActions
        wheelHeightConstraint?.constant = next.wheelHeight
        shuffleHeightConstraint?.constant = next.shuffleHeight
        goHeightConstraint?.constant = next.goHeight

        topStack.spacing = next.headerToWheel
        topStack.setCustomSpacing(Layout.labelsToWheel, after: columnLabelsRow)
        columnLabelsRow.spacing = next.columnSpacing
        if previous?.rowFontSize != next.rowFontSize {
            pickerView.reloadAllComponents()
        }

        if previous?.isNarrow != next.isNarrow {
            NSLayoutConstraint.deactivate(next.isNarrow ? regularWeightConstraints : narrowWeightConstraints)
            NSLayoutConstraint.activate(next.isNarrow ? narrowWeightConstraints : regularWeightConstraints)
        }
        if previous != nil {
            updateActionButtonTitle()
        }
    }

    // MARK: - Sheet size

    /// The first measurement, at the presenter's window width with the metrics for it.
    private func measureInitialHeight() {
        loadViewIfNeeded()
        let window = hostWindow
        let windowWidth = window?.bounds.width ?? view.bounds.width
        let sizeClass = window?.traitCollection.horizontalSizeClass ?? traitCollection.horizontalSizeClass
        let isCompact = isCompactLayout(sizeClass: sizeClass, window: window)
        let side = Metrics.make(isCompact: isCompact, isNarrow: false).sidePadding
        let width = min(Layout.columnMaxWidth, windowWidth - 2 * side)
        applyMetricsIfNeeded(isCompact: isCompact, isNarrow: width < Layout.narrowRowWidth)
        fittedHeight = contentHeight(forWidth: width)
        if #unavailable(iOS 16.0) {
            applyLegacyDetents()
        }
    }

    /// The column's height from the sheet's top to the bottom safe area.
    private func contentHeight(forWidth width: CGFloat) -> CGFloat {
        guard width > 0, let metrics else { return 0 }
        let fitting = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let topHeight = topStack.systemLayoutSizeFitting(
            fitting, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        let actionsHeight = actionsStack.systemLayoutSizeFitting(
            fitting, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        return (metrics.topPadding + topHeight + metrics.wheelToActions + actionsHeight + metrics.bottomPadding)
            .rounded(.up)
    }

    /// Keeps the detent on the content's real height once the column has its width.
    private func updateFittedHeight() {
        let width = topStack.bounds.width
        guard width > 0 else { return }
        let height = contentHeight(forWidth: width)
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
            change = { [weak self] in self?.applyLegacyDetents() }
        }
        if animated {
            sheet.animateChanges(change)
        } else {
            change()
        }
    }

    /// iOS 15 has no custom detent: medium, large on short windows.
    private func applyLegacyDetents() {
        guard let sheet = sheetPresentationController else { return }
        let windowHeight = hostWindow?.bounds.height ?? view.bounds.height
        sheet.detents = windowHeight <= Layout.legacyLargeWindowHeight ? [.large()] : [.medium()]
    }

    // MARK: - Data Loading

    /// The month buckets (cached ones come back at once) and each targeted filter's count per
    /// month, which the weights need before the first pick.
    private func loadMonths() {
        let service = photoLibraryService
        loadMonthsTask?.cancel()
        loadMonthsTask = Task { [weak self] in
            async let photos = service.loadMonthBuckets(mediaType: .image)
            async let videos = service.loadMonthBuckets(mediaType: .video)
            async let screenshots = service.subtypeMonthCounts(mediaType: .image, subtype: .photoScreenshot)
            async let recordings = service.subtypeMonthCounts(mediaType: .video, subtype: .videoScreenRecording)
            async let slowMotion = service.subtypeMonthCounts(mediaType: .video, subtype: .videoHighFrameRate)
            async let timeLapse = service.subtypeMonthCounts(mediaType: .video, subtype: .videoTimelapse)

            // The buckets come first (usually cached): real values fill the wheel at once,
            // so it never sits blank while the subtype counts load
            let (loadedPhotos, loadedVideos) = await (photos, videos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.photoMonths = loadedPhotos.map { MonthOption(key: $0.key, title: $0.title, totalCount: $0.totalCount) }
                self.videoMonths = loadedVideos.map { MonthOption(key: $0.key, title: $0.title, totalCount: $0.totalCount) }
                self.didLoadBuckets()
            }

            let counts: [FilterContext: [String: Int]] = await [
                .screenshots: screenshots,
                .screenRecordings: recordings,
                .slowMotion: slowMotion,
                .timeLapse: timeLapse
            ]
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else { return }
                self.subtypeCounts = counts
                self.didLoadMonths()
            }
        }
    }

    /// Shows a provisional pick at rest while the counts load; the spin rolls again once they're in.
    private func didLoadBuckets() {
        cacheAvailableMonths()
        guard !isSpinning else { return }
        _ = roll(Set(Column.allCases))
        showSelection()
    }

    /// Shows a first pick at rest, or starts the spin that was waiting for the months.
    private func didLoadMonths() {
        hasLoadedMonths = true
        cacheAvailableMonths()
        if isSpinPending {
            isSpinPending = false
            spin(Set(Column.allCases))
        } else if !isSpinning {
            _ = roll(Set(Column.allCases))
            showSelection()
            updateButtonsForRest()
        }
    }

    private func cacheAvailableMonths() {
        cachedAvailablePhotoMonths = photoMonths.filter { month in
            !isMonthComplete(monthKey: month.key, mediaType: .image)
        }

        cachedAvailableVideoMonths = videoMonths.filter { month in
            !isMonthComplete(monthKey: month.key, mediaType: .video)
        }
    }

    private func months(for media: MediaOption) -> [MonthOption] {
        switch media {
        case .photos:
            return photoMonths
        case .videos:
            return videoMonths
        }
    }

    private func availableMonths(for media: MediaOption) -> [MonthOption] {
        switch media {
        case .photos:
            if let cached = cachedAvailablePhotoMonths {
                return cached
            }
        case .videos:
            if let cached = cachedAvailableVideoMonths {
                return cached
            }
        }

        let allMonths = months(for: media)
        let available = allMonths.filter { month in
            !isMonthComplete(monthKey: month.key, mediaType: media.mediaType)
        }

        switch media {
        case .photos:
            cachedAvailablePhotoMonths = available
        case .videos:
            cachedAvailableVideoMonths = available
        }

        return available
    }

    private func isMonthComplete(monthKey: String, mediaType: PHAssetMediaType) -> Bool {
        let progress = reviewProgressStore.getProgress(forMonthKey: monthKey, mediaType: mediaType)
        return progress.originalTotalCount > 0 && progress.reviewedCount >= progress.originalTotalCount
    }

    private func filters(for media: MediaOption) -> [FilterOption] {
        switch media {
        case .photos:
            return photoFilters
        case .videos:
            return videoFilters
        }
    }

    // MARK: - Weighted Pick

    /// Items still to review in a month: its record's total minus what's reviewed, or the
    /// bucket's count before it has a record.
    private func remaining(_ month: MonthOption, media: MediaOption) -> Int {
        let progress = reviewProgressStore.getProgress(forMonthKey: month.key, mediaType: media.mediaType)
        guard progress.originalTotalCount > 0 else { return month.totalCount }
        return max(0, progress.originalTotalCount - progress.reviewedCount)
    }

    private func weight(of media: MediaOption) -> Double {
        let left = availableMonths(for: media).reduce(0) { $0 + remaining($1, media: media) }
        return Double(left).squareRoot()
    }

    private func weight(of month: MonthOption, media: MediaOption) -> Double {
        Double(remaining(month, media: media)).squareRoot()
    }

    /// 0 for a filter that's finished or has nothing left in the month, so it never comes up.
    private func weight(of filter: FilterOption, in month: MonthOption, media: MediaOption) -> Double {
        let type = MonthFilterStatusStore.FilterType(filterContext: filter.context)
        guard !type.isComplete(monthKey: month.key, mediaType: media.mediaType) else { return 0 }
        let monthWeight = weight(of: month, media: media)
        switch filter.context {
        case .none:
            return monthWeight
        case .largeFiles:
            return monthWeight * Weights.largestShare
        case .eyesClosed:
            return monthWeight * Weights.eyesClosedShare
        case .screenshots, .screenRecordings, .slowMotion, .timeLapse:
            let count = subtypeCounts[filter.context]?[month.key] ?? 0
            let filterKey = "\(month.key)_\(type.rawValue)"
            let reviewed = reviewProgressStore.getProgress(forMonthKey: filterKey, mediaType: media.mediaType).reviewedCount
            let left = count - reviewed
            return left > 0 ? Double(left).squareRoot() * Weights.targetedBoost : 0
        }
    }

    /// The filters that can come up in the current month, with their weights.
    private func pickableFilters() -> [(filter: FilterOption, weight: Double)] {
        guard let month = selectedMonth else { return [] }
        return filters(for: selectedMedia)
            .map { ($0, weight(of: $0, in: month, media: selectedMedia)) }
            .filter { $0.1 > 0 }
    }

    /// One of `items`, each as likely as its weight; nil when none weighs anything.
    private func weightedRandom<T>(_ items: [(T, Double)]) -> T? {
        let total = items.reduce(0) { $0 + max(0, $1.1) }
        guard total > 0 else { return nil }
        var target = Double.random(in: 0..<total)
        for (item, weight) in items where weight > 0 {
            if target < weight { return item }
            target -= weight
        }
        return items.last { $0.1 > 0 }?.0
    }

    /// Rolls `requested` by weight. A later column keeps its pick while it still fits (its month
    /// is unfinished in the media, its filter has something left in the month) and rolls when it
    /// doesn't. Returns the columns to turn: the requested ones and any whose pick changed.
    private func roll(_ requested: Set<Column>) -> [Column] {
        let before = currentPicks

        let mediaWeights = MediaOption.allCases.map { ($0, weight(of: $0)) }
        let mediaFits = mediaWeights.contains { $0.0 == selectedMedia && $0.1 > 0 }
        if requested.contains(.media) || !mediaFits {
            selectedMedia = weightedRandom(mediaWeights) ?? selectedMedia
        }

        let months = availableMonths(for: selectedMedia)
        let monthFits = selectedMonth.map { month in months.contains { $0.key == month.key } } ?? false
        if requested.contains(.month) || !monthFits {
            selectedMonth = weightedRandom(months.map { ($0, weight(of: $0, media: selectedMedia)) })
        }

        let filters = pickableFilters()
        let filterFits = filters.contains { $0.filter.context == selectedFilter.context }
        if requested.contains(.filter) || !filterFits {
            selectedFilter = weightedRandom(filters.map { ($0.filter, $0.weight) })
                ?? self.filters(for: selectedMedia)[0]
        }

        let after = currentPicks
        return Column.allCases.filter { requested.contains($0) || before[$0.rawValue] != after[$0.rawValue] }
    }

    /// At rest Go opens the pick (disabled without one) and Shuffle works while there's a month.
    private func updateButtonsForRest() {
        actionButton.isEnabled = selectedMonth != nil
        shuffleButton.isEnabled = selectedMonth != nil
        updateActionButtonTitle()
        updateWheelAccessibilityValues()
    }

    /// A blue pill (board C4b: the column titles are blue chips). The
    /// title is white set as an attribute, since the configuration's foreground washes out on the
    /// glass (the `SimilarPhotosHelpSheet` pattern).
    private func updateActionButtonTitle() {
        let isCompact = (metrics?.goHeight ?? GeneralConstants.ButtonSize.large) < GeneralConstants.ButtonSize.large
        let ink: UIColor = .white
        let background = UIColor.systemBlue.resolvedColor(with: traitCollection)

        let titleText: String
        var symbol: UIImage?
        // While the wheel spins, Go keeps the last pick's title (dimmed) instead of giving the new one away
        if selectedMonth != nil {
            titleText = Strings.goToButton(media: selectedMedia.title, monthTitle: formatMonthTitle(from: selectedMonth?.key))
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: isCompact ? 14 : 15, weight: .bold)
            symbol = UIImage(systemName: selectedFilter.systemImageName, withConfiguration: symbolConfig)?
                .withTintColor(ink, renderingMode: .alwaysOriginal)
        } else {
            titleText = Strings.noMonthsAvailable
        }
        let title = NSAttributedString(string: titleText, attributes: [
            .font: UIFont.systemFont(ofSize: isCompact ? 16 : 17, weight: .bold),
            .foregroundColor: ink
        ])

        actionButton.configure(
            attributedTitle: title,
            image: symbol,
            style: .prominent,
            backgroundColor: background,
            foregroundColor: ink,
            contentInsets: Layout.buttonInsets
        )

        if var config = actionButton.configuration {
            config.imagePlacement = .trailing
            actionButton.configuration = config
        }
        applySingleLineTitle()
    }

    private func applySingleLineTitle() {
        guard var config = actionButton.configuration else { return }
        config.titleLineBreakMode = .byTruncatingTail
        actionButton.configuration = config
        actionButton.titleLabel?.numberOfLines = 1
    }

    private func formatMonthTitle(from key: String?) -> String {
        guard let key = key else { return Strings.noMonth }
        return DateFormatterManager.shared.shortMonth(fromMonthKey: key)
    }

    // MARK: - Actions

    @objc private func handleGoTap() {
        guard let month = selectedMonth else { return }
        onSelect?(selectedMedia.mediaType, month.key, selectedFilter.context)
    }

    @objc private func handleShuffleTap() {
        spin(Set(Column.allCases))
    }

    // MARK: - Wheel

    private enum Spin {
        /// When each column starts turning after the one before: Media, then Month, then Filter
        static let stagger: TimeInterval = 0.3
        /// About how long the system's animated row change takes
        static let settle: TimeInterval = 0.6
        /// Values each column passes before its pick
        static let fillerCounts = [8, 10, 12]
        /// Values kept above and added below the pick, so the wheel never shows an empty row
        static let context = 3
    }

    /// The blue flash on the pick when a spin lands (board C4b)
    private enum Flash {
        static let fadeIn: TimeInterval = 0.35
        static let hold: TimeInterval = 0.25
        static let fadeOut: TimeInterval = 0.9
    }

    private var columnLabels: [ColumnTitleView] { [mediaLabel, monthLabel, filterLabel] }

    /// The wheel's columns follow the labels' weighted widths.
    private func updateWheelColumnWidths() {
        let widths = columnLabels.map(\.bounds.width)
        guard widths.allSatisfy({ $0 > 0 }), widths != appliedColumnWidths else { return }
        appliedColumnWidths = widths
        pickerView.reloadAllComponents()
    }

    /// Moves each column's label over its wheel column. The system wheel adds its own gaps
    /// between and around the columns, so where a column ends up is read from its rows.
    private func alignColumnLabelsToWheel() {
        for (component, label) in columnLabels.enumerated() {
            let row = pickerView.selectedRow(inComponent: component)
            guard row >= 0, let rowView = pickerView.view(forRow: row, forComponent: component),
                  rowView.window != nil, rowView.bounds.width > 0 else { continue }
            let wheelCenter = rowView.convert(CGPoint(x: rowView.bounds.midX, y: 0), to: columnLabelsRow).x
            let offset = (wheelCenter - label.center.x).rounded()
            if label.transform.tx != offset {
                label.transform = CGAffineTransform(translationX: offset, y: 0)
            }
        }
    }

    /// The values each column turns through: media, unfinished months, and the filters that can
    /// come up in the month (so the strip doesn't flash one that can't be picked).
    private func wheelPools() -> [[String]] {
        let mediaPool = MediaOption.allCases.map(\.title)
        var monthPool = availableMonths(for: selectedMedia).map(\.title)
        if monthPool.count < 2 {
            monthPool = (availableMonths(for: .photos) + availableMonths(for: .videos)).map(\.title)
        }
        if monthPool.isEmpty { monthPool = [Strings.noMonth] }
        var filterPool = pickableFilters().map(\.filter.title)
        if filterPool.count < 2 { filterPool = filters(for: selectedMedia).map(\.title) }
        return [mediaPool, monthPool, filterPool]
    }

    private var currentPicks: [String] {
        [selectedMedia.title, selectedMonth?.title ?? Strings.noMonth, selectedFilter.title]
    }

    /// `count` random values of the pool, no value twice in a row.
    private func fillers(count: Int, from pool: [String], after first: String) -> [String] {
        guard pool.count > 1 else { return Array(repeating: pool.first ?? " ", count: count) }
        var result: [String] = []
        var previous = first
        for _ in 0..<count {
            let value = pool.filter { $0 != previous }.randomElement() ?? pool[0]
            result.append(value)
            previous = value
        }
        return result
    }

    /// Shows the pick at rest in each column, without turning the wheel.
    private func showSelection() {
        let pools = wheelPools()
        for component in 0..<wheelRows.count {
            let pick = currentPicks[component]
            let above = fillers(count: Spin.context, from: pools[component], after: pick)
            let below = fillers(count: Spin.context, from: pools[component], after: pick)
            wheelRows[component] = above + [pick] + below
            pickerView.reloadComponent(component)
            pickerView.selectRow(Spin.context, inComponent: component, animated: false)
        }
    }

    /// Turns one column from what it shows, through fillers, to `pick`.
    private func turn(component: Int, to pick: String, pool: [String], animated: Bool) {
        let rows = wheelRows[component]
        let current = min(pickerView.selectedRow(inComponent: component), rows.count - 1)
        // Keep the rows on screen, so the reload doesn't change what the wheel shows
        let head = Array(rows[max(0, current - Spin.context)...current])
        let visibleBelow = Array(rows[(current + 1)..<min(rows.count, current + 1 + Spin.context)])
        let passing = visibleBelow + fillers(count: Spin.fillerCounts[component], from: pool, after: visibleBelow.last ?? head.last ?? pick)
        let below = fillers(count: Spin.context, from: pool, after: pick)
        wheelRows[component] = head + passing + [pick] + below

        pickerView.reloadComponent(component)
        pickerView.selectRow(head.count - 1, inComponent: component, animated: false)
        pickerView.selectRow(head.count + passing.count, inComponent: component, animated: animated)
    }

    /// One roll of `columns`: the pick is made first, then the columns that roll (and any later
    /// column whose pick no longer fits) turn to it one after another, left to right, each with a
    /// selection haptic. The other columns stay still. Reduce Motion: no turning.
    private func spin(_ columns: Set<Column>) {
        guard !isSpinning, !columns.isEmpty else { return }
        resetPickFlash()
        pendingSpinSteps.forEach { $0.cancel() }
        pendingSpinSteps.removeAll()
        actionButton.isEnabled = false
        shuffleButton.isEnabled = false
        updateActionButtonTitle()

        guard hasLoadedMonths else {
            isSpinPending = true
            return
        }

        isSpinning = true
        let turning = roll(columns)
        let picks = currentPicks
        let pools = wheelPools()
        let animated = !UIAccessibility.isReduceMotionEnabled

        HapticFeedbackManager.shared.prepareAll()
        for (order, column) in turning.enumerated() {
            let component = column.rawValue
            let delay = animated ? Spin.stagger * Double(order) : 0
            schedule(after: delay) { [weak self] in
                self?.turn(component: component, to: picks[component], pool: pools[component], animated: animated)
            }
            guard animated else { continue }
            schedule(after: delay + Spin.settle) {
                HapticFeedbackManager.shared.selection()
            }
        }
        let end = animated ? Spin.stagger * Double(max(0, turning.count - 1)) + Spin.settle : 0
        schedule(after: end) { [weak self] in
            self?.finishSpin()
        }
    }

    /// Runs `work` after `delay` as a stored step, so it can be cancelled
    private func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        let item = DispatchWorkItem(block: work)
        pendingSpinSteps.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Stops a spin or a flash in its tracks (the sheet is going away). A spin cut short rests on
    /// its pick, so the sheet works again if the dismissal is cancelled.
    private func cancelSpinSteps() {
        pendingSpinSteps.forEach { $0.cancel() }
        pendingSpinSteps.removeAll()
        resetPickFlash()
        guard isSpinning else { return }
        isSpinning = false
        showSelection()
        updateButtonsForRest()
    }

    private func finishSpin() {
        isSpinning = false
        updateButtonsForRest()
        announceSelection()
        flashPick()
    }

    /// The selected rows' views, one per column
    private var pickRowViews: [WheelRowView] {
        (0..<wheelRows.count).compactMap { component in
            let row = pickerView.selectedRow(inComponent: component)
            guard row >= 0 else { return nil }
            return pickerView.view(forRow: row, forComponent: component) as? WheelRowView
        }
    }

    /// The band and the three picks turn blue together and fade back, once, with a success
    /// haptic. Reduce Motion: no flash.
    private func flashPick() {
        guard !UIAccessibility.isReduceMotionEnabled, selectedMonth != nil else { return }
        flashGeneration += 1
        let generation = flashGeneration
        let rows = pickRowViews
        HapticFeedbackManager.shared.success()

        UIView.animate(withDuration: Flash.fadeIn, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
            self.pickFlashView.alpha = 1
        }
        rows.forEach { $0.setFlashed(true, duration: Flash.fadeIn) }

        schedule(after: Flash.fadeIn + Flash.hold) { [weak self] in
            guard let self, self.flashGeneration == generation else { return }
            UIView.animate(withDuration: Flash.fadeOut, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                self.pickFlashView.alpha = 0
            }
            rows.forEach { $0.setFlashed(false, duration: Flash.fadeOut) }
        }
    }

    /// Ends a flash at once (a new spin starts)
    private func resetPickFlash() {
        flashGeneration += 1
        pickFlashView.layer.removeAllAnimations()
        pickFlashView.alpha = 0
        pickRowViews.forEach { $0.setFlashed(false, duration: 0) }
    }

    private func announceSelection() {
        UIAccessibility.post(notification: .announcement, argument: currentPicks.joined(separator: ", "))
    }
}

// MARK: - Wheel Interaction

extension LuckyPickerSheetViewController: UIGestureRecognizerDelegate {
    private enum Interaction {
        /// A swipe rolls its column once it travels this far, or moves this fast
        static let rollDistance: CGFloat = 30
        static let rollVelocity: CGFloat = 300
    }

    private var columnTitles: [String] { [Strings.media, Strings.month, Strings.filter] }

    fileprivate func setupWheelInteraction() {
        wheelPanGesture.delegate = self
        wheelTouchView.addGestureRecognizer(wheelPanGesture)
        wheelTouchView.addGestureRecognizer(wheelTapGesture)

        // The columns stand in for the system wheel, which only shows the pick
        pickerView.accessibilityElementsHidden = true
        wheelColumnElements = Column.allCases.map { column in
            let element = WheelColumnElement(accessibilityContainer: wheelTouchView)
            element.accessibilityTraits = .adjustable
            element.accessibilityHint = Strings.columnHint
            element.onRoll = { [weak self] in self?.rollFromUser(column) }
            element.onActivate = { [weak self] in self?.rollFromUser(column) }
            return element
        }
        wheelTouchView.accessibilityElements = wheelColumnElements
        updateWheelAccessibilityValues()
    }

    /// The column under `x`, by the column labels the wheel's columns follow.
    private func column(at x: CGFloat) -> Column? {
        let centers = columnLabels.map { $0.convert($0.bounds, to: wheelTouchView).midX }
        guard let nearest = centers.indices.min(by: { abs(centers[$0] - x) < abs(centers[$1] - x) }) else { return nil }
        return Column(rawValue: nearest)
    }

    private var acceptsWheelInput: Bool { hasLoadedMonths && !isSpinning && selectedMonth != nil }

    /// A tap or a swipe rolls the column under it.
    private func rollFromUser(_ column: Column) {
        guard acceptsWheelInput else { return }
        spin([column])
    }

    @objc fileprivate func handleWheelPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            panStartColumn = column(at: gesture.location(in: wheelTouchView).x)
        case .ended:
            let travel = abs(gesture.translation(in: wheelTouchView).y)
            let speed = abs(gesture.velocity(in: wheelTouchView).y)
            if let column = panStartColumn, travel >= Interaction.rollDistance || speed >= Interaction.rollVelocity {
                rollFromUser(column)
            }
            panStartColumn = nil
        case .cancelled, .failed:
            panStartColumn = nil
        default:
            break
        }
    }

    @objc fileprivate func handleWheelTap(_ gesture: UITapGestureRecognizer) {
        guard let column = column(at: gesture.location(in: wheelTouchView).x) else { return }
        rollFromUser(column)
    }

    /// Only vertical swipes belong to the wheel.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === wheelPanGesture else { return true }
        let velocity = wheelPanGesture.velocity(in: wheelTouchView)
        return abs(velocity.y) > abs(velocity.x)
    }

    /// The sheet's own drag waits for a swipe on the wheel to fail, so rolling doesn't move the sheet.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === wheelPanGesture else { return false }
        return !(otherGestureRecognizer.view?.isDescendant(of: wheelTouchView) ?? false)
    }

    // MARK: Accessibility

    /// "Month", "March 2025"
    fileprivate func updateWheelAccessibilityValues() {
        let picks = currentPicks
        for (index, element) in wheelColumnElements.enumerated() {
            element.accessibilityLabel = columnTitles[index]
            element.accessibilityValue = picks[index]
        }
    }

    /// Each element covers its column of the wheel, by the column labels' frames.
    fileprivate func updateWheelAccessibilityFrames() {
        let height = wheelTouchView.bounds.height
        for (index, element) in wheelColumnElements.enumerated() where columnLabels.indices.contains(index) {
            let label = columnLabels[index]
            let frame = label.convert(label.bounds, to: wheelTouchView)
            element.accessibilityFrameInContainerSpace = CGRect(x: frame.minX, y: 0, width: frame.width, height: height)
        }
    }
}

/// A wheel column for VoiceOver: swiping up or down, or double-tapping, rolls it.
private final class WheelColumnElement: UIAccessibilityElement {
    var onRoll: (() -> Void)?
    var onActivate: (() -> Void)?

    override func accessibilityIncrement() { onRoll?() }
    override func accessibilityDecrement() { onRoll?() }
    override func accessibilityActivate() -> Bool {
        onActivate?()
        return true
    }
}

// MARK: - UIPickerViewDataSource

extension LuckyPickerSheetViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        wheelRows.count
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        wheelRows[component].count
    }
}

// MARK: - UIPickerViewDelegate

extension LuckyPickerSheetViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        // The wheel adds its own gaps between and around columns; the labels' weights are
        // scaled into what's left, so the last column never runs past the edge. The overhang
        // only widens the band: the columns stay under their labels.
        let available = pickerView.bounds.width - Layout.wheelColumnGaps - 2 * Layout.wheelBandOverhang
        let total = appliedColumnWidths.reduce(0, +)
        guard appliedColumnWidths.indices.contains(component), total > 0, available > 0 else {
            return max(0, available) / CGFloat(wheelRows.count)
        }
        return appliedColumnWidths[component] * available / total
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        Layout.wheelRowHeight
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int,
                    reusing view: UIView?) -> UIView {
        let rowView = (view as? WheelRowView) ?? WheelRowView()
        if view == nil || isSpinning { rowView.setFlashed(false, duration: 0) }
        rowView.text = wheelRows[component][row]
        rowView.baseFont = ThemeManager.Fonts.titleFont(size: metrics?.rowFontSize ?? 17, weight: .semibold)
        rowView.sideInset = (metrics?.isNarrow ?? false) ? Layout.narrowWheelRowInset : Layout.wheelRowInset
        return rowView
    }
}

// MARK: - ColumnTitleView

/// A column's title over the wheel: a pale blue chip with a blue title, centered in the
/// column's weighted width (the view itself is as wide as the column; the chip hugs the title).
private final class ColumnTitleView: UIView {
    private static let chipHeight: CGFloat = 22
    private static let chipPadding: CGFloat = GeneralConstants.EdgePadding.small

    private let chipView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .luckyChipBackground
        view.layer.cornerRadius = ColumnTitleView.chipHeight / 2
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .luckyChipText
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        isAccessibilityElement = false
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(chipView)
        chipView.addSubview(titleLabel)
        setupConstraint()
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            chipView.topAnchor.constraint(equalTo: topAnchor),
            chipView.bottomAnchor.constraint(equalTo: bottomAnchor),
            chipView.centerXAnchor.constraint(equalTo: centerXAnchor),
            chipView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            chipView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            chipView.heightAnchor.constraint(equalToConstant: Self.chipHeight),

            titleLabel.leadingAnchor.constraint(equalTo: chipView.leadingAnchor, constant: Self.chipPadding),
            titleLabel.trailingAnchor.constraint(equalTo: chipView.trailingAnchor, constant: -Self.chipPadding),
            titleLabel.centerYAnchor.constraint(equalTo: chipView.centerYAnchor)
        ])
    }
}

// MARK: - WheelRowView

/// A wheel row: the value centered with a gap on both sides, so a long one never runs into the
/// column's edges. Wraps to two lines between words; a word wider than the row shrinks the font
/// (down to `minimumScale`) so it never breaks mid-word.
private final class WheelRowView: UIView {
    private static let minimumScale: CGFloat = 0.7
    private static let sizeStep: CGFloat = 0.5
    private static let wordSlack: CGFloat = 2

    let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    /// The same value in blue, over `label`, shown while the pick flashes
    private let flashLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .luckyChipText
        label.textAlignment = .center
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.alpha = 0
        label.isAccessibilityElement = false
        return label
    }()

    var text: String? {
        didSet {
            guard text != oldValue else { return }
            label.text = text
            flashLabel.text = text
            setNeedsLayout()
        }
    }

    /// The font at full size; the label may use a smaller size of it
    var baseFont: UIFont = .systemFont(ofSize: 17) {
        didSet {
            guard baseFont != oldValue else { return }
            setNeedsLayout()
        }
    }

    var sideInset: CGFloat = 0 {
        didSet {
            guard sideInset != oldValue else { return }
            leadingConstraint?.constant = sideInset
            trailingConstraint?.constant = -sideInset
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyFittingFont()
    }

    /// Fades the value to its blue copy and back (at once with a zero duration). Two labels with
    /// one layout fade into each other, so nothing ghosts the way a text cross-dissolve does.
    func setFlashed(_ flashed: Bool, duration: TimeInterval) {
        let changes = {
            self.flashLabel.alpha = flashed ? 1 : 0
            self.label.alpha = flashed ? 0 : 1
        }
        guard duration > 0 else {
            label.layer.removeAllAnimations()
            flashLabel.layer.removeAllAnimations()
            changes()
            return
        }
        UIView.animate(withDuration: duration, delay: 0,
                       options: [flashed ? .curveEaseIn : .curveEaseOut, .beginFromCurrentState],
                       animations: changes)
    }

    /// Scales the font so the widest word fits the row's own width.
    private func applyFittingFont() {
        // UILabel breaks a word that only just fits, so each word keeps a little slack
        let available = bounds.width - 2 * sideInset - Self.wordSlack
        guard available > 0 else { return }
        let words = (text ?? "").split(separator: " ").map(String.init)
        let minimumSize = baseFont.pointSize * Self.minimumScale
        var font = baseFont
        while font.pointSize - Self.sizeStep >= minimumSize,
              words.contains(where: { ceil($0.size(withAttributes: [.font: font]).width) > available }) {
            font = baseFont.withSize(font.pointSize - Self.sizeStep)
        }
        if label.font != font {
            label.font = font
            flashLabel.font = font
        }
    }

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(label)
        addSubview(flashLabel)
        let leading = label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sideInset)
        let trailing = label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sideInset)
        leadingConstraint = leading
        trailingConstraint = trailing
        NSLayoutConstraint.activate([
            leading,
            trailing,
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),

            flashLabel.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            flashLabel.trailingAnchor.constraint(equalTo: label.trailingAnchor),
            flashLabel.topAnchor.constraint(equalTo: label.topAnchor),
            flashLabel.bottomAnchor.constraint(equalTo: label.bottomAnchor)
        ])
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct LuckyPickerSheetViewControllerPreview:
        UIViewControllerRepresentable
    {
        func makeUIViewController(context: Context) -> LuckyPickerSheetViewController {
            return LuckyPickerSheetViewController()
        }

        func updateUIViewController(_ uiViewController: LuckyPickerSheetViewController, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview(
        "Lucky Picker Sheet",
        traits: .fixedLayout(width: 375, height: 300)
    ) {
        LuckyPickerSheetViewControllerPreview()
            .ignoresSafeArea()
    }
#endif
