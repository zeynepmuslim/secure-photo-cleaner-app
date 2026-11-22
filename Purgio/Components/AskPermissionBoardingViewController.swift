//
//  AskPermissionBoardingViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 5.04.2026.
//

import Photos
import UIKit

private enum Strings {
    static let title = NSLocalizedString("askPermission.title", comment: "Ask permission screen title")
    static let subtitle = NSLocalizedString("askPermission.subtitle", comment: "Ask permission screen subtitle")
    static let allowAccess = NSLocalizedString("monthsList.allowPhotoAccess", comment: "Allow photo access button title")
    static let settingsAlertTitle = NSLocalizedString("askPermission.settingsAlertTitle", comment: "Alert title when photo access is denied")
    static let settingsAlertMessage = NSLocalizedString("askPermission.settingsAlertMessage", comment: "Alert message when photo access is denied")
    static let openSettings = NSLocalizedString("askPermission.openSettings", comment: "Open Settings action")
    static let privacyNoAccount = NSLocalizedString("askPermission.privacyNoAccount", comment: "Privacy row: no account or sign-up")
    static let privacyOnDevice = NSLocalizedString("askPermission.privacyOnDevice", comment: "Privacy row: photos analyzed on-device")
    static let privacyNoInternet = NSLocalizedString("askPermission.privacyNoInternet", comment: "Privacy row: no internet connection needed")
    static let cancel = CommonStrings.cancel
}

/// The photo access sheet (board "Photo access sheet · frame, line and lock").
/// `.permissionRequest` is Home's startup sheet while access is `.notDetermined`
/// (Home sets `isModalInPresentation`); `.noAction` is the read-only privacy sheet from
/// Settings' Privacy card, with a close button and no Allow access.
///
/// The sheet covers the tab bar and the side bar, so its column spans the full width with
/// 24pt sides; only rows the camera overlaps narrow (`updateOcclusionClearance`).
/// On the Duo's inner display only the table pose splits it at the fold (`updateFoldSplit`).
final class AskPermissionBoardingViewController: UIViewController {
    enum Status {
        case permissionRequest
        case noAction
    }

    // MARK: - Layout

    private enum Layout {
        /// The column's sides, from the sheet's edges.
        static let sidePadding = GeneralConstants.EdgePadding.sheetColumn
        static let headerSpacing: CGFloat = 8
        static let rowIconSpacing: CGFloat = 12
        /// Between the content and Allow access.
        static let buttonGap: CGFloat = 16
        /// The column's top below the grabber (asking) or the close button (read-only).
        static let topPadding = GeneralConstants.EdgePadding.medium
        static let closeButtonGap: CGFloat = 8
        /// Bottom: above the safe area, or above the bottom edge on a home-button phone.
        static let bottomAboveSafeArea = GeneralConstants.EdgePadding.medium
        static let bottomWithoutSafeArea = GeneralConstants.EdgePadding.content
        /// Upright, between the header and the art on the raised half.
        static let uprightHeaderToArt: CGFloat = 20
        /// The least room left between the stacked parts before the art shrinks.
        static let minimumGap = GeneralConstants.EdgePadding.small
        /// A sheet this short or shorter takes the compact metrics (iPhone SE / 7).
        static let shortSheetHeight: CGFloat = 700
        static let closeButtonSize = GeneralConstants.ButtonSize.medium
    }

    private struct Metrics: Equatable {
        var titleSize: CGFloat
        var subtitleSize: CGFloat
        var rowFontSize: CGFloat
        var capsule: CGSize
        var rowSpacing: CGFloat
        var buttonHeight: CGFloat
        /// The art's preferred size; it shrinks to fit the room.
        var art: CGSize
        /// Extra room above and below the art in the one column.
        var artMargin: CGFloat = 0
    }

    private enum SplitMode {
        case single
        case upright
    }

    private struct OcclusionRow {
        let row: UIView
        let leading: NSLayoutConstraint
        let trailing: NSLayoutConstraint
    }

    private struct PrivacyRowParts {
        let capsule: UIView
        let icon: UIImageView
        let label: UILabel
        let capsuleWidth: NSLayoutConstraint
        let capsuleHeight: NSLayoutConstraint
    }

