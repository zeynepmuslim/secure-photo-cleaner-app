//
//  OnboardingViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.01.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let title = NSLocalizedString("onboarding.title", comment: "Onboarding welcome title")
    static let subtitle = NSLocalizedString("onboarding.subtitle", comment: "Onboarding subtitle")
    static let gotIt = NSLocalizedString("onboarding.gotIt", comment: "Got it button")
    static let swipeUpTitle = NSLocalizedString("onboarding.swipeUpTitle", comment: "Swipe up instruction title")
    static let swipeUpInfo = NSLocalizedString("onboarding.swipeUpInfo", comment: "Swipe up instruction description")
    static let swipeLeftTitle = NSLocalizedString("onboarding.swipeLeftTitle", comment: "Swipe left instruction title")
    static let swipeLeftInfo = NSLocalizedString("onboarding.swipeLeftInfo", comment: "Swipe left instruction description")
    static let swipeRightTitle = NSLocalizedString("onboarding.swipeRightTitle", comment: "Swipe right instruction title")
    static let swipeRightInfo = NSLocalizedString("onboarding.swipeRightInfo", comment: "Swipe right instruction description")
    static let store = NSLocalizedString("onboarding.store", comment: "Store slice label in the swipe guide")
    static let keep = NSLocalizedString("onboarding.keep", comment: "Keep slice label in the swipe guide")
    static let delete = CommonStrings.delete
}

/// The swipe guide: a header, a pie of the three swipe directions, the three rules and Got It!.
/// One column on every iPhone; on the iPhone Duo's inner display held sideways the pie and the
/// rules sit side by side, and in the table pose the header and pie stay above the fold.
final class OnboardingViewController: UIViewController {

    var onDismiss: (() -> Void)?

    // MARK: - Layout

    private enum SizeSet: Equatable {
        /// SE, the Duo's cover display, the book pose.
        case compact
        /// iPhone 17 through Pro Max.
        case regular
        /// The Duo's inner display upright.
        case large

        var titleSize: CGFloat {
            switch self {
            case .compact: return 26
            case .regular: return 31
            case .large: return 34
            }
        }

        var subtitleSize: CGFloat { self == .compact ? 15 : 17 }
        var ruleMetrics: OnboardingRuleMetrics { self == .compact ? .compact : .regular }
        var ruleSpacing: CGFloat { self == .compact ? 12 : 18 }
        var buttonHeight: CGFloat {
            self == .compact ? GeneralConstants.ButtonSize.mediumLarge : GeneralConstants.ButtonSize.large
        }
        var buttonBottom: CGFloat {
            self == .compact ? GeneralConstants.Spacer.compactSheetButtonBottom : GeneralConstants.Spacer.sheetButtonBottom
        }
    }

    private enum LayoutMode: Equatable {
        case column(SizeSet)
        case sideBySide
        case table

        var sizeSet: SizeSet {
            switch self {
            case .column(let set): return set
            case .sideBySide: return .regular
            case .table: return .compact
            }
        }
    }

    private enum Layout {
        static let contentMaxWidth: CGFloat = 430
        static let titleToSubtitle: CGFloat = 8
        static let minimumGap: CGFloat = 8
        /// Below this safe-area height the compact set is used.
        static let compactHeightLimit: CGFloat = 720
        /// From this safe-area height (regular width) the large set is used.
        static let largeHeightMinimum: CGFloat = 780

        enum Pie {
            static let heightShare: CGFloat = 0.28
            static let minimum: CGFloat = 150
            static let maximum: CGFloat = 270
            static let maximumWidthShare: CGFloat = 0.75
            static let sideBySide: CGFloat = 200
            static let sideBySideWidthShare: CGFloat = 0.4
            static let tableShare: CGFloat = 0.8
            static let tableMinimum: CGFloat = 120
            static let tableMaximum: CGFloat = 220
        }
    }

    // MARK: - Views

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.title
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.subtitle
        label.textColor = .onboardingSecondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
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

