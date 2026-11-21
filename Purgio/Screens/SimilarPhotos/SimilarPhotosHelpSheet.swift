//
//  SimilarPhotosHelpSheet.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.02.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let title = NSLocalizedString("similarHelp.title", comment: "Help sheet title")
    static let subtitle = NSLocalizedString("similarHelp.subtitle", comment: "Help sheet subtitle")
    static let hintTapLead = NSLocalizedString("similarHelp.hintTapLead", comment: "Hint, bold start: tap a photo")
    static let hintTapText = NSLocalizedString("similarHelp.hintTapText", comment: "Hint, rest: switches keep and delete")
    static let hintStoreLead = NSLocalizedString("similarHelp.hintStoreLead", comment: "Hint, bold start: Store, then photos")
    static let hintStoreText = NSLocalizedString("similarHelp.hintStoreText", comment: "Hint, rest: saves them to an album")
    static let hintConfirmLead = NSLocalizedString("similarHelp.hintConfirmLead", comment: "Hint, bold start: Confirm")
    static let hintConfirmText = NSLocalizedString("similarHelp.hintConfirmText", comment: "Hint, rest: sends each photo where it belongs")
    static let gotIt = NSLocalizedString("similarHelp.gotIt", comment: "Got it button")
}

/// The Similar Photos help sheet (board "Similar photos · help sheet · keep, bin and store
/// targets"): one page with a working sample set, three hints, and a Confirm that flies each
/// sample photo to the Photos pile, the bin or the store box (`+Confirm.swift`). The sample
/// is local to the sheet: nothing reaches PhotoKit or the stores.
final class SimilarPhotosHelpSheet: UIViewController {

    private enum Layout {
        static let sidePadding: CGFloat = 24
        static let maximumContentWidth: CGFloat = 420
        static let titleToSubtitle: CGFloat = 6
        static let hintSpacing: CGFloat = 12
        static let buttonBottom = GeneralConstants.Spacer.compactSheetButtonBottom
        static let regularThumbnail: CGFloat = 72
        static let compactThumbnail: CGFloat = 60
    }

    /// The column's vertical gaps: regular, or tightened when the sheet is short on height
    private struct Spacing {
        let top: CGFloat
        let headerToCard: CGFloat
        let cardToHints: CGFloat
        let hintsToButton: CGFloat

        static let regular = Spacing(top: 30, headerToCard: 24, cardToHints: 22, hintsToButton: 24)
        static let compact = Spacing(top: 20, headerToCard: 14, cardToHints: 14, hintsToButton: 12)
    }