    // MARK: - State

    private let status: Status

    private var appliedMode: SplitMode?
    /// The view's size at the last split check, to tell a fold change from a rotation.
    private var lastSplitSize: CGSize?
    private var appliedMetrics: Metrics?
    private var isUpdatingLayout = false

    private var privacyRows: [PrivacyRowParts] = []
    private var occlusionRows: [OcclusionRow] = []

    private var singleConstraints: [NSLayoutConstraint] = []
    private var uprightConstraints: [NSLayoutConstraint] = []
    private var columnBottomConstraint: NSLayoutConstraint?
    private var buttonHeightConstraint: NSLayoutConstraint?
    private var artWidthConstraint: NSLayoutConstraint?
    private var artHeightConstraint: NSLayoutConstraint?
    /// The art's holder hugs the art plus its margins.
    private var artHuggingConstraint: NSLayoutConstraint?
    /// The fold gap's edges, as distances from the view's top edge (upright).
    private var uprightGapStartConstraint: NSLayoutConstraint?
    private var uprightGapEndConstraint: NSLayoutConstraint?

    // MARK: - Init

    init(status: Status = .permissionRequest) {
        self.status = status
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Views

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.title
        label.font = ThemeManager.Fonts.titleFont(size: 28, weight: .heavy)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.subtitle
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.headerSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Spans the lane; `headerStack` insets inside it only where the camera overlaps.
    private let headerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let artView: PrivacyShieldArtView = {
        let view = PrivacyShieldArtView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Spans the lane and is as tall as the art, which it centers.
    private let artHolder: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let privacyStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Spans the lane; the leading-aligned rows sit centered in it.
    private let privacyContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let allowButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let closeButton = CloseButton()

    private let columnGuide = UILayoutGuide()
    /// The room the second stack centers in: the base (upright), down to Allow access.
    private let secondRoomGuide = UILayoutGuide()
    private let raisedGuide = UILayoutGuide()

    /// One column: the header, the art and the rows spread evenly above the button.
    private let singleStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// The split's raised half: the header and the art (upright).
    private let firstStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// The split's base: the rows (upright).
    private let secondStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let topSpacer = AskPermissionBoardingViewController.makeEdgeSpacer()
    private let bottomSpacer = AskPermissionBoardingViewController.makeEdgeSpacer()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraint()
        configureSheet()

        if status == .permissionRequest {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: AskPermissionBoardingViewController, _: UITraitCollection) in
                self.applyButtonStyle()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !isUpdatingLayout, view.bounds.width > 0 else { return }
        isUpdatingLayout = true
        defer { isUpdatingLayout = false }

        // Size-dependent choices run here, on every pass: the Duo can fold, unfold or turn under the sheet.
        updateBottomInset()
        updateFoldSplit()
        UIView.performWithoutAnimation {
            updateOcclusionClearance()
            updateHeaderWrapWidth()
        }
        artView.setNeedsLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyButtonStyle()
        }
    }

    // MARK: - Sheet

    /// The large detent only, with the grabber.
    private func configureSheet() {
        guard let sheet = sheetPresentationController else { return }
        sheet.detents = [.large()]
        sheet.prefersGrabberVisible = true
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)
        headerContainer.addSubview(headerStack)

        artHolder.addSubview(artView)

        let privacyItems: [(symbol: String, text: String)] = [
            ("person.crop.circle.badge.xmark", Strings.privacyNoAccount),
            ("cpu", Strings.privacyOnDevice),
            ("wifi.slash", Strings.privacyNoInternet)
        ]
        privacyItems.forEach { item in
            privacyStack.addArrangedSubview(makePrivacyRow(symbol: item.symbol, text: item.text))
        }
        privacyContainer.addSubview(privacyStack)

        [singleStack, firstStack, secondStack].forEach(view.addSubview)
        [columnGuide, secondRoomGuide, raisedGuide].forEach(view.addLayoutGuide)

