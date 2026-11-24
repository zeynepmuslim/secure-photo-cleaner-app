//
//  YearDetailSheet.swift
//  Purgio
//
//  Created by ZeynepMüslim on 25.06.2026.
//

import Photos
import UIKit

// MARK: - Strings
private enum Strings {
    static func monthsCount(_ n: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString("yearDetailSheet.months", comment: "1 month, 5 months"), n)
    }
    static func itemsCount(_ n: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("yearDetailSheet.itemsCount", comment: "1 item, 14 items"), n)
    }
    static func reviewed(_ reviewed: Int, of total: Int) -> String {
        String(format: NSLocalizedString(
            "yearDetailSheet.reviewedAccessibility", comment: "VoiceOver: 21 of 29 reviewed"), reviewed, total)
    }
    static let note = NSLocalizedString("yearDetailSheet.note", comment: "Why a small year is one session")
    static let allCaughtUp = NSLocalizedString(
        "yearDetailSheet.allCaughtUp", comment: "A month whose items are all reviewed")

    /// 28% (en), %28 (tr)
    static func percent(_ value: Int) -> String {
        percentFormatter.string(from: NSNumber(value: Double(value) / 100)) ?? "\(value)%"
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

// MARK: - Metrics

/// The sheet's sizes. `.compact` is for short sheets: iPhone SE, the Duo's cover display, and on the
/// Duo's inner display the sheet below an upright fold or in the book pose's leading half.
private struct YearDetailMetrics: Equatable {
    let yearFontSize: CGFloat
    let percentFontSize: CGFloat
    let noteGap: CGFloat
    let stripGap: CGFloat
    let stripTopPadding: CGFloat
    let stripBottomPadding: CGFloat
    let capsuleSize: CGSize
    let rowVerticalPadding: CGFloat
    let bottomPadding: CGFloat

    static let regular = YearDetailMetrics(
        yearFontSize: 28, percentFontSize: 22, noteGap: 8, stripGap: 16,
        stripTopPadding: 16, stripBottomPadding: 12, capsuleSize: CGSize(width: 14, height: 72),
        rowVerticalPadding: 11, bottomPadding: 24)

    static let compact = YearDetailMetrics(
        yearFontSize: 24, percentFontSize: 20, noteGap: 6, stripGap: 12,
        stripTopPadding: 12, stripBottomPadding: 10, capsuleSize: CGSize(width: 12, height: 56),
        rowVerticalPadding: 9, bottomPadding: 22)
}

// MARK: - Month Progress

/// A month's numbers as the sheet shows them: the total is the stored total, else the live count.
private struct YearMonthProgress {
    let month: MonthItem
    let total: Int
    let reviewed: Int

    init(_ month: MonthItem) {
        self.month = month
        total = month.originalTotalCount > 0 ? month.originalTotalCount : month.currentPhotoCount
        reviewed = min(max(month.reviewedCount, 0), max(total, 0))
    }

    var hasItems: Bool { total > 0 }
    var isComplete: Bool { total > 0 && reviewed >= total }
    var percent: Int { reviewed.roundedPercent(of: total) }

    /// 1…12 from the "yyyy-MM" key
    var monthNumber: Int? { Int(month.key.suffix(2)) }
}

// MARK: - YearDetailSheet

/// Board "Year detail sheet · Y2 Year strip": a sparse year's months as a twelve-column strip of
/// capsules and a list, in one column as tall as its content. Only the list scrolls.
final class YearDetailSheet: UIViewController {

    private enum Layout {
        static let topPadding: CGFloat = GeneralConstants.EdgePadding.content
        static let maximumColumnWidth = GeneralConstants.SheetColumn.maximumWidth
        static let stripToList: CGFloat = 10
        static let stripSidePadding: CGFloat = 6
        static let stripColumnSpacing: CGFloat = 6
        static let compactWindowHeight: CGFloat = 700
    }

    private let yearItem: YearItem
    private let months: [YearMonthProgress]
    private let yearTotal: Int
    private let yearReviewed: Int

    private var metrics: YearDetailMetrics = .regular
    private var hidesNote = false
    private var appliedLayoutKey: LayoutKey?
    private var fittedHeight: CGFloat = 0
    /// The height the detent last resolved to
    private var resolvedHeight: CGFloat = 0

    /// A row of the column whose sides inset only where the camera overlaps it (`updateOcclusionClearance`)
    private struct OcclusionRow {
        let row: UIView
        let leading: NSLayoutConstraint
        let trailing: NSLayoutConstraint
    }
    private var occlusionRows: [OcclusionRow] = []
    /// The sheet's frame in its window when the occlusion insets were found; they only grow while it holds.
    private var occlusionFrame: CGRect = .null

    /// The fixed rows, each in a container so its sides can inset on their own
    private let headerContainer = UIView()
    private let noteContainer = UIView()
    private let stripContainer = UIView()

    private struct LayoutKey: Equatable {
        let isCompact: Bool
        let hidesNote: Bool
        let capsWidth: Bool
    }

    // MARK: Views

    private let columnView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Header, note and strip: they stay put above the list
    private let fixedStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let headerRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .bottom
        stack.spacing = 12
        stack.isAccessibilityElement = true
        stack.accessibilityTraits = .header
        return stack
    }()

    private let yearLabel: UILabel = {
        let label = UILabel()
        label.textColor = .textPrimary
        label.font = ThemeManager.Fonts.titleFont(size: YearDetailMetrics.regular.yearFontSize, weight: .heavy)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let percentLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: YearDetailMetrics.regular.percentFontSize, weight: .heavy)
        label.textColor = .label
        label.textAlignment = .natural
        return label
    }()

    private let fractionLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()

    private let noteLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let stripCard: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.layer.cornerRadius = GeneralConstants.CornerRadius.card
        view.layer.cornerCurve = .continuous
        // Hidden from VoiceOver: the list carries the same facts
        view.accessibilityElementsHidden = true
        return view
    }()

    private let stripStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .bottom
        stack.spacing = Layout.stripColumnSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let listCard: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.layer.cornerRadius = GeneralConstants.CornerRadius.card
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let listStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var stripColumns: [YearStripColumnView] = []
    private var listRows: [YearMonthRowView] = []

    private var stripTopConstraint: NSLayoutConstraint?
    private var stripBottomConstraint: NSLayoutConstraint?
    private var columnBottomConstraint: NSLayoutConstraint?
    private var columnWidthCapConstraint: NSLayoutConstraint?

    // MARK: - Init

    init(yearItem: YearItem) {
        self.yearItem = yearItem
        let months = yearItem.months.map(YearMonthProgress.init).sorted { $0.month.key < $1.month.key }
        self.months = months
        self.yearTotal = months.reduce(0) { $0 + $1.total }
        self.yearReviewed = months.reduce(0) { $0 + $1.reviewed }
        super.init(nibName: nil, bundle: nil)
        configureSheet()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    private func configureSheet() {
        modalPresentationStyle = .pageSheet
        guard let sheet = sheetPresentationController else { return }
        if #available(iOS 16.0, *) {
            sheet.detents = [
                .custom(identifier: .init("yearDetail.content")) { [weak self] context in
                    guard let self else { return nil }
                    // The resolver first runs at `present`, before `viewWillAppear`
                    if self.fittedHeight <= 0 { self.estimateFittedHeight() }
                    self.resolvedHeight = self.fittedHeight
                    guard self.fittedHeight > 0 else { return nil }
                    return min(self.fittedHeight, context.maximumDetentValue)
                },
                .large()
            ]
        } else {
            sheet.detents = [.medium(), .large()]
        }
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        setupUI()
        setupConstraint()
        configureContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        estimateFittedHeight()

        if #unavailable(iOS 16.0), let sheet = sheetPresentationController {
            let window = hostWindow
            let windowHeight = window?.bounds.height ?? view.bounds.height
            let fitsMedium = fittedHeight <= windowHeight / 2 - (window?.safeAreaInsets.bottom ?? 0)
            sheet.detents = fitsMedium ? [.medium()] : [.large()]
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Skipped while the sheet slid in past the camera
        UIView.performWithoutAnimation { updateOcclusionClearance() }
        updateFittedHeight()
        // A change measured during the presentation isn't picked up by the sheet; apply it now.
        guard #available(iOS 16.0, *), abs(resolvedHeight - fittedHeight) > 0.5,
              let sheet = sheetPresentationController else { return }
        sheet.animateChanges { sheet.invalidateDetents() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if updateLayoutVariantIfNeeded() {
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
        UIView.performWithoutAnimation { updateOcclusionClearance() }
        updateFittedHeight()
    }

    // MARK: - Setup

    private func setupUI() {
        let leadingStack = UIStackView(arrangedSubviews: [yearLabel, subtitleLabel])
        leadingStack.axis = .vertical
        leadingStack.spacing = 2
        leadingStack.alignment = .leading

        let trailingStack = UIStackView(arrangedSubviews: [percentLabel, fractionLabel])
        trailingStack.axis = .vertical
        trailingStack.spacing = 0
        trailingStack.alignment = .trailing
        trailingStack.setContentHuggingPriority(.required, for: .horizontal)
        trailingStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        headerRow.addArrangedSubview(leadingStack)
        headerRow.addArrangedSubview(trailingStack)

        stripCard.addSubview(stripStack)

        for (container, row) in [(headerContainer, headerRow), (noteContainer, noteLabel), (stripContainer, stripCard)] as [(UIView, UIView)] {
            row.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(row)
            fixedStack.addArrangedSubview(container)
        }

        listCard.addSubview(listStack)
        scrollView.addSubview(listCard)

        columnView.addSubview(fixedStack)
        columnView.addSubview(scrollView)
        view.addSubview(columnView)
    }

    private func setupConstraint() {
        let safe = view.safeAreaLayoutGuide
        let side = GeneralConstants.EdgePadding.content
        let listSide = GeneralConstants.EdgePadding.medium

        // The sheet covers the tab bar and the side bar, so the column spans its full width;
        // only rows the camera overlaps narrow (`updateOcclusionClearance`).
        let fullWidth = columnView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -2 * side)
        fullWidth.priority = .defaultHigh
        let widthCap = columnView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maximumColumnWidth)
        columnWidthCapConstraint = widthCap

        let columnBottom = columnView.bottomAnchor.constraint(
            lessThanOrEqualTo: safe.bottomAnchor, constant: -metrics.bottomPadding)
        columnBottomConstraint = columnBottom

        // The list is as tall as its rows until the room runs out, then it scrolls
        let listFits = scrollView.frameLayoutGuide.heightAnchor.constraint(
            equalTo: scrollView.contentLayoutGuide.heightAnchor)
        listFits.priority = .defaultHigh

        let stripTop = stripStack.topAnchor.constraint(equalTo: stripCard.topAnchor, constant: metrics.stripTopPadding)
        let stripBottom = stripStack.bottomAnchor.constraint(
            equalTo: stripCard.bottomAnchor, constant: -metrics.stripBottomPadding)
        stripTopConstraint = stripTop
        stripBottomConstraint = stripBottom

        NSLayoutConstraint.activate([
            columnView.topAnchor.constraint(equalTo: safe.topAnchor, constant: Layout.topPadding),
            columnView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: side),
            columnView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -side),
            columnView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fullWidth,
            columnBottom,

            fixedStack.topAnchor.constraint(equalTo: columnView.topAnchor),
            fixedStack.leadingAnchor.constraint(equalTo: columnView.leadingAnchor),
            fixedStack.trailingAnchor.constraint(equalTo: columnView.trailingAnchor),

            stripTop,
            stripBottom,
            stripStack.leadingAnchor.constraint(equalTo: stripCard.leadingAnchor, constant: Layout.stripSidePadding),
            stripStack.trailingAnchor.constraint(equalTo: stripCard.trailingAnchor, constant: -Layout.stripSidePadding),

            scrollView.topAnchor.constraint(equalTo: fixedStack.bottomAnchor, constant: Layout.stripToList),
            scrollView.bottomAnchor.constraint(equalTo: columnView.bottomAnchor),
            listFits,

            listCard.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            listCard.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            listCard.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            listCard.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            listCard.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            listStack.topAnchor.constraint(equalTo: listCard.topAnchor),
            listStack.leadingAnchor.constraint(equalTo: listCard.leadingAnchor, constant: listSide),
            listStack.trailingAnchor.constraint(equalTo: listCard.trailingAnchor, constant: -listSide),
            listStack.bottomAnchor.constraint(equalTo: listCard.bottomAnchor),
        ])

        var rowConstraints: [NSLayoutConstraint] = []
        for (container, row) in [(headerContainer, headerRow), (noteContainer, noteLabel), (stripContainer, stripCard)] as [(UIView, UIView)] {
            rowConstraints += [
                row.topAnchor.constraint(equalTo: container.topAnchor),
                row.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ]
            occlusionRows.append(OcclusionRow(
                row: row,
                leading: row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                trailing: row.trailingAnchor.constraint(equalTo: container.trailingAnchor)))
        }
        occlusionRows.append(OcclusionRow(
            row: scrollView,
            leading: scrollView.leadingAnchor.constraint(equalTo: columnView.leadingAnchor),
            trailing: scrollView.trailingAnchor.constraint(equalTo: columnView.trailingAnchor)))
        rowConstraints += occlusionRows.flatMap { [$0.leading, $0.trailing] }
        NSLayoutConstraint.activate(rowConstraints)
    }

    private func configureContent() {
        yearLabel.text = yearItem.year
        subtitleLabel.text = "\(Strings.monthsCount(months.count)) · \(Strings.itemsCount(yearTotal))"
        percentLabel.text = Strings.percent(yearReviewed.roundedPercent(of: yearTotal))
        fractionLabel.text = "\(yearReviewed) / \(yearTotal)"
        headerRow.accessibilityLabel = [
            yearItem.year,
            Strings.monthsCount(months.count),
            Strings.itemsCount(yearTotal),
            Strings.reviewed(yearReviewed, of: yearTotal)
        ].joined(separator: ", ")
        noteLabel.text = Strings.note

        // The strip: always January to December
        let symbols = DateFormatterManager.shared.shortStandaloneMonthSymbols
        for index in 0..<12 {
            let column = YearStripColumnView()
            let name = index < symbols.count ? symbols[index] : ""
            let progress = months.first { $0.monthNumber == index + 1 && $0.hasItems }
            column.configure(shortName: name, progress: progress)
            stripColumns.append(column)
            stripStack.addArrangedSubview(column)
        }

        // The list: months with items, oldest first
        let listed = months.filter(\.hasItems)
        for (index, progress) in listed.enumerated() {
            let row = YearMonthRowView()
            row.configure(progress: progress, percentText: Strings.percent(progress.percent),
                          itemsText: Strings.itemsCount(progress.total), allCaughtUp: Strings.allCaughtUp)
            listRows.append(row)
            listStack.addArrangedSubview(row)
            if index < listed.count - 1 {
                let hairline = UIView()
                hairline.backgroundColor = .separator
                hairline.translatesAutoresizingMaskIntoConstraints = false
                hairline.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                listStack.addArrangedSubview(hairline)
            }
        }
        listCard.isHidden = listed.isEmpty

        applyMetrics()
    }

    // MARK: - iPhone Duo camera

    /// Rows the camera overlaps (the Duo's cover display) narrow evenly on both sides, staying
    /// centered; the others keep the column's full width. A narrower row can wrap and move the
    /// rows below it, so while the sheet stays where it is an inset only grows: the layout settles.
    /// Skipped while the sheet slides in or out (it passes the camera); `viewDidAppear` runs it again.
    private func updateOcclusionClearance() {
        guard view.window != nil, transitionCoordinator == nil else { return }
        var cameras: [CGRect] = []
        if #available(iOS 27.1, *) {
            cameras = view.reservedRegions(kind: .occlusion).map(\.frame)
        }
        let sheetFrame = view.convert(view.bounds, to: nil)
        let frameChanged = sheetFrame != occlusionFrame
        occlusionFrame = sheetFrame
        let column = columnView.frame
        var changed = false
        for entry in occlusionRows {
            let rowFrame = entry.row.convert(entry.row.bounds, to: view)
            let frame = CGRect(x: column.minX, y: rowFrame.minY, width: column.width, height: rowFrame.height)
            var inset: CGFloat = frameChanged ? 0 : entry.leading.constant
            if !entry.row.isHidden, entry.row.superview?.isHidden != true, frame.width > 0 {
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
        if changed { view.layoutIfNeeded() }
    }

    // MARK: - Size-dependent layout

    /// The sheet has no window of its own yet in `viewWillAppear`; the presenter's is the same one.
    private var hostWindow: UIWindow? {
        view.window ?? presentingViewController?.view.window
    }

    /// The window's width class: the sheet itself can be compact inside a regular window.
    private var usesRegularWidth: Bool {
        (hostWindow?.traitCollection ?? traitCollection).horizontalSizeClass == .regular
    }

    /// Picks compact or regular metrics, whether the note shows and whether the column is capped.
    /// Returns true when anything changed.
    @discardableResult
    private func updateLayoutVariantIfNeeded() -> Bool {
        let isRegular = usesRegularWidth
        let windowHeight = hostWindow?.bounds.height ?? view.bounds.height
        var isCompact = !isRegular && windowHeight <= Layout.compactWindowHeight
        var hideNote = false

        if #available(iOS 27.1, *), let foldHost = presentingViewController?.view {
            if isRegular, let fold = FoldRegion.splittingFold(in: foldHost), fold.width > fold.height {
                // Upright inner display: the sheet sits below the fold
                isCompact = true
                hideNote = true
            } else if FoldRegion.pose(for: FoldRegion.activeFold(in: foldHost)) == .book {
                // Book pose: the sheet floats in the leading half
                isCompact = true
            }
        }

        let key = LayoutKey(isCompact: isCompact, hidesNote: hideNote, capsWidth: isRegular)
        guard key != appliedLayoutKey else { return false }
        appliedLayoutKey = key
        metrics = isCompact ? .compact : .regular
        hidesNote = hideNote
        columnWidthCapConstraint?.isActive = isRegular
        applyMetrics()
        return true
    }

    private func applyMetrics() {
        yearLabel.font = ThemeManager.Fonts.titleFont(size: metrics.yearFontSize, weight: .heavy)
        percentLabel.font = .monospacedDigitSystemFont(ofSize: metrics.percentFontSize, weight: .heavy)

        noteContainer.isHidden = hidesNote
        fixedStack.setCustomSpacing(hidesNote ? metrics.stripGap : metrics.noteGap, after: headerContainer)
        fixedStack.setCustomSpacing(metrics.stripGap, after: noteContainer)

        stripTopConstraint?.constant = metrics.stripTopPadding
        stripBottomConstraint?.constant = -metrics.stripBottomPadding
        columnBottomConstraint?.constant = -metrics.bottomPadding

        stripColumns.forEach { $0.apply(capsuleSize: metrics.capsuleSize) }
        listRows.forEach { $0.apply(verticalPadding: metrics.rowVerticalPadding) }
    }

    /// A first height from the presenter's window, before the sheet has laid out;
    /// `viewDidLayoutSubviews` corrects it with the column's real width.
    private func estimateFittedHeight() {
        loadViewIfNeeded()
        updateLayoutVariantIfNeeded()
        let window = hostWindow
        let windowWidth = window?.bounds.width ?? view.bounds.width
        let horizontalInsets = (window?.safeAreaInsets.left ?? 0) + (window?.safeAreaInsets.right ?? 0)
        var width = windowWidth - horizontalInsets - 2 * GeneralConstants.EdgePadding.content
        if usesRegularWidth { width = min(width, Layout.maximumColumnWidth) }
        fittedHeight = contentHeight(forWidth: width)
    }

    /// The column's height from the sheet's top to the bottom safe area, list included.
    private func contentHeight(forWidth width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let listInset = occlusionRows.first { $0.row === scrollView }?.leading.constant ?? 0
        let listWidth = max(0, width - 2 * listInset)
        let listHeight = listCard.isHidden ? 0 : Layout.stripToList + fittingHeight(of: listCard, width: listWidth)
        return view.safeAreaInsets.top + Layout.topPadding
            + fittingHeight(of: fixedStack, width: width)
            + listHeight
            + metrics.bottomPadding
    }

    private func fittingHeight(of view: UIView, width: CGFloat) -> CGFloat {
        view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height.rounded(.up)
    }

    /// Keeps the custom detent on the content's real height once the column has its width.
    private func updateFittedHeight() {
        let width = columnView.bounds.width
        guard width > 0 else { return }
        let height = contentHeight(forWidth: width)
        guard abs(height - fittedHeight) > 0.5 else { return }
        fittedHeight = height
        guard #available(iOS 16.0, *), let sheet = sheetPresentationController else { return }
        if view.window != nil, !isBeingPresented {
            sheet.animateChanges { sheet.invalidateDetents() }
        } else {
            sheet.invalidateDetents()
        }
    }
}