    // MARK: - Views

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.title
        label.font = ThemeManager.Fonts.titleFont(size: 26, weight: .heavy)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.accessibilityTraits = .header
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.subtitle
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.titleToSubtitle
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    let sampleCard: SimilarHelpSampleCardView = {
        let view = SimilarHelpSampleCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// The hints at rest and the targets after Confirm share this area
    private let hintsAreaView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let hintsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.hintSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// The hints in the order the sample is used: tap, store, confirm
    private let hintRows: [SimilarHelpHintRowView] = [
        SimilarHelpHintRowView(
            systemImage: "arrow.up.and.down", color: ThemeManager.Colors.statusGreen,
            bottomColor: ThemeManager.Colors.statusRed, glyphColor: .white,
            lead: Strings.hintTapLead, text: Strings.hintTapText),
        SimilarHelpHintRowView(
            systemImage: "archivebox.fill", color: ThemeManager.Colors.statusYellow, glyphColor: .inkOnYellow,
            lead: Strings.hintStoreLead, text: Strings.hintStoreText),
        SimilarHelpHintRowView(
            systemImage: "arrow.triangle.branch", color: .systemGray5, glyphColor: .label,
            lead: Strings.hintConfirmLead, text: Strings.hintConfirmText)
    ]

    let targetsView: SimilarHelpTargetsView = {
        let view = SimilarHelpTargetsView()
        view.alpha = 0
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Photos on their way to the bin or the box: over the card, under the targets, so they
    /// disappear behind a lid and a body
    let lowFlightLayer = SimilarPhotosHelpSheet.makeFlightLayer()
    /// The kept photos, which land on top of the pile
    let highFlightLayer = SimilarPhotosHelpSheet.makeFlightLayer()

    private lazy var gotItButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.addTarget(self, action: #selector(handleGotIt), for: .touchUpInside)
        return button
    }()

    /// The content column: the sheet's full width minus 24pt a side, centered, at most 420pt wide.
    /// The sheet covers the tab bar and the side bar, so the camera strip's safe area doesn't apply.
    private let contentGuide = UILayoutGuide()

    /// A row of the column whose sides inset only where the camera overlaps it (`updateOcclusionClearance`)
    private struct OcclusionRow {
        let row: UIView
        let leading: NSLayoutConstraint
        let trailing: NSLayoutConstraint
    }
    private var occlusionRows: [OcclusionRow] = []
    /// The sheet's frame in its window when the occlusion insets were found; they only grow while it holds.
    private var occlusionFrame: CGRect = .null

    // MARK: - State

    private var didConfigureForSize = false
    private var isUpdatingLayout = false
    private var isCompact = false
    private var spacing = Spacing.regular
    private var fittedHeight: CGFloat = 0
    private var usesMaximumDetent = false
    private var appliedTableFold: CGRect?

    private var headerTopConstraint: NSLayoutConstraint?
    private var headerToCardConstraint: NSLayoutConstraint?
    private var cardToHintsConstraint: NSLayoutConstraint?
    private var hintsToButtonConstraint: NSLayoutConstraint?

    /// The Confirm animation's timed steps, cancelled when the sheet closes
    var pendingWorkItems: [DispatchWorkItem] = []
    var isConfirming = false
    /// The hints the user has done (indices into `hintRows`)
    private var completedHints: Set<Int> = []

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
        configureSheet()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraint()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
                (self: SimilarPhotosHelpSheet, _: UITraitCollection) in
                self.applyGotItStyle()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !didConfigureForSize else { return }
        didConfigureForSize = true
        configureDetents()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sampleCard.startIdleLoop()
        // The camera clearance waits for the sheet to settle
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !isUpdatingLayout else { return }
        isUpdatingLayout = true
        defer { isUpdatingLayout = false }

        // The hinge update can land late or mid-transition: re-check on every pass, switch without animation.
        UIView.performWithoutAnimation {
            updateCompactLayout()
            updateTableFoldLayout()
            updateOcclusionClearance()
        }
        updateFittedHeight()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sampleCard.pauseIdleLoop()
        cancelPendingWork()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyGotItStyle()
        }
    }

    // MARK: - Setup

    private func configureSheet() {
        modalPresentationStyle = .pageSheet
        guard let sheet = sheetPresentationController else { return }
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }

    private static func makeFlightLayer() -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    private func setupUI() {
        // A solid grouped background on every iOS, so the white sample card stands out and the
        // targets sit straight on the sheet
        view.backgroundColor = .mainBackground
        view.addLayoutGuide(contentGuide)

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)

        hintRows.forEach { hintsStack.addArrangedSubview($0) }
        updateHintStatuses(animated: false)

        view.addSubview(headerStack)
        view.addSubview(sampleCard)
        view.addSubview(hintsAreaView)
        hintsAreaView.addSubview(hintsStack)
        view.addSubview(lowFlightLayer)
        view.addSubview(targetsView)
        view.addSubview(highFlightLayer)
        view.addSubview(gotItButton)