        switch status {
        case .permissionRequest:
            applyButtonStyle()
            allowButton.addTarget(self, action: #selector(allowTapped), for: .touchUpInside)
            view.addSubview(allowButton)
        case .noAction:
            closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            view.addSubview(closeButton)
        }
    }

    private static func makeEdgeSpacer() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 0).isActive = true
        return view
    }

    /// An ink vertical capsule holding the row's symbol in the opposite color, then the text.
    private func makePrivacyRow(symbol: String, text: String) -> UIView {
        let capsule = UIView()
        // Ink, like Allow access: black in light mode, white in dark.
        capsule.backgroundColor = .label
        capsule.layer.cornerCurve = .continuous
        capsule.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: symbol))
        // The opposite of the capsule: white in light mode, black in dark.
        icon.tintColor = .textPrimaryReverse
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(icon)

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .textSecondary
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        let row = UIStackView(arrangedSubviews: [capsule, label])
        row.axis = .horizontal
        row.spacing = Layout.rowIconSpacing
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        let width = capsule.widthAnchor.constraint(equalToConstant: 22)
        let height = capsule.heightAnchor.constraint(equalToConstant: 36)
        NSLayoutConstraint.activate([
            width, height,
            icon.centerXAnchor.constraint(equalTo: capsule.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            icon.widthAnchor.constraint(lessThanOrEqualTo: capsule.widthAnchor, constant: -4),
        ])
        privacyRows.append(PrivacyRowParts(capsule: capsule, icon: icon, label: label, capsuleWidth: width, capsuleHeight: height))
        return row
    }

    private func setupConstraint() {
        let safeArea = view.safeAreaLayoutGuide

        // Inside the containers: the occlusion clearance narrows the content evenly.
        let headerLeading = headerStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor)
        let headerTrailing = headerStack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor)
        let privacyLeading = privacyStack.leadingAnchor.constraint(greaterThanOrEqualTo: privacyContainer.leadingAnchor)
        let privacyTrailing = privacyStack.trailingAnchor.constraint(lessThanOrEqualTo: privacyContainer.trailingAnchor)
        occlusionRows = [
            OcclusionRow(row: headerContainer, leading: headerLeading, trailing: headerTrailing),
            OcclusionRow(row: privacyContainer, leading: privacyLeading, trailing: privacyTrailing),
        ]

        let artWidth = artView.widthAnchor.constraint(equalToConstant: 354)
        let artHeight = artView.heightAnchor.constraint(equalToConstant: 330)
        let artHugging = artHolder.heightAnchor.constraint(equalTo: artView.heightAnchor)
        artHugging.priority = .defaultHigh
        artHuggingConstraint = artHugging
        artWidthConstraint = artWidth
        artHeightConstraint = artHeight

        // The read-only sheet's column starts under the close button; the asking one under the grabber.
        let columnTop: NSLayoutConstraint
        switch status {
        case .permissionRequest:
            columnTop = columnGuide.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: Layout.topPadding)
        case .noAction:
            columnTop = columnGuide.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: Layout.closeButtonGap)
        }
        let columnBottom = columnGuide.bottomAnchor.constraint(
            equalTo: view.bottomAnchor, constant: -Layout.bottomAboveSafeArea)
        columnBottomConstraint = columnBottom

        // Where the content above the button ends.
        let roomBottom: NSLayoutYAxisAnchor
        let roomGap: CGFloat
        switch status {
        case .permissionRequest:
            roomBottom = allowButton.topAnchor
            roomGap = Layout.buttonGap
        case .noAction:
            roomBottom = columnGuide.bottomAnchor
            roomGap = 0
        }

        var common: [NSLayoutConstraint] = [
            headerLeading, headerTrailing,
            headerStack.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            headerStack.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),

            privacyLeading, privacyTrailing,
            privacyStack.centerXAnchor.constraint(equalTo: privacyContainer.centerXAnchor),
            privacyStack.topAnchor.constraint(equalTo: privacyContainer.topAnchor),
            privacyStack.bottomAnchor.constraint(equalTo: privacyContainer.bottomAnchor),

            artWidth, artHeight,
            artView.centerXAnchor.constraint(equalTo: artHolder.centerXAnchor),
            // The holder hugs the art, unless a stack stretches it (the raised half): then the
            // art stays centered in the room it's given.
            artView.centerYAnchor.constraint(equalTo: artHolder.centerYAnchor),
            artView.topAnchor.constraint(greaterThanOrEqualTo: artHolder.topAnchor),
            artHugging,

            // Full width with 24pt sides: the page sheet covers the tab bar and the side bar.
            columnGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Layout.sidePadding),
            columnGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Layout.sidePadding),
            columnTop,
            columnBottom,

            secondRoomGuide.bottomAnchor.constraint(equalTo: roomBottom, constant: -roomGap),
        ]

        switch status {
        case .permissionRequest:
            let buttonHeight = allowButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large)
            buttonHeightConstraint = buttonHeight
            common += [
                buttonHeight,
                allowButton.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
                allowButton.bottomAnchor.constraint(equalTo: columnGuide.bottomAnchor),
            ]
        case .noAction:
            common += [
                closeButton.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: GeneralConstants.EdgePadding.medium),
                closeButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: GeneralConstants.EdgePadding.medium),
            ]
        }
        NSLayoutConstraint.activate(common)

        // One column.
        singleConstraints = [
            singleStack.topAnchor.constraint(equalTo: columnGuide.topAnchor),
            singleStack.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            singleStack.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
            singleStack.bottomAnchor.constraint(equalTo: roomBottom, constant: -roomGap),
        ]

        // Upright: the header and the art on the raised half; the rows and the button on the base.
        let uprightGapStart = raisedGuide.bottomAnchor.constraint(equalTo: view.topAnchor)
        let uprightGapEnd = secondRoomGuide.topAnchor.constraint(equalTo: view.topAnchor)
        uprightGapStartConstraint = uprightGapStart
        uprightGapEndConstraint = uprightGapEnd
        uprightConstraints = [
            raisedGuide.topAnchor.constraint(equalTo: columnGuide.topAnchor),
            uprightGapStart,
            raisedGuide.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            raisedGuide.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),

            // The header at the raised half's top; the art centered in the room under it.
            firstStack.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            firstStack.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
            firstStack.topAnchor.constraint(equalTo: raisedGuide.topAnchor),
            firstStack.bottomAnchor.constraint(equalTo: raisedGuide.bottomAnchor),

            uprightGapEnd,
            secondStack.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            secondStack.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
            secondStack.centerYAnchor.constraint(equalTo: secondRoomGuide.centerYAnchor),
            secondStack.topAnchor.constraint(greaterThanOrEqualTo: secondRoomGuide.topAnchor),
        ]

        if status == .permissionRequest {
            singleConstraints.append(allowButton.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor))
            uprightConstraints.append(allowButton.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor))
        }

        // Start as one column; the first layout pass picks the real mode.
        appliedMode = .single
        rebuildContent(for: .single)
        NSLayoutConstraint.activate(singleConstraints)
    }

    // MARK: - Layout passes

    /// 16pt above the safe area (34pt on Face ID phones); 20pt above the edge on a home-button phone.
    private func updateBottomInset() {
        let safeBottom = view.safeAreaInsets.bottom
        let inset = safeBottom > 0 ? safeBottom + Layout.bottomAboveSafeArea : Layout.bottomWithoutSafeArea
        if columnBottomConstraint?.constant != -inset {
            columnBottomConstraint?.constant = -inset
        }
    }

    /// The split: only the table pose (a horizontal `activeFold`, regular width) splits at the fold.
    /// Fully open or held sideways the sheet stays one column, stacked top to bottom; the art may
    /// cross the fold line there (it isn't tappable) so it can be as large as the room allows.
    private func currentSplitFold() -> CGRect? {
        guard let fold = FoldRegion.activeFold(in: view),
              fold.width > fold.height,
              traitCollection.horizontalSizeClass == .regular else { return nil }
        return fold
    }

    /// Swaps the constraint sets without animation when the mode changes (folding into or out of
    /// the table pose). The fold's distances follow the hinge on every pass.
    private func updateFoldSplit() {
        let fold = currentSplitFold()
        let mode: SplitMode = fold == nil ? .single : .upright
        // Folding into or out of the table pose keeps the view's size; a rotation or the first
        // layout doesn't, and those switch at once.
        let isFoldChange = mode != appliedMode && lastSplitSize == view.bounds.size && view.window != nil
        lastSplitSize = view.bounds.size
        if isFoldChange {
            crossDissolveFromCurrentContent()
        }
        UIView.performWithoutAnimation {
            if mode != appliedMode {
                switchMode(to: mode)
            }
            applyMetrics(metrics(for: mode))
            let gap = gapEdges(for: fold)
            updateGapConstants(gap)
            updateArtSize(mode: mode, gap: gap)
            view.layoutIfNeeded()
        }
    }

    /// Lays a snapshot of what's on screen over the sheet and fades it out, so the layout under it
    /// cross-dissolves to the new one (the views move between stacks, so they can't animate their frames).
    private func crossDissolveFromCurrentContent() {
        guard let snapshot = view.snapshotView(afterScreenUpdates: false) else { return }
        snapshot.frame = view.bounds
        snapshot.isUserInteractionEnabled = false
        view.addSubview(snapshot)
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            snapshot.alpha = 0
        } completion: { _ in
            snapshot.removeFromSuperview()
        }
    }

    private func switchMode(to mode: SplitMode) {
        NSLayoutConstraint.deactivate(singleConstraints + uprightConstraints)
        rebuildContent(for: mode)
        switch mode {
        case .single: NSLayoutConstraint.activate(singleConstraints)
        case .upright: NSLayoutConstraint.activate(uprightConstraints)
        }
        appliedMode = mode
    }

    /// Moves the same header, art and rows between the single column and the two halves.
    private func rebuildContent(for mode: SplitMode) {
        for stack in [singleStack, firstStack, secondStack] {
            stack.arrangedSubviews.forEach {
                stack.removeArrangedSubview($0)
                $0.removeFromSuperview()
            }
        }
        switch mode {
        case .single:
            [topSpacer, headerContainer, artHolder, privacyContainer, bottomSpacer].forEach(singleStack.addArrangedSubview)
        case .upright:
            firstStack.spacing = Layout.uprightHeaderToArt
            [headerContainer, artHolder].forEach(firstStack.addArrangedSubview)
            secondStack.spacing = 0
            secondStack.addArrangedSubview(privacyContainer)
        }
        singleStack.isHidden = mode != .single
        firstStack.isHidden = mode == .single
        secondStack.isHidden = mode == .single
    }

    private func metrics(for mode: SplitMode) -> Metrics {
        let large = GeneralConstants.ButtonSize.large
        let compact = GeneralConstants.ButtonSize.mediumLarge
        switch mode {
        case .upright:
            return Metrics(titleSize: 30, subtitleSize: 16, rowFontSize: 18, capsule: CGSize(width: 26, height: 44),
                           rowSpacing: 20, buttonHeight: large, art: CGSize(width: 600, height: 600))
        case .single:
            let window = view.window
            if DuoLayout.isDuoDisplay(window), window?.traitCollection.horizontalSizeClass == .compact {
                // The Duo's cover display.
                let artHeight: CGFloat = status == .noAction ? 280 : 230
                return Metrics(titleSize: 23, subtitleSize: 14, rowFontSize: 14, capsule: CGSize(width: 20, height: 32),
                               rowSpacing: 10, buttonHeight: compact, art: CGSize(width: 400, height: artHeight))
            }
            if view.bounds.height <= Layout.shortSheetHeight {
                // iPhone SE / iPhone 7, and the Duo's inner display held sideways.
                return Metrics(titleSize: 23, subtitleSize: 14, rowFontSize: 14, capsule: CGSize(width: 20, height: 32),
                               rowSpacing: 9, buttonHeight: compact, art: CGSize(width: 320, height: 216))
            }
            if traitCollection.horizontalSizeClass == .regular {
                // The Duo's inner display upright and fully open: the art takes all the room it can.
                return Metrics(titleSize: 30, subtitleSize: 16, rowFontSize: 18, capsule: CGSize(width: 26, height: 44),
                               rowSpacing: 16, buttonHeight: large, art: CGSize(width: 640, height: 900), artMargin: 28)
            }
            return Metrics(titleSize: 28, subtitleSize: 15, rowFontSize: 15, capsule: CGSize(width: 22, height: 36),
                           rowSpacing: 12, buttonHeight: large, art: CGSize(width: 354, height: 360))
        }
    }

    private func applyMetrics(_ metrics: Metrics) {
        guard metrics != appliedMetrics else { return }
        appliedMetrics = metrics
        titleLabel.font = ThemeManager.Fonts.titleFont(size: metrics.titleSize, weight: .heavy)
        subtitleLabel.font = .systemFont(ofSize: metrics.subtitleSize, weight: .regular)
        privacyStack.spacing = metrics.rowSpacing
        let iconConfig = UIImage.SymbolConfiguration(pointSize: metrics.capsule.width * 0.6, weight: .semibold)
        for row in privacyRows {
            row.label.font = .systemFont(ofSize: metrics.rowFontSize, weight: .medium)
            row.icon.preferredSymbolConfiguration = iconConfig
            row.capsuleWidth.constant = metrics.capsule.width
            row.capsuleHeight.constant = metrics.capsule.height
            row.capsule.layer.cornerRadius = metrics.capsule.width / 2
        }
        buttonHeightConstraint?.constant = metrics.buttonHeight
        artHuggingConstraint?.constant = 2 * metrics.artMargin
    }

    /// The gap at the fold, as (start, end) from the view's top edge: the whole fold region.
    private func gapEdges(for fold: CGRect?) -> (start: CGFloat, end: CGFloat)? {
        guard let fold = fold else { return nil }
        return (fold.minY, fold.maxY)
    }

    private func updateGapConstants(_ gap: (start: CGFloat, end: CGFloat)?) {
        guard let gap = gap else { return }
        switch appliedMode {
        case .upright:
            uprightGapStartConstraint?.constant = gap.start
            uprightGapEndConstraint?.constant = gap.end
        default:
            break
        }
    }

    /// The art's preferred size, shrunk (never stretched) to the room it has, so nothing scrolls.
    private func updateArtSize(mode: SplitMode, gap: (start: CGFloat, end: CGFloat)?) {
        guard let metrics = appliedMetrics else { return }
        let columnWidth = view.bounds.width - 2 * Layout.sidePadding
        let safeTop = view.safeAreaInsets.top
        let columnTop = status == .noAction
            ? safeTop + GeneralConstants.EdgePadding.medium + Layout.closeButtonSize + Layout.closeButtonGap
            : safeTop + Layout.topPadding
        let columnBottom = view.bounds.height + (columnBottomConstraint?.constant ?? 0)
        let buttonRoom = status == .permissionRequest ? metrics.buttonHeight + Layout.buttonGap : 0
        let occlusionInset = 2 * (occlusionRows.first?.leading.constant ?? 0)

        let available: CGSize
        switch mode {
        case .single:
            let used = headerHeight(width: columnWidth - occlusionInset)
                + fittingHeight(of: privacyStack, width: columnWidth)
                + 4 * Layout.minimumGap + 2 * metrics.artMargin
            available = CGSize(width: columnWidth, height: columnBottom - buttonRoom - columnTop - used)
        case .upright:
            let raisedBottom = gap?.start ?? view.bounds.height / 2
            let header = headerHeight(width: columnWidth - occlusionInset)
            available = CGSize(width: columnWidth,
                               height: raisedBottom - columnTop - header - Layout.uprightHeaderToArt - Layout.minimumGap)
        }
        let scale = max(0, min(1, available.width / metrics.art.width, available.height / metrics.art.height))
        let width = (metrics.art.width * scale).rounded()
        let height = (metrics.art.height * scale).rounded()
        if artWidthConstraint?.constant != width { artWidthConstraint?.constant = width }
        if artHeightConstraint?.constant != height { artHeightConstraint?.constant = height }
    }

    /// The header's height at the width it will have. Its labels wrap at that width first: a wrap
    /// width left from an earlier layout (the cover display's, say) would measure too many lines.
    private func headerHeight(width: CGFloat) -> CGFloat {
        setHeaderWrapWidth(width)
        return fittingHeight(of: headerStack, width: width)
    }

    private func setHeaderWrapWidth(_ width: CGFloat) {
        guard width > 0 else { return }
        for label in [titleLabel, subtitleLabel] where label.preferredMaxLayoutWidth != width {
            label.preferredMaxLayoutWidth = width
        }
    }

    private func fittingHeight(of view: UIView, width: CGFloat) -> CGFloat {
        view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    /// The sheet spans its full width, so on the Duo's cover display the camera can sit beside
    /// the header. A row the camera actually overlaps narrows by the same amount on both sides,
    /// so it stays centered; the column itself never shifts.
    private func updateOcclusionClearance() {
        var cameras: [CGRect] = []
        if #available(iOS 27.1, *) {
            cameras = view.reservedRegions(kind: .occlusion).map(\.frame)
        }
        var changed = false
        for entry in occlusionRows {
            let row = entry.row
            var inset: CGFloat = 0
            if row.superview != nil, row.window != nil {
                let frame = row.convert(row.bounds, to: view)
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
        if changed {
            view.layoutIfNeeded()
        }
    }

    /// The header's labels span their container, whose width changes when the mode switches or the
    /// sheet resizes (book pose ↔ open). A label still measured for the old width would truncate
    /// instead of wrapping, so its wrap width follows its real width and the view lays out again.
    private func updateHeaderWrapWidth() {
        var changed = false
        for label in [titleLabel, subtitleLabel] where label.bounds.width > 0 {
            guard label.preferredMaxLayoutWidth != label.bounds.width else { continue }
            label.preferredMaxLayoutWidth = label.bounds.width
            changed = true
        }
        if changed {
            view.layoutIfNeeded()
        }
    }

    /// The app's ink button. The colors are resolved per appearance because the glass doesn't keep
    /// a dynamic title color legible (as Onboarding's Got It and MonthFilterCards' Continue pill).
    private func applyButtonStyle() {
        guard status == .permissionRequest else { return }
        let ink: UIColor = traitCollection.userInterfaceStyle == .dark ? .black : .white
        let title = NSAttributedString(string: Strings.allowAccess, attributes: [
            .font: ThemeManager.Fonts.titleFont(size: 17, weight: .semibold),
            .foregroundColor: ink,
        ])
        allowButton.configure(
            attributedTitle: title,
            style: .prominent,
            backgroundColor: UIColor.label.resolvedColor(with: traitCollection),
            foregroundColor: ink)
    }

    // MARK: - Actions

    @objc private func allowTapped() {
        allowButton.isEnabled = false
        Task { @MainActor in
            let status = await PhotoLibraryService.shared.requestAuthorization()

            self.allowButton.isEnabled = true

            if status == .authorized || status == .limited {
                NotificationCenter.default.post(name: .photoAuthorizationGranted, object: nil)
                self.dismiss(animated: true)
            } else {
                self.showSettingsAlert()
            }
        }
    }

    @objc private func closeTapped() {
        HapticFeedbackManager.shared.impact(intensity: .light)
        dismiss(animated: true)
    }

    private func showSettingsAlert() {
        let alert = UIAlertController(
            title: Strings.settingsAlertTitle,
            message: Strings.settingsAlertMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: Strings.openSettings, style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }

    @objc private func appDidBecomeActive() {
        let status = PhotoLibraryService.shared.authorizationStatus()
        if status == .authorized || status == .limited {
            NotificationCenter.default.post(name: .photoAuthorizationGranted, object: nil)
            dismiss(animated: true)
        }
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Light Mode") {
        let vc = AskPermissionBoardingViewController()
        vc.overrideUserInterfaceStyle = .light
        return vc
    }

    @available(iOS 17.0, *)
    #Preview("Dark Mode") {
        let vc = AskPermissionBoardingViewController()
        vc.overrideUserInterfaceStyle = .dark
        return vc
    }

    @available(iOS 17.0, *)
    #Preview("No Action") {
        AskPermissionBoardingViewController(status: .noAction)
    }
#endif