// MARK: - YearStripColumnView

/// One month of the strip: a capsule (or a dot for a month without items) over the short name and
/// the month's total. Every column has the same height, so the labels line up.
private final class YearStripColumnView: UIView {

    private enum Layout {
        static let dotSize: CGFloat = 6
        static let capsuleToName: CGFloat = 6
        static let fontSize: CGFloat = 11
        static let emptyNameAlpha: CGFloat = 0.6
    }

    private let capsuleSlot: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let capsuleView: ReviewCapsuleView = {
        let view = ReviewCapsuleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let dotView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.layer.cornerRadius = Layout.dotSize / 2
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let nameLabel: UILabel = YearStripColumnView.makeLabel()
    private let countLabel: UILabel = YearStripColumnView.makeLabel()

    private var slotHeightConstraint: NSLayoutConstraint?
    private var capsuleWidthConstraint: NSLayoutConstraint?
    private var capsuleHeightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.font = .systemFont(ofSize: Layout.fontSize, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func setupUI() {
        isAccessibilityElement = false
        countLabel.font = .monospacedDigitSystemFont(ofSize: Layout.fontSize, weight: .regular)

        addSubview(capsuleSlot)
        capsuleSlot.addSubview(capsuleView)
        capsuleSlot.addSubview(dotView)
        addSubview(nameLabel)
        addSubview(countLabel)

        let size = YearDetailMetrics.regular.capsuleSize
        let slotHeight = capsuleSlot.heightAnchor.constraint(equalToConstant: size.height)
        let capsuleWidth = capsuleView.widthAnchor.constraint(equalToConstant: size.width)
        let capsuleHeight = capsuleView.heightAnchor.constraint(equalToConstant: size.height)
        slotHeightConstraint = slotHeight
        capsuleWidthConstraint = capsuleWidth
        capsuleHeightConstraint = capsuleHeight

        NSLayoutConstraint.activate([
            capsuleSlot.topAnchor.constraint(equalTo: topAnchor),
            capsuleSlot.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsuleSlot.trailingAnchor.constraint(equalTo: trailingAnchor),
            slotHeight,

            capsuleView.centerXAnchor.constraint(equalTo: capsuleSlot.centerXAnchor),
            capsuleView.bottomAnchor.constraint(equalTo: capsuleSlot.bottomAnchor),
            capsuleWidth,
            capsuleHeight,

            dotView.centerXAnchor.constraint(equalTo: capsuleSlot.centerXAnchor),
            dotView.bottomAnchor.constraint(equalTo: capsuleSlot.bottomAnchor),
            dotView.widthAnchor.constraint(equalToConstant: Layout.dotSize),
            dotView.heightAnchor.constraint(equalToConstant: Layout.dotSize),

            nameLabel.topAnchor.constraint(equalTo: capsuleSlot.bottomAnchor, constant: Layout.capsuleToName),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            countLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor),
            countLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            countLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func configure(shortName: String, progress: YearMonthProgress?) {
        nameLabel.text = shortName
        if let progress {
            let month = progress.month
            capsuleView.isHidden = false
            dotView.isHidden = true
            capsuleView.configure(
                deleted: month.deletedCount, kept: month.keptCount, stored: month.storedCount,
                total: progress.total, reviewed: progress.reviewed)
            nameLabel.font = .systemFont(ofSize: Layout.fontSize, weight: .bold)
            nameLabel.textColor = .label
            nameLabel.alpha = 1
            countLabel.text = "\(progress.total)"
        } else {
            capsuleView.isHidden = true
            dotView.isHidden = false
            nameLabel.font = .systemFont(ofSize: Layout.fontSize, weight: .regular)
            nameLabel.textColor = .secondaryLabel
            nameLabel.alpha = Layout.emptyNameAlpha
            // A blank line keeps the names level with the other columns
            countLabel.text = " "
        }
    }

    func apply(capsuleSize: CGSize) {
        slotHeightConstraint?.constant = capsuleSize.height
        capsuleWidthConstraint?.constant = capsuleSize.width
        capsuleHeightConstraint?.constant = capsuleSize.height
    }
}

// MARK: - YearMonthRowView

/// One month of the list: title, item count and the percent (or a green check once complete).
private final class YearMonthRowView: UIView {

    private enum Layout {
        static let trailingSlotWidth: CGFloat = 40
        static let spacing: CGFloat = 8
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .textPrimary
        label.numberOfLines = 0
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let trailingSlot: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let percentLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        label.textAlignment = .right
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let checkView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let view = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: config))
        view.tintColor = ThemeManager.Colors.statusGreen
        view.contentMode = .center
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        isAccessibilityElement = true

        addSubview(titleLabel)
        addSubview(countLabel)
        addSubview(trailingSlot)
        trailingSlot.addSubview(percentLabel)
        trailingSlot.addSubview(checkView)

        let padding = YearDetailMetrics.regular.rowVerticalPadding
        let top = titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: padding)
        let bottom = titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
        topConstraint = top
        bottomConstraint = bottom

        NSLayoutConstraint.activate([
            top,
            bottom,
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: Layout.spacing),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            trailingSlot.leadingAnchor.constraint(equalTo: countLabel.trailingAnchor, constant: Layout.spacing),
            trailingSlot.trailingAnchor.constraint(equalTo: trailingAnchor),
            trailingSlot.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailingSlot.widthAnchor.constraint(equalToConstant: Layout.trailingSlotWidth),
            trailingSlot.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),

            percentLabel.topAnchor.constraint(equalTo: trailingSlot.topAnchor),
            percentLabel.bottomAnchor.constraint(equalTo: trailingSlot.bottomAnchor),
            percentLabel.leadingAnchor.constraint(equalTo: trailingSlot.leadingAnchor),
            percentLabel.trailingAnchor.constraint(equalTo: trailingSlot.trailingAnchor),

            checkView.trailingAnchor.constraint(equalTo: trailingSlot.trailingAnchor),
            checkView.centerYAnchor.constraint(equalTo: trailingSlot.centerYAnchor),
        ])
    }

    func configure(progress: YearMonthProgress, percentText: String, itemsText: String, allCaughtUp: String) {
        titleLabel.text = progress.month.title
        countLabel.text = itemsText

        let status: String
        if progress.isComplete {
            percentLabel.isHidden = true
            checkView.isHidden = false
            status = allCaughtUp
        } else {
            percentLabel.isHidden = false
            checkView.isHidden = true
            percentLabel.text = percentText
            percentLabel.textColor = progress.percent > 0 ? .label : .secondaryLabel
            status = percentText
        }
        accessibilityLabel = [progress.month.title, itemsText, status].joined(separator: ", ")
    }

    func apply(verticalPadding: CGFloat) {
        topConstraint?.constant = verticalPadding
        bottomConstraint?.constant = -verticalPadding
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

private func previewMonth(_ month: Int, _ total: Int, reviewed: Int = 0,
                          deleted: Int = 0, kept: Int = 0, stored: Int = 0) -> MonthItem {
    let key = String(format: "2019-%02d", month)
    return MonthItem(
        title: DateFormatterManager.shared.displayMonth(fromMonthKey: key), key: key,
        currentPhotoCount: total, reviewedCount: reviewed, keptCount: kept, deletedCount: deleted,
        storedCount: stored, originalTotalCount: total, mediaType: .image)
}

private func previewYear(_ months: [MonthItem]) -> YearItem {
    YearItem(
        year: "2019", key: "year-2019", months: months,
        currentTotalCount: months.reduce(0) { $0 + $1.currentPhotoCount },
        reviewedCount: 0, deletedCount: 0, keptCount: 0, storedCount: 0, originalTotalCount: 0,
        mediaType: .image)
}

@available(iOS 17.0, *)
#Preview("One month") {
    YearDetailSheet(yearItem: previewYear([previewMonth(8, 14, reviewed: 5, deleted: 2, kept: 3)]))
}

@available(iOS 17.0, *)
#Preview("Five months") {
    YearDetailSheet(yearItem: previewYear([
        previewMonth(1, 5, reviewed: 5, deleted: 2, kept: 2, stored: 1),
        previewMonth(3, 12, reviewed: 6, deleted: 3, kept: 2, stored: 1),
        previewMonth(4, 9),
        previewMonth(7, 8, reviewed: 2, kept: 2),
        previewMonth(11, 12),
    ]))
}

@available(iOS 17.0, *)
#Preview("Nine months") {
    YearDetailSheet(yearItem: previewYear([
        previewMonth(1, 4, reviewed: 4, deleted: 1, kept: 3),
        previewMonth(2, 6, reviewed: 3, deleted: 2, kept: 1),
        previewMonth(3, 5),
        previewMonth(5, 7, reviewed: 7, deleted: 3, kept: 3, stored: 1),
        previewMonth(6, 3),
        previewMonth(8, 6, reviewed: 1, stored: 1),
        previewMonth(9, 4),
        previewMonth(10, 5, reviewed: 2, deleted: 2),
        previewMonth(12, 6),
    ]))
}
#endif