        sampleCard.onStep = { [weak self] step in self?.handleSampleStep(step) }
        sampleCard.onConfirm = { [weak self] in self?.runConfirmAnimation() }
        applyGotItStyle()
    }

    private func setupConstraint() {
        let safeArea = view.safeAreaLayoutGuide

        // Horizontally the sheet spans its full width: it covers the tab bar and the side bar,
        // so the camera strip's safe area doesn't apply. As wide as the sheet allows up to
        // 420pt, centered in it; only rows the camera itself overlaps narrow, on both sides.
        let fillWidth = contentGuide.widthAnchor.constraint(
            equalTo: view.widthAnchor, constant: -2 * Layout.sidePadding)
        fillWidth.priority = .defaultHigh

        let headerTop = headerStack.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: spacing.top)
        let headerToCard = sampleCard.topAnchor.constraint(
            equalTo: headerStack.bottomAnchor, constant: spacing.headerToCard)
        let cardToHints = hintsAreaView.topAnchor.constraint(
            equalTo: sampleCard.bottomAnchor, constant: spacing.cardToHints)
        let hintsToButton = gotItButton.topAnchor.constraint(
            greaterThanOrEqualTo: hintsAreaView.bottomAnchor, constant: spacing.hintsToButton)
        headerTopConstraint = headerTop
        headerToCardConstraint = headerToCard
        cardToHintsConstraint = cardToHints
        hintsToButtonConstraint = hintsToButton

        var constraints = [
            contentGuide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentGuide.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor, constant: Layout.sidePadding),
            contentGuide.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maximumContentWidth),
            fillWidth,
            contentGuide.topAnchor.constraint(equalTo: safeArea.topAnchor),
            contentGuide.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),

            headerTop,
            headerToCard,
            cardToHints,
            hintsToButton,

            hintsStack.topAnchor.constraint(equalTo: hintsAreaView.topAnchor),
            hintsStack.leadingAnchor.constraint(equalTo: hintsAreaView.leadingAnchor),
            hintsStack.trailingAnchor.constraint(equalTo: hintsAreaView.trailingAnchor),
            hintsStack.bottomAnchor.constraint(equalTo: hintsAreaView.bottomAnchor),

            // The targets take the hints' place, centered in the same area
            targetsView.leadingAnchor.constraint(equalTo: hintsAreaView.leadingAnchor),
            targetsView.trailingAnchor.constraint(equalTo: hintsAreaView.trailingAnchor),
            targetsView.centerYAnchor.constraint(equalTo: hintsAreaView.centerYAnchor),

            gotItButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),
            gotItButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -Layout.buttonBottom)
        ]
        occlusionRows = ([headerStack, sampleCard, hintsAreaView, gotItButton] as [UIView]).map { item in
            OcclusionRow(
                row: item,
                leading: item.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
                trailing: item.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor))
        }
        constraints += occlusionRows.flatMap { [$0.leading, $0.trailing] }
        // Overlays: a flying photo's frame is in the view's own coordinates
        for layer in [lowFlightLayer, highFlightLayer] {
            constraints += [
                layer.topAnchor.constraint(equalTo: view.topAnchor),
                layer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                layer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                layer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }

    /// The ink primary button; the glass doesn't keep a dynamic color, so it's resolved per appearance.
    /// The ink button. In a sheet the sheet's elevated `.systemBackground` and the configuration's
    /// foreground color both come out washed out on the glass (white on white in dark mode), so the
    /// title is pure black or white set as an attribute, as in Onboarding.
    private func applyGotItStyle() {
        let ink: UIColor = traitCollection.userInterfaceStyle == .dark ? .black : .white
        let title = NSAttributedString(string: Strings.gotIt, attributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: ink,
        ])
        gotItButton.configure(
            attributedTitle: title,
            style: .prominent,
            backgroundColor: UIColor.label.resolvedColor(with: traitCollection),
            foregroundColor: ink)
    }

    // MARK: - Sheet size

    /// The sheet has no window of its own yet in `viewWillAppear`; the presenter's is the same one.
    private var hostWindow: UIWindow? {
        view.window ?? presentingViewController?.view.window
    }

    /// iOS 16+: the sheet is as tall as its content (the whole height in the table pose, where
    /// the content splits at the fold). iOS 15 has no custom detent: medium when the content
    /// fits it, else large.
    private func configureDetents() {
        guard let sheet = sheetPresentationController else { return }
        let window = hostWindow
        let windowSize = window?.bounds.size ?? view.bounds.size
        let insets = window?.safeAreaInsets ?? .zero
        let width = min(Layout.maximumContentWidth, windowSize.width - 2 * Layout.sidePadding)
        fittedHeight = contentHeight(forWidth: width)

        if #available(iOS 16.0, *) {
            sheet.detents = [
                .custom(identifier: .init("similarHelp.content")) { [weak self] context in
                    guard let self else { return nil }
                    if self.usesMaximumDetent { return context.maximumDetentValue }
                    return min(self.fittedHeight, context.maximumDetentValue)
                }
            ]
        } else {
            let fitsMedium = fittedHeight <= windowSize.height / 2 - insets.bottom
            sheet.detents = windowSize.height <= 667 || !fitsMedium ? [.large()] : [.medium()]
        }
    }

    /// The column's height from the sheet's top to the bottom safe area, at the current gaps.
    private func contentHeight(forWidth width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        sampleCard.prepareLayout(forWidth: rowWidth(of: sampleCard, column: width))
        return spacing.top + fittingHeight(of: headerStack, width: rowWidth(of: headerStack, column: width))
            + spacing.headerToCard + fittingHeight(of: sampleCard, width: rowWidth(of: sampleCard, column: width))
            + spacing.cardToHints + fittingHeight(of: hintsStack, width: rowWidth(of: hintsAreaView, column: width))
            + spacing.hintsToButton + GeneralConstants.ButtonSize.large + Layout.buttonBottom
    }

    /// A row's width in a column this wide: narrower by its camera clearance. Measuring a row
    /// at any other width than it lays out at (the sample card sizes its photos from its width)
    /// would change it on every pass.
    private func rowWidth(of row: UIView, column width: CGFloat) -> CGFloat {
        let inset = occlusionRows.first { $0.row === row }?.leading.constant ?? 0
        return max(0, width - 2 * inset)
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
        let width = contentGuide.layoutFrame.width
        guard width > 0 else { return }
        let height = contentHeight(forWidth: width)
        let wantsMaximum = hasTableFold
        guard abs(height - fittedHeight) > 0.5 || wantsMaximum != usesMaximumDetent else { return }
        fittedHeight = height
        usesMaximumDetent = wantsMaximum
        guard #available(iOS 16.0, *), let sheet = sheetPresentationController else { return }
        if view.window != nil, !isBeingPresented {
            sheet.animateChanges { sheet.invalidateDetents() }
        } else {
            sheet.invalidateDetents()
        }
    }

    /// A sheet too short for its content (iPhone SE, the Duo's cover display) takes smaller
    /// photos and tighter gaps instead of scrolling. Measured, not guessed from the window's
    /// size, and it happens once.
    private func updateCompactLayout() {
        let width = contentGuide.layoutFrame.width
        guard !isCompact, width > 0, !hasTableFold else { return }
        let available = view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        guard available > 0, contentHeight(forWidth: width) > available + 0.5 else { return }

        isCompact = true
        spacing = .compact
        sampleCard.maximumThumbnailSide = Layout.compactThumbnail
        headerTopConstraint?.constant = spacing.top
        headerToCardConstraint?.constant = spacing.headerToCard
        cardToHintsConstraint?.constant = spacing.cardToHints
        hintsToButtonConstraint?.constant = spacing.hintsToButton
        view.layoutIfNeeded()
    }

    // MARK: - iPhone Duo camera

    /// Rows the camera overlaps (the Duo's cover display) narrow evenly on both sides, staying
    /// centered; the others keep the column's full width. A narrower row can wrap and move the
    /// rows below it, which would take a row out from under the camera and back on the next pass,
    /// so while the sheet stays where it is an inset only grows: the layout settles. Skipped while
    /// the sheet slides in or out (it passes the camera on the way); `viewDidAppear` runs it again.
    private func updateOcclusionClearance() {
        guard view.window != nil, transitionCoordinator == nil else { return }
        var cameras: [CGRect] = []
        if #available(iOS 27.1, *) {
            cameras = view.reservedRegions(kind: .occlusion).map(\.frame)
        }
        let frame = view.convert(view.bounds, to: nil)
        let frameChanged = frame != occlusionFrame
        occlusionFrame = frame
        let column = contentGuide.layoutFrame
        var changed = false
        for entry in occlusionRows {
            let frame = CGRect(x: column.minX, y: entry.row.frame.minY, width: column.width, height: entry.row.frame.height)
            var inset: CGFloat = frameChanged ? 0 : entry.leading.constant
            if !entry.row.isHidden, frame.width > 0 {
                for camera in cameras where camera.intersects(frame) {
                    // How far the camera reaches into the row from the edge it sits on.
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

    // MARK: - iPhone Duo table pose

    /// The device is in the table pose and the fold crosses the sheet.
    private var hasTableFold: Bool {
        guard let fold = FoldRegion.activeFold(in: view) else { return false }
        return FoldRegion.pose(for: fold) == .table
    }

    /// The fold in the table pose, when the header and the sample set fit above it.
    private func currentTableFold() -> CGRect? {
        guard let fold = FoldRegion.activeFold(in: view), FoldRegion.pose(for: fold) == .table else { return nil }
        let contentArea = view.bounds.inset(by: view.safeAreaInsets)
        guard fold.minY > contentArea.minY, fold.maxY < contentArea.maxY else { return nil }
        let roomAbove = fold.minY - GeneralConstants.Spacer.foldGap - contentArea.minY
        guard roomAbove >= topGroupHeight() + Spacing.compact.top else { return nil }
        return fold
    }

    private func topGroupHeight() -> CGFloat {
        let width = contentGuide.layoutFrame.width
        return fittingHeight(of: headerStack, width: rowWidth(of: headerStack, column: width)) + spacing.headerToCard
            + fittingHeight(of: sampleCard, width: rowWidth(of: sampleCard, column: width))
    }

    /// Table pose: the header and the sample set centered above the fold; the hints (or the
    /// targets) and Got it below it. Nothing tappable sits on the fold.
    private func updateTableFoldLayout() {
        let fold = currentTableFold()
        guard fold != appliedTableFold else { return }
        appliedTableFold = fold

        guard let fold else {
            headerTopConstraint?.constant = spacing.top
            cardToHintsConstraint?.constant = spacing.cardToHints
            view.layoutIfNeeded()
            return
        }

        let foldGap = GeneralConstants.Spacer.foldGap
        let safeTop = view.safeAreaInsets.top
        let groupHeight = topGroupHeight()
        let roomAbove = fold.minY - foldGap - safeTop
        let top = max(Spacing.compact.top, ((roomAbove - groupHeight) / 2).rounded())
        let cardBottom = safeTop + top + groupHeight

        headerTopConstraint?.constant = top
        cardToHintsConstraint?.constant = max(spacing.cardToHints, fold.maxY + foldGap - cardBottom)
        view.layoutIfNeeded()
    }

    // MARK: - Hints

    private func handleSampleStep(_ step: SimilarHelpSampleCardView.SampleStep) {
        let index: Int
        switch step {
        case .toggled: index = 0
        case .stored: index = 1
        case .confirmed: index = 2
        }
        guard !completedHints.contains(index) else { return }
        completedHints.insert(index)
        updateHintStatuses(animated: true)
    }

    /// Done hints show a check, the first one not done yet is at full strength, the rest are dimmed.
    private func updateHintStatuses(animated: Bool) {
        let activeIndex = hintRows.indices.first { !completedHints.contains($0) }
        for (index, row) in hintRows.enumerated() {
            let status: SimilarHelpHintRowView.Status =
                completedHints.contains(index) ? .done : (index == activeIndex ? .active : .upcoming)
            row.setStatus(status, animated: animated)
        }
    }

    // MARK: - Actions

    @objc private func handleGotIt() {
        cancelPendingWork()
        dismiss(animated: true)
    }

    func cancelPendingWork() {
        pendingWorkItems.forEach { $0.cancel() }
        pendingWorkItems.removeAll()
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview {
        SimilarPhotosHelpSheet()
    }
#endif