    /// Holds `headerStack`; its sides inset only where the camera overlaps (`updateOcclusionClearance`).
    private let headerRow: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let slicesView = OnboardingSlicesView()

    private let deleteRule = OnboardingRuleRowView()
    private let keepRule = OnboardingRuleRowView()
    private let storeRule = OnboardingRuleRowView()

    private let rulesStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let gotItButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// Safe area ± 20pt, capped at `contentMaxWidth` and centered.
    private let columnGuide = UILayoutGuide()
    /// Safe area ± 20pt, uncapped (the sideways sheet's header, row and button).
    private let wideGuide = UILayoutGuide()

    // MARK: - State

    private var didSetupLayout = false
    private var isUpdatingLayout = false
    private var appliedMode: LayoutMode?

    private var columnConstraints: [NSLayoutConstraint] = []
    private var sideBySideConstraints: [NSLayoutConstraint] = []
    private var tableConstraints: [NSLayoutConstraint] = []
    private var buttonHeightConstraint: NSLayoutConstraint?
    private var buttonBottomConstraint: NSLayoutConstraint?
    /// Table pose: the raised half ends `foldGap` above the fold, the base starts `foldGap` below it.
    private var raisedBottomConstraint: NSLayoutConstraint?
    private var baseTopConstraint: NSLayoutConstraint?
    private var headerLeadingConstraint: NSLayoutConstraint?
    private var headerTrailingConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)
        configureSheet()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        presentationController?.delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !isUpdatingLayout else { return }
        isUpdatingLayout = true
        defer { isUpdatingLayout = false }

        if !didSetupLayout {
            didSetupLayout = true
            setupUI()
            setupConstraint()
        }

        // The hinge update can land late: re-check on every pass, switch without animation.
        UIView.performWithoutAnimation {
            let mode = resolveMode()
            if mode != appliedMode {
                apply(mode)
            }
            updateFoldConstants(for: mode)
            updateSlicesDiameter(for: mode)
            view.layoutIfNeeded()
            updateOcclusionClearance()
        }
    }

    // MARK: - Setup

    /// Large on every iOS version and size: the guide lays out its own column, sideways and
    /// table-pose variants inside the full sheet, so it needs no iOS 16 custom detent.
    private func configureSheet() {
        modalPresentationStyle = .pageSheet
        guard let sheet = sheetPresentationController else { return }
        sheet.detents = [.large()]
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }

    private func setupUI() {
        if #available(iOS 26.0, *) {
            view.backgroundColor = .clear
        } else {
            view.backgroundColor = .mainBackground
        }

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)
        headerRow.addSubview(headerStack)

        slicesView.configure(storeTitle: Strings.store, keepTitle: Strings.keep, deleteTitle: Strings.delete)

        deleteRule.configure(
            iconName: "trash", title: Strings.swipeLeftTitle, info: Strings.swipeLeftInfo,
            color: ThemeManager.Colors.statusRed, titleColor: ThemeManager.Colors.statusRed, iconTint: .white)
        keepRule.configure(
            iconName: "checkmark", title: Strings.swipeRightTitle, info: Strings.swipeRightInfo,
            color: ThemeManager.Colors.statusGreen, titleColor: ThemeManager.Colors.statusGreen, iconTint: .white)
        storeRule.configure(
            iconName: "archivebox", title: Strings.swipeUpTitle,
            info: Strings.swipeUpInfo,
            color: ThemeManager.Colors.statusYellow, titleColor: .yellow200, iconTint: .inkOnYellow)
        [deleteRule, keepRule, storeRule].forEach(rulesStack.addArrangedSubview)

        applyButtonStyle()
        gotItButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: OnboardingViewController, _: UITraitCollection) in
                self.applyButtonStyle()
            }
        }

        view.addLayoutGuide(columnGuide)
        view.addLayoutGuide(wideGuide)
        view.addSubview(headerRow)
        view.addSubview(slicesView)
        view.addSubview(rulesStack)
        view.addSubview(gotItButton)
    }

    private func setupConstraint() {
        let safeArea = view.safeAreaLayoutGuide
        let padding = GeneralConstants.EdgePadding.content

        let columnFill = columnGuide.widthAnchor.constraint(equalTo: safeArea.widthAnchor, constant: -2 * padding)
        columnFill.priority = .defaultHigh

        let headerLeading = headerStack.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor)
        let headerTrailing = headerStack.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor)
        headerLeadingConstraint = headerLeading
        headerTrailingConstraint = headerTrailing

        let buttonHeight = gotItButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large)
        let buttonBottom = gotItButton.bottomAnchor.constraint(
            equalTo: safeArea.bottomAnchor, constant: -GeneralConstants.Spacer.sheetButtonBottom)
        buttonHeightConstraint = buttonHeight
        buttonBottomConstraint = buttonBottom

        NSLayoutConstraint.activate([
            columnGuide.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            columnGuide.leadingAnchor.constraint(greaterThanOrEqualTo: safeArea.leadingAnchor, constant: padding),
            columnGuide.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.contentMaxWidth),
            columnFill,
            columnGuide.topAnchor.constraint(equalTo: safeArea.topAnchor),
            columnGuide.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),

            wideGuide.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: padding),
            wideGuide.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -padding),
            wideGuide.topAnchor.constraint(equalTo: safeArea.topAnchor),
            wideGuide.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),

            headerLeading, headerTrailing,
            headerStack.topAnchor.constraint(equalTo: headerRow.topAnchor),
            headerStack.bottomAnchor.constraint(equalTo: headerRow.bottomAnchor),

            buttonHeight, buttonBottom,
        ])

        columnConstraints = makeColumnConstraints()
        sideBySideConstraints = makeSideBySideConstraints()
        tableConstraints = makeTableConstraints()
    }

    /// Header, pie, rules and button in one column; the gaps between them (and above the header) are equal.
    private func makeColumnConstraints() -> [NSLayoutConstraint] {
        let gaps = (0..<4).map { _ in makeGapGuide() }
        return [
            headerRow.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            headerRow.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
            slicesView.centerXAnchor.constraint(equalTo: columnGuide.centerXAnchor),
            rulesStack.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            rulesStack.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
            gotItButton.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            gotItButton.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
        ] + chain([view.safeAreaLayoutGuide.topAnchor, headerRow.topAnchor], gaps[0])
            + chain([headerRow.bottomAnchor, slicesView.topAnchor], gaps[1])
            + chain([slicesView.bottomAnchor, rulesStack.topAnchor], gaps[2])
            + chain([rulesStack.bottomAnchor, gotItButton.topAnchor], gaps[3])
            + equalHeights(gaps)
    }

    /// The header across the top, the pie (leading) and the rules (trailing) side by side and
    /// vertically centered, then the button across the sheet's width.
    private func makeSideBySideConstraints() -> [NSLayoutConstraint] {
        let gaps = (0..<3).map { _ in makeGapGuide() }
        let row = UILayoutGuide()
        view.addLayoutGuide(row)
        let rowHug = row.heightAnchor.constraint(equalToConstant: 0)
        rowHug.priority = .defaultLow

        return [
            headerRow.leadingAnchor.constraint(equalTo: wideGuide.leadingAnchor),
            headerRow.trailingAnchor.constraint(equalTo: wideGuide.trailingAnchor),
            row.leadingAnchor.constraint(equalTo: wideGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: wideGuide.trailingAnchor),
            rowHug,

            slicesView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            slicesView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            slicesView.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor),

            rulesStack.leadingAnchor.constraint(
                equalTo: slicesView.trailingAnchor, constant: GeneralConstants.EdgePadding.content),
            rulesStack.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            rulesStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            rulesStack.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor),

            gotItButton.leadingAnchor.constraint(equalTo: wideGuide.leadingAnchor),
            gotItButton.trailingAnchor.constraint(equalTo: wideGuide.trailingAnchor),
        ] + chain([view.safeAreaLayoutGuide.topAnchor, headerRow.topAnchor], gaps[0])
            + chain([headerRow.bottomAnchor, row.topAnchor], gaps[1])
            + chain([row.bottomAnchor, gotItButton.topAnchor], gaps[2])
            + equalHeights(gaps)
    }

    /// Table pose: the header and the pie spaced evenly above the fold; the rules and the button
    /// spaced evenly below it. Nothing sits on the fold.
    private func makeTableConstraints() -> [NSLayoutConstraint] {
        let raised = UILayoutGuide()
        let base = UILayoutGuide()
        view.addLayoutGuide(raised)
        view.addLayoutGuide(base)
        let raisedGaps = (0..<3).map { _ in makeGapGuide() }
        let baseGaps = (0..<2).map { _ in makeGapGuide() }

        let raisedBottom = raised.bottomAnchor.constraint(equalTo: view.topAnchor)
        let baseTop = base.topAnchor.constraint(equalTo: view.topAnchor)
        raisedBottomConstraint = raisedBottom
        baseTopConstraint = baseTop

        return [
            raised.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            raisedBottom,
            baseTop,
            base.bottomAnchor.constraint(equalTo: gotItButton.topAnchor),

            headerRow.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            headerRow.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
            slicesView.centerXAnchor.constraint(equalTo: columnGuide.centerXAnchor),
            rulesStack.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            rulesStack.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
            gotItButton.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            gotItButton.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
        ] + chain([raised.topAnchor, headerRow.topAnchor], raisedGaps[0])
            + chain([headerRow.bottomAnchor, slicesView.topAnchor], raisedGaps[1])
            + chain([slicesView.bottomAnchor, raised.bottomAnchor], raisedGaps[2])
            + equalHeights(raisedGaps)
            + chain([base.topAnchor, rulesStack.topAnchor], baseGaps[0])
            + chain([rulesStack.bottomAnchor, gotItButton.topAnchor], baseGaps[1])
            + equalHeights(baseGaps)
    }

    private func makeGapGuide() -> UILayoutGuide {
        let guide = UILayoutGuide()
        view.addLayoutGuide(guide)
        return guide
    }

    /// Spans `guide` from the first anchor to the second.
    private func chain(_ anchors: [NSLayoutYAxisAnchor], _ guide: UILayoutGuide) -> [NSLayoutConstraint] {
        [
            guide.topAnchor.constraint(equalTo: anchors[0]),
            guide.bottomAnchor.constraint(equalTo: anchors[1]),
        ]
    }

    /// Every gap as tall as the first, which is at least `minimumGap`.
    private func equalHeights(_ gaps: [UILayoutGuide]) -> [NSLayoutConstraint] {
        guard let first = gaps.first else { return [] }
        return [first.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumGap)]
            + gaps.dropFirst().map { $0.heightAnchor.constraint(equalTo: first.heightAnchor) }
    }

    // MARK: - Layout Modes

    /// Decided from what the view sees on this pass: the fold's pose, the size class and its own bounds.
    private func resolveMode() -> LayoutMode {
        let pose = FoldRegion.pose(for: FoldRegion.activeFold(in: view))
        if pose == .table {
            return .table
        }
        // The window is read on purpose, not the view: the sheet itself is compact width even on the
        // inner display, and held sideways the system centers a nearly square sheet (about 653×661),
        // so neither its own size class nor its bounds show how the device is held. This reads the
        // window's size class and shape, never the screen. The book pose moves the sheet to one half:
        // one column.
        let isRegularWidth = (view.window?.traitCollection ?? traitCollection).horizontalSizeClass == .regular
        let container = view.window?.bounds.size ?? view.bounds.size
        if isRegularWidth && pose != .book && container.width > container.height {
            return .sideBySide
        }
        let height = view.safeAreaLayoutGuide.layoutFrame.height
        if height < Layout.compactHeightLimit {
            return .column(.compact)
        }
        if isRegularWidth && height >= Layout.largeHeightMinimum {
            return .column(.large)
        }
        return .column(.regular)
    }

    private func apply(_ mode: LayoutMode) {
        appliedMode = mode
        NSLayoutConstraint.deactivate(columnConstraints + sideBySideConstraints + tableConstraints)
        switch mode {
        case .column: NSLayoutConstraint.activate(columnConstraints)
        case .sideBySide: NSLayoutConstraint.activate(sideBySideConstraints)
        case .table: NSLayoutConstraint.activate(tableConstraints)
        }

        let set = mode.sizeSet
        titleLabel.font = ThemeManager.Fonts.titleFont(size: set.titleSize, weight: .heavy)
        subtitleLabel.font = .systemFont(ofSize: set.subtitleSize, weight: .regular)
        [deleteRule, keepRule, storeRule].forEach { $0.apply(metrics: set.ruleMetrics) }
        rulesStack.spacing = set.ruleSpacing
        buttonHeightConstraint?.constant = set.buttonHeight
        buttonBottomConstraint?.constant = -set.buttonBottom
    }

    private func updateFoldConstants(for mode: LayoutMode) {
        guard mode == .table, let fold = FoldRegion.activeFold(in: view) else { return }
        let gap = GeneralConstants.Spacer.foldGap
        if raisedBottomConstraint?.constant != fold.minY - gap {
            raisedBottomConstraint?.constant = fold.minY - gap
        }
        if baseTopConstraint?.constant != fold.maxY + gap {
            baseTopConstraint?.constant = fold.maxY + gap
        }
    }

    /// The pie follows the sheet's own size, shrinking further when the column's text needs the room.
    private func updateSlicesDiameter(for mode: LayoutMode) {
        let safe = view.safeAreaLayoutGuide.layoutFrame
        guard safe.width > 0, safe.height > 0 else { return }
        let set = mode.sizeSet
        let wideWidth = safe.width - 2 * GeneralConstants.EdgePadding.content
        let columnWidth = min(wideWidth, Layout.contentMaxWidth)
        let buttonSpace = set.buttonHeight + set.buttonBottom
        let gap = Layout.minimumGap

        var diameter: CGFloat
        switch mode {
        case .column(let sizeSet):
            let header = fittingHeight(of: headerRow, width: columnWidth)
            let rules = fittingHeight(of: rulesStack, width: columnWidth)
            let available = safe.height - header - rules - buttonSpace - 4 * gap
            diameter = sizeSet == .large
                ? Layout.Pie.maximum
                : min(max(safe.height * Layout.Pie.heightShare, Layout.Pie.minimum), Layout.Pie.maximum)
            diameter = min(diameter, columnWidth * Layout.Pie.maximumWidthShare, available)

        case .sideBySide:
            let header = fittingHeight(of: headerRow, width: wideWidth)
            let available = safe.height - header - buttonSpace - 3 * gap
            diameter = min(Layout.Pie.sideBySide, available, wideWidth * Layout.Pie.sideBySideWidthShare)

        case .table:
            guard let fold = FoldRegion.activeFold(in: view) else { return }
            let header = fittingHeight(of: headerRow, width: columnWidth)
            let raisedHeight = fold.minY - GeneralConstants.Spacer.foldGap - safe.minY
            let available = raisedHeight - header - 3 * gap
            diameter = min(
                max(available * Layout.Pie.tableShare, Layout.Pie.tableMinimum),
                Layout.Pie.tableMaximum, available)
        }
        slicesView.setDiameter(max(diameter.rounded(), 0))
    }

    private func fittingHeight(of view: UIView, width: CGFloat) -> CGFloat {
        view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    /// On the Duo's cover display the camera sits at the top trailing corner, beside the header.
    /// Where it overlaps the header row, the header narrows by the same amount on both sides, so it
    /// stays centered.
    private func updateOcclusionClearance() {
        var cameras: [CGRect] = []
        if #available(iOS 27.1, *) {
            cameras = view.reservedRegions(kind: .occlusion).map(\.frame)
        }
        var inset: CGFloat = 0
        if headerRow.window != nil {
            let frame = headerRow.convert(headerRow.bounds, to: view)
            for camera in cameras where camera.intersects(frame) {
                // How far the camera reaches into the row from the edge it sits on.
                let overlap = camera.midX > frame.midX ? frame.maxX - camera.minX : camera.maxX - frame.minX
                inset = max(inset, min(overlap, frame.width / 4))
            }
        }
        guard headerLeadingConstraint?.constant != inset else { return }
        headerLeadingConstraint?.constant = inset
        headerTrailingConstraint?.constant = -inset
        view.layoutIfNeeded()
    }

    /// The app's ink button. The colors are resolved per appearance because the glass doesn't keep
    /// a dynamic title color legible (as MonthFilterCards' Continue pill), and the title is pure
    /// black or white set as an attribute: the sheet's elevated `.systemBackground` and the
    /// configuration's foreground color both came out washed out on the glass.
    private func applyButtonStyle() {
        let ink: UIColor = traitCollection.userInterfaceStyle == .dark ? .black : .white
        let title = NSAttributedString(string: Strings.gotIt, attributes: [
            .font: ThemeManager.Fonts.titleFont(size: 17, weight: .semibold),
            .foregroundColor: ink,
        ])
        gotItButton.configure(
            attributedTitle: title,
            style: .prominent,
            backgroundColor: UIColor.label.resolvedColor(with: traitCollection),
            foregroundColor: ink)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if didSetupLayout, traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyButtonStyle()
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        OnboardingStore.shared.hasCompletedOnboarding = true
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension OnboardingViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        OnboardingStore.shared.hasCompletedOnboarding = true
        onDismiss?()
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    /// Hosts the guide at a fixed size, optionally in regular width (the Duo's inner display).
    @available(iOS 17.0, *)
    private final class OnboardingPreviewHost: UIViewController {
        private let isRegularWidth: Bool
        private let style: UIUserInterfaceStyle

        init(isRegularWidth: Bool = false, style: UIUserInterfaceStyle = .light) {
            self.isRegularWidth = isRegularWidth
            self.style = style
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            let guide = OnboardingViewController()
            guide.overrideUserInterfaceStyle = style
            if isRegularWidth {
                guide.traitOverrides.horizontalSizeClass = .regular
            }
            addChild(guide)
            guide.view.translatesAutoresizingMaskIntoConstraints = false
            guide.view.backgroundColor = .mainBackground
            view.addSubview(guide.view)
            NSLayoutConstraint.activate([
                guide.view.topAnchor.constraint(equalTo: view.topAnchor),
                guide.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                guide.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                guide.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            guide.didMove(toParent: self)
        }
    }

    @available(iOS 17.0, *)
    #Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
        OnboardingPreviewHost()
    }

    @available(iOS 17.0, *)
    #Preview("iPhone 17", traits: .fixedLayout(width: 402, height: 874)) {
        OnboardingPreviewHost()
    }

    @available(iOS 17.0, *)
    #Preview("iPhone 17 Pro Max", traits: .fixedLayout(width: 440, height: 956)) {
        OnboardingPreviewHost()
    }

    @available(iOS 17.0, *)
    #Preview("iPhone 17 Dark", traits: .fixedLayout(width: 402, height: 874)) {
        OnboardingPreviewHost(style: .dark)
    }

    @available(iOS 17.0, *)
    #Preview("Duo cover display", traits: .fixedLayout(width: 466, height: 678)) {
        OnboardingPreviewHost()
    }

    @available(iOS 17.0, *)
    #Preview("Duo sideways sheet", traits: .fixedLayout(width: 630, height: 600)) {
        OnboardingPreviewHost(isRegularWidth: true)
    }
#endif
