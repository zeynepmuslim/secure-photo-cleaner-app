//
//  TipJarViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.04.2026.
//

import Combine
import StoreKit
import UIKit

private enum Strings {
    static let title = NSLocalizedString("tipJar.title", comment: "Tip jar sheet title")
    static let openSourceNote = NSLocalizedString("tipJar.openSourceNote", comment: "Tip jar open source / free explanation")
    static let thankYou = NSLocalizedString("tipJar.thankYou", comment: "Thank you message after successful tip")
    static let error = NSLocalizedString("tipJar.error", comment: "Generic tip jar error")
    static let retry = NSLocalizedString("tipJar.retry", comment: "Retry loading products button")
    static let selectAmount = NSLocalizedString("tipJar.selectAmount", comment: "Button placeholder when no tip is selected")
    static let sendTipFormat = NSLocalizedString("tipJar.sendTipFormat", comment: "Button when a tip is selected; %@ is the price")
    static let tierSmall = NSLocalizedString("tipJar.tier.small", comment: "Small tip card label")
    static let tierMedium = NSLocalizedString("tipJar.tier.medium", comment: "Medium tip card label")
    static let tierLarge = NSLocalizedString("tipJar.tier.large", comment: "Large tip card label")
    static let gateTitle = NSLocalizedString("tipJar.gate.title", comment: "Internet gate title in tip jar")
    static let gateSubtitle = NSLocalizedString("tipJar.gate.subtitle", comment: "Internet gate explanation in tip jar")
    static let gateEnableButton = NSLocalizedString("tipJar.gate.enableButton", comment: "Button to enable internet access from tip jar")

    static func thankYouDetail(tier: String, price: String) -> String {
        String(format: NSLocalizedString("tipJar.thankYouDetail", comment: "Under the thank-you title: %1$@ is the tier name, %2$@ the price"), tier, price)
    }
}

final class TipJarViewController: UIViewController {

    private let manager = TipJarManager.shared
    private var cancellables = Set<AnyCancellable>()

    /// One row of the picker. `product` is nil only in DEBUG previews.
    private struct Tier {
        let title: String
        let price: String
        let product: Product?
    }

    private lazy var tierMetas: [(title: String, imageName: String, symbolSize: CGFloat, heightRatio: CGFloat)] = [
        (Strings.tierSmall, "small-tip", 26, 0.5),
        (Strings.tierMedium, "mid-tip", 34, 0.75),
        (Strings.tierLarge, "large-tip", 30, 1),
    ]

    private enum Layout {
        /// Below the grabber.
        static let contentTop: CGFloat = GeneralConstants.EdgePadding.content
        /// Under the last scrolling item, above the footer.
        static let contentBottom: CGFloat = 16
        /// Widest the column gets (the Duo's inner display), so the capsules don't spread out.
        static let maximumContentWidth: CGFloat = 420
        static let sectionSpacing: CGFloat = 16
        static let footerSpacing: CGFloat = 12
        /// Between the title and the note (and the gate's title and text).
        static let headerSpacing: CGFloat = 8
        /// Between the heart (or the gate's icon) and the texts beside it.
        static let iconToTextSpacing: CGFloat = 14
        static let iconPointSize: CGFloat = 34
        /// Same for the heart and the gate's icon, so both text columns start at one line.
        static let iconWidth: CGFloat = 44
        /// Between the icon and the title when the icon sits above the texts (full-height sheet).
        static let stackedIconSpacing: CGFloat = 12
        /// The heart above the texts fills some of the full-height sheet's spare room.
        static let stackedHeroIconPointSize: CGFloat = 76
        /// Above the safe area's bottom edge; on Touch ID iPhones the sheet's bottom is the safe area.
        static let footerSafeAreaBottom: CGFloat = 8
        /// Clearance from the fold region in the table pose.
        static let foldGap: CGFloat = GeneralConstants.Spacer.foldGap
        /// The sheet's title and the thank-you title.
        static let titleFontSize: CGFloat = 22
        /// From the header's bottom to the spinner while the tiers load.
        static let loadingIndicatorTop: CGFloat = 48

        /// The thank-you state: a red capsule with a heart and a tilted check badge on its corner.
        enum ThankYou {
            static let capsuleHeight: CGFloat = 150
            static let heartPointSize: CGFloat = 30
            static let stackSpacing: CGFloat = 18
            static let titleToDetail: CGFloat = 6
            static let detailFontSize: CGFloat = 13
            static let badgeSize: CGFloat = 34
            static let badgeBorderWidth: CGFloat = 3
            static let badgeCheckPointSize: CGFloat = 14
            static let badgeTilt: CGFloat = -8 * .pi / 180
            /// How far the badge sticks out above the capsule's top and past its trailing edge.
            static let badgeOverhangTop: CGFloat = 10
            static let badgeOverhangTrailing: CGFloat = 14
        }

        /// Gaps used when the content doesn't fit the medium detent with the standard ones
        /// (e.g. Turkish on a 6.3" iPhone), tried before moving to the large detent.
        enum Tight {
            static let contentTop: CGFloat = 12
            static let contentBottom: CGFloat = 8
            static let sectionSpacing: CGFloat = 10
            static let footerSpacing: CGFloat = 8
            static let headerSpacing: CGFloat = 6
        }
    }

    // MARK: - Views

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsHorizontalScrollIndicator = false
        // The scroll view already sits inside the safe area; the table-pose math reads its frame.
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.sectionSpacing
        return stack
    }()

    /// The heart beside the title and the note: above the fold in the table pose.
    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .top
        stack.spacing = Layout.iconToTextSpacing
        return stack
    }()

    /// Holds `headerStack`; its sides inset only where the camera overlaps (`updateOcclusionClearance`).
    private let headerRow: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Title over the note, beside the heart.
    private let headerTextStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.headerSpacing
        return stack
    }()

    private let heroIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "heart.fill")
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: Layout.iconPointSize, weight: .semibold)
        imageView.tintColor = .tipJarRed100
        imageView.contentMode = .center
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ThemeManager.Fonts.titleFont(size: Layout.titleFontSize, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .natural
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let openSourceNoteLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ThemeManager.Fonts.regularCaption
        label.textColor = .textSecondary
        label.textAlignment = .natural
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    /// The tier picker: one column per tier, capsules bottom-aligned at the top of each column.
    private let cardsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .top
        stack.distribution = .fillEqually
        stack.spacing = GeneralConstants.TipCapsule.spacing
        return stack
    }()

    /// The sheet's spare height is split evenly three ways: above the heart (`headerTopSpacer`),
    /// between the header and the picker or gate (`bodySpacer`), and above the footer (`flexSpacer`).
    private let flexSpacer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
        view.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)
        return view
    }()

    private let headerTopSpacer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
        view.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)
        return view
    }()

    private let bodySpacer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
        view.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)
        return view
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private lazy var retryButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = Strings.retry
        config.baseForegroundColor = .tipJarRed100
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.setContentHuggingPriority(.required, for: .vertical)
        button.addAction(UIAction { [weak self] _ in
            self?.loadProducts()
        }, for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    /// The send button (or the gate's slider), pinned under the scrolling content.
    private let footerStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.footerSpacing
        return stack
    }()

    private lazy var actionButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configure(
            title: Strings.selectAmount,
            backgroundColor: .tipJarRed100,
            font: ThemeManager.Fonts.semiboldBody,
            contentInsets: NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        )
        button.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large).isActive = true
        button.isEnabled = false
        button.addAction(UIAction { [weak self] _ in
            self?.ctaButtonTapped()
        }, for: .touchUpInside)
        return button
    }()

    // MARK: Thank-you state (C4)

    /// Fills the sheet (or, in the table pose, the area below the fold); its content is centered in it.
    private let successContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let successStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Layout.ThankYou.stackSpacing
        return stack
    }()

    private let successCapsule: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .tipJarRed100
        view.layer.cornerRadius = GeneralConstants.TipCapsule.width / 2
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let successHeartView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: Layout.ThankYou.heartPointSize, weight: .semibold)
        imageView.image = UIImage(systemName: "heart.fill", withConfiguration: config)
        imageView.tintColor = .white
        imageView.contentMode = .center
        return imageView
    }()

    private let successBadge: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .tipJarRed100
        view.layer.cornerRadius = Layout.ThankYou.badgeSize / 2
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = Layout.ThankYou.badgeBorderWidth
        view.layer.borderColor = UIColor.white.cgColor
        view.transform = CGAffineTransform(rotationAngle: Layout.ThankYou.badgeTilt)
        return view
    }()

    private let successBadgeCheck: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: Layout.ThankYou.badgeCheckPointSize, weight: .heavy)
        imageView.image = UIImage(systemName: "checkmark", withConfiguration: config)
        imageView.tintColor = .white
        imageView.contentMode = .center
        return imageView
    }()

    private let successLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ThemeManager.Fonts.titleFont(size: Layout.titleFontSize, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let successDetailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: Layout.ThankYou.detailFontSize, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    // MARK: Internet gate

    /// The gate's icon beside its title and text, in the picker's place.
    private let gateContainer: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .top
        stack.spacing = Layout.iconToTextSpacing
        return stack
    }()

    /// Holds `gateContainer` and shows or hides it; insets like `headerRow`.
    private let gateRow: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let gateTextStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.headerSpacing
        return stack
    }()

    private let gateIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: Layout.iconPointSize, weight: .semibold)
        imageView.image = UIImage(systemName: "wifi.slash", withConfiguration: config)
        imageView.tintColor = .tipJarRed100
        imageView.contentMode = .center
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    private let gateTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ThemeManager.Fonts.semiboldBody
        label.textColor = .textPrimary
        label.textAlignment = .natural
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let gateSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ThemeManager.Fonts.regularCaption
        label.textColor = .textSecondary
        label.textAlignment = .natural
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private lazy var gateEnableButton: SlideToConfirmButton = {
        let button = SlideToConfirmButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = Strings.gateEnableButton
        button.addAction(UIAction { [weak self] _ in
            self?.gateEnableButtonTapped()
        }, for: .primaryActionTriggered)
        return button
    }()

    // MARK: - State

    private var tiers: [Tier] = []
    private var tipCards: [TipTier] = []
    private var selectedTierIndex: Int?
    private var didEnableInternetForSession = false
    private var pendingInternetRestoreFeedback = false

    private var capsuleWidth: CGFloat = GeneralConstants.TipCapsule.width
    private var capsuleAreaHeight: CGFloat = GeneralConstants.TipCapsule.maximumHeight

    /// The table-pose fold in `view`'s space while it crosses the content, else nil.
    private var appliedTableFold: CGRect?
    private var isUpdatingLayout = false
    /// Fixed icon widths for the side-by-side rows; off while the icons sit above the texts.
    private lazy var iconWidthConstraints: [NSLayoutConstraint] = [
        heroIconView.widthAnchor.constraint(equalToConstant: Layout.iconWidth),
        gateIconView.widthAnchor.constraint(equalToConstant: Layout.iconWidth),
    ]
    /// Whether the icons currently sit above centered texts; nil until the first layout pass.
    private var appliedStackedIcons: Bool?
    /// True while the sheet sits at the medium detent; cleared when it moves to large because
    /// its content didn't fit (it never shrinks back).
    private var usesMediumDetent = false
    /// The medium sheet's content didn't fit with the standard gaps, so it uses `Layout.Tight`.
    private var usesTightSpacing = false

    private var contentTopInset: CGFloat { usesTightSpacing ? Layout.Tight.contentTop : Layout.contentTop }
    private var contentBottomInset: CGFloat { usesTightSpacing ? Layout.Tight.contentBottom : Layout.contentBottom }
    private var sectionSpacing: CGFloat { usesTightSpacing ? Layout.Tight.sectionSpacing : Layout.sectionSpacing }

    private var contentTopConstraint: NSLayoutConstraint?
    private var contentBottomConstraint: NSLayoutConstraint?
    private var scrollBottomToFooterConstraint: NSLayoutConstraint?
    /// Keep the three spacers equal; off in the table pose, where the fold sets the split.
    private var spreadConstraints: [NSLayoutConstraint] = []
    private var successTopConstraint: NSLayoutConstraint?

    /// A row that narrows evenly on both sides where the camera overlaps it.
    private struct OcclusionRow {
        let row: UIView
        let leading: NSLayoutConstraint
        let trailing: NSLayoutConstraint
    }
    private var occlusionRows: [OcclusionRow] = []

    var onRestoredInternet: (() -> Void)?

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if DEBUG
    enum PreviewState {
        case normal
        case gate
        case success
        case failed
    }

    private var _previewState: PreviewState?

    convenience init(previewState: PreviewState) {
        self.init()
        self._previewState = previewState
    }

    /// Stand-in tiers so the picker and the thank-you state render without StoreKit.
    private static let previewPrices = ["$0.99", "$2.99", "$4.99"]

    private func applyPreviewStateIfNeeded() {
        guard let state = _previewState else { return }
        switch state {
        case .normal:
            showNormalContent()
            rebuildCards(for: Self.previewPrices.enumerated().map { index, price in
                Tier(title: tierMetas[index].title, price: price, product: nil)
            })
        case .gate:
            showInternetGate()
        case .success:
            rebuildCards(for: Self.previewPrices.enumerated().map { index, price in
                Tier(title: tierMetas[index].title, price: price, product: nil)
            })
            selectTier(at: 1, haptic: false)
            showSuccess()
        case .failed:
            showNormalContent()
            DispatchQueue.main.async { [weak self] in
                self?.showError("Transaction could not be completed. Please try again.")
            }
        }
    }
    #endif

    deinit {
        Task { @MainActor in
            TipJarManager.shared.resetPurchaseState()
        }
    }

    // MARK: - Lifecycle

    private var didConfigureForSize = false

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 26.0, *) {
            view.backgroundColor = .clear
        } else {
            view.backgroundColor = .mainBackground
        }
        configureSheet()
        setupUI()
        setupConstraint()

        #if DEBUG
        if _previewState != nil {
            applyPreviewStateIfNeeded()
            return
        }
        #endif

        bindManager()
        if SettingsStore.shared.allowInternetAccess {
            showNormalContent()
            loadProducts()
        } else {
            showInternetGate()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !didConfigureForSize else { return }
        didConfigureForSize = true

        let isCompactHeight = (hostWindow?.bounds.height ?? view.bounds.height) <= 667
        let usesFullHeight = isCompactHeight || isDuoDisplay
        sheetPresentationController?.detents = usesFullHeight ? [.large()] : [.medium()]
        usesMediumDetent = !usesFullHeight
    }

    /// The sheet has no window of its own yet in `viewWillAppear`; the presenter's is the same one.
    private var hostWindow: UIWindow? {
        view.window ?? presentingViewController?.view.window
    }

    /// Either iPhone Duo display, where the sheet always takes the full height. Read from the
    /// window's traits and safe area, never its size:
    /// - inner display: regular width (an iPhone-only, portrait app gets it nowhere else);
    /// - cover display: compact width with a horizontal safe area (the camera strip down one side).
    private var isDuoDisplay: Bool {
        guard let window = hostWindow else { return false }
        switch window.traitCollection.horizontalSizeClass {
        case .regular:
            return true
        case .compact:
            return window.safeAreaInsets.left > 0 || window.safeAreaInsets.right > 0
        default:
            return false
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !isUpdatingLayout else { return }
        isUpdatingLayout = true
        defer { isUpdatingLayout = false }

        // The hinge update can land late or mid-transition: re-check on every pass, switch without animation.
        UIView.performWithoutAnimation {
            updateIconPlacement()
            updateTableFoldLayout()
            updateOcclusionClearance()
            updateCapsuleSizes()
        }
        growToLargeDetentIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isBeingDismissed, didEnableInternetForSession else { return }
        SettingsStore.shared.endTemporaryInternetOverride()
        didEnableInternetForSession = false
        pendingInternetRestoreFeedback = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard pendingInternetRestoreFeedback else { return }
        pendingInternetRestoreFeedback = false
        onRestoredInternet?()
    }

    private func configureSheet() {
        guard let sheet = sheetPresentationController else { return }
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }

    // MARK: - Setup

    private func setupUI() {
        titleLabel.text = Strings.title
        openSourceNoteLabel.text = Strings.openSourceNote
        successLabel.text = Strings.thankYou
        gateTitleLabel.text = Strings.gateTitle
        gateSubtitleLabel.text = Strings.gateSubtitle

        headerTextStack.addArrangedSubview(titleLabel)
        headerTextStack.addArrangedSubview(openSourceNoteLabel)
        headerStack.addArrangedSubview(heroIconView)
        headerStack.addArrangedSubview(headerTextStack)

        gateTextStack.addArrangedSubview(gateTitleLabel)
        gateTextStack.addArrangedSubview(gateSubtitleLabel)
        gateContainer.addArrangedSubview(gateIconView)
        gateContainer.addArrangedSubview(gateTextStack)

        contentStack.addArrangedSubview(headerTopSpacer)
        headerRow.addSubview(headerStack)
        gateRow.addSubview(gateContainer)
        contentStack.addArrangedSubview(headerRow)
        contentStack.addArrangedSubview(bodySpacer)
        contentStack.addArrangedSubview(cardsStack)
        contentStack.addArrangedSubview(retryButton)
        contentStack.addArrangedSubview(gateRow)
        contentStack.addArrangedSubview(flexSpacer)
        // The spacers bring no spacing of their own: at rest they measure zero.
        contentStack.setCustomSpacing(0, after: headerTopSpacer)
        contentStack.setCustomSpacing(0, after: bodySpacer)
        contentStack.setCustomSpacing(0, after: cardsStack)
        contentStack.setCustomSpacing(0, after: retryButton)
        contentStack.setCustomSpacing(0, after: gateRow)

        // The gate's slider sits in the send button's slot, so both states end on the same control row.
        footerStack.addArrangedSubview(actionButton)
        footerStack.addArrangedSubview(gateEnableButton)

        successCapsule.addSubview(successHeartView)
        successCapsule.addSubview(successBadge)
        successBadge.addSubview(successBadgeCheck)
        successStack.addArrangedSubview(successCapsule)
        successStack.addArrangedSubview(successLabel)
        successStack.setCustomSpacing(Layout.ThankYou.titleToDetail, after: successLabel)
        successStack.addArrangedSubview(successDetailLabel)
        successContainer.addSubview(successStack)

        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)
        view.addSubview(footerStack)
        view.addSubview(loadingIndicator)
        view.addSubview(successContainer)
    }

    private func setupConstraint() {
        let safeArea = view.safeAreaLayoutGuide
        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        let padding = GeneralConstants.EdgePadding.content

        let contentTop = contentStack.topAnchor.constraint(equalTo: content.topAnchor, constant: Layout.contentTop)
        let toFooter = scrollView.bottomAnchor.constraint(equalTo: footerStack.topAnchor, constant: -Layout.footerSpacing)
        let successTop = successContainer.topAnchor.constraint(equalTo: safeArea.topAnchor)
        let contentBottom = contentStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Layout.contentBottom)
        contentTopConstraint = contentTop
        contentBottomConstraint = contentBottom
        scrollBottomToFooterConstraint = toFooter
        successTopConstraint = successTop
        spreadConstraints = [
            headerTopSpacer.heightAnchor.constraint(equalTo: flexSpacer.heightAnchor),
            bodySpacer.heightAnchor.constraint(equalTo: flexSpacer.heightAnchor),
        ]
        NSLayoutConstraint.activate(spreadConstraints)

        occlusionRows = [(headerRow, headerStack), (gateRow, gateContainer)].map { row, content in
            let leading = content.leadingAnchor.constraint(equalTo: row.leadingAnchor)
            let trailing = content.trailingAnchor.constraint(equalTo: row.trailingAnchor)
            NSLayoutConstraint.activate([
                leading, trailing,
                content.topAnchor.constraint(equalTo: row.topAnchor),
                content.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            ])
            return OcclusionRow(row: row, leading: leading, trailing: trailing)
        }

        // The column fills the sheet minus 20pt a side, capped and centered on wide sheets.
        let contentFill = contentStack.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -2 * padding)
        contentFill.priority = .defaultHigh
        let footerFill = footerStack.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -2 * padding)
        footerFill.priority = .defaultHigh
        // Above the home indicator, and at least 24pt off a sheet bottom that has no safe area.
        let footerBottom = footerStack.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -Layout.footerSafeAreaBottom)
        footerBottom.priority = .defaultHigh

        // Horizontally the sheet spans its full width: it covers the tab bar and the side bar,
        // so the camera strip's safe area doesn't apply. Only rows the camera itself overlaps
        // narrow on both sides, staying centered (`updateOcclusionClearance`).
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toFooter,

            content.widthAnchor.constraint(equalTo: frame.widthAnchor),
            // Short content still fills the scroll view; the spacers take the rest.
            content.heightAnchor.constraint(greaterThanOrEqualTo: frame.heightAnchor),
            contentTop,
            contentBottom,
            contentStack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            contentStack.widthAnchor.constraint(lessThanOrEqualTo: frame.widthAnchor, constant: -2 * padding),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maximumContentWidth),
            contentFill,

            footerStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            footerStack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -2 * padding),
            footerStack.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maximumContentWidth),
            footerFill,
            footerStack.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor, constant: -Layout.footerSafeAreaBottom),
            footerStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -GeneralConstants.Spacer.buttonBottom),
            footerBottom,

            loadingIndicator.centerXAnchor.constraint(equalTo: contentStack.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: Layout.loadingIndicatorTop),

            successTop,
            successContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            successContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            successContainer.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),

            successStack.centerYAnchor.constraint(equalTo: successContainer.centerYAnchor),
            successStack.leadingAnchor.constraint(equalTo: successContainer.leadingAnchor),
            successStack.trailingAnchor.constraint(equalTo: successContainer.trailingAnchor),
            successStack.topAnchor.constraint(greaterThanOrEqualTo: successContainer.topAnchor),
            successStack.bottomAnchor.constraint(lessThanOrEqualTo: successContainer.bottomAnchor),

            successCapsule.widthAnchor.constraint(equalToConstant: GeneralConstants.TipCapsule.width),
            successCapsule.heightAnchor.constraint(equalToConstant: Layout.ThankYou.capsuleHeight),
            successHeartView.centerXAnchor.constraint(equalTo: successCapsule.centerXAnchor),
            successHeartView.centerYAnchor.constraint(equalTo: successCapsule.centerYAnchor),

            successBadge.widthAnchor.constraint(equalToConstant: Layout.ThankYou.badgeSize),
            successBadge.heightAnchor.constraint(equalToConstant: Layout.ThankYou.badgeSize),
            successBadge.topAnchor.constraint(equalTo: successCapsule.topAnchor, constant: -Layout.ThankYou.badgeOverhangTop),
            successBadge.trailingAnchor.constraint(equalTo: successCapsule.trailingAnchor, constant: Layout.ThankYou.badgeOverhangTrailing),
            successBadgeCheck.centerXAnchor.constraint(equalTo: successBadge.centerXAnchor),
            successBadgeCheck.centerYAnchor.constraint(equalTo: successBadge.centerYAnchor),
        ])
    }

    private func bindManager() {
        manager.$products
            .receive(on: DispatchQueue.main)   // Hop to main thread
            .sink { [weak self] products in    // Run each new value
                self?.rebuildCards(for: products.map { Tier(title: $0.displayName, price: $0.displayPrice, product: $0) })
            }
            .store(in: &cancellables)          // auto cancel on deinit

        manager.$purchaseState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handlePurchaseState(state)
            }
            .store(in: &cancellables)
    }

    private func loadProducts() {
        retryButton.isHidden = true
        loadingIndicator.startAnimating()
        Task { @MainActor in
            await manager.loadProducts()
            loadingIndicator.stopAnimating()
            if manager.products.isEmpty {
                retryButton.isHidden = false
            }
        }
    }

    // MARK: - Layout

    /// The fold while the device is in the table pose and the fold crosses the sheet's content.
    private func currentTableFold() -> CGRect? {
        guard #available(iOS 27.1, *),
              let fold = FoldRegion.activeFold(in: view),
              FoldRegion.pose(for: fold) == .table else { return nil }
        let contentArea = view.bounds.inset(by: view.safeAreaInsets)
        guard fold.minY > contentArea.minY, fold.maxY < contentArea.maxY else { return nil }
        return fold
    }

    /// Table pose: heart, title and note above the fold; the picker (or the gate) below it,
    /// with the footer at the bottom. The thank-you state centers below the fold.
    private func updateTableFoldLayout() {
        let fold = currentTableFold()
        guard fold != appliedTableFold || fold != nil else { return }
        appliedTableFold = fold

        guard let fold = fold else {
            setSpreadsSpareHeight(true)
            contentTopConstraint?.constant = contentTopInset
            contentStack.setCustomSpacing(sectionSpacing, after: headerRow)
            successTopConstraint?.constant = 0
            view.layoutIfNeeded()
            return
        }

        // The fold sets where the header ends and the body starts; spare height goes above the footer.
        setSpreadsSpareHeight(false)

        // In the scroll view's frame space, which matches its content at rest.
        let foldInScroll = view.convert(fold, to: scrollView).offsetBy(dx: 0, dy: -scrollView.contentOffset.y)
        let headerHeight = headerRow.systemLayoutSizeFitting(
            CGSize(width: contentStack.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let spaceAboveFold = foldInScroll.minY - Layout.foldGap
        let top = max(contentTopInset, ((spaceAboveFold - headerHeight) / 2).rounded())
        let gap = max(sectionSpacing, foldInScroll.maxY + Layout.foldGap - (top + headerHeight))

        contentTopConstraint?.constant = top
        contentStack.setCustomSpacing(gap, after: headerRow)
        successTopConstraint?.constant = max(0, fold.maxY - view.safeAreaInsets.top)
        view.layoutIfNeeded()
    }

    /// The sheet spans its full width, so on the Duo's cover display the camera can sit beside
    /// the header. A row the camera actually overlaps narrows by the same amount on both sides,
    /// so it stays centered; the column itself never shifts.
    private func updateOcclusionClearance() {
        var cameras: [CGRect] = []
        if #available(iOS 27.1, *) {
            cameras = view.reservedRegions(kind: .occlusion).map(\.frame)
        }
        for entry in occlusionRows {
            let row = entry.row
            var inset: CGFloat = 0
            if !row.isHidden, row.window != nil {
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
        }
        view.layoutIfNeeded()
    }

    /// Splits spare height evenly above the heart, under the header and above the footer,
    /// or (table pose) leaves it all above the footer.
    private func setSpreadsSpareHeight(_ spreads: Bool) {
        if spreads {
            headerTopSpacer.isHidden = false
            bodySpacer.isHidden = false
            NSLayoutConstraint.activate(spreadConstraints)
        } else {
            NSLayoutConstraint.deactivate(spreadConstraints)
            headerTopSpacer.isHidden = true
            bodySpacer.isHidden = true
        }
    }

    /// Sizes the capsules to the room the sheet has: the large tier up to 200pt, the others
    /// 1.5 : 1 smaller, the smallest never shorter than its width (the width gives way first).
    private func updateCapsuleSizes() {
        guard !tipCards.isEmpty, !cardsStack.isHidden, contentStack.bounds.width > 0 else { return }

        let spacing = GeneralConstants.TipCapsule.spacing
        let columnWidth = ((contentStack.bounds.width - 2 * spacing) / 3).rounded(.down)
        let fixedHeight = naturalContentHeight() - capsuleAreaHeight
        let available = scrollView.bounds.height - (contentTopConstraint?.constant ?? 0) - contentBottomInset - fixedHeight

        var width = min(GeneralConstants.TipCapsule.width, columnWidth)
        var area = min(GeneralConstants.TipCapsule.maximumHeight, available)
        if area < 2 * width {
            width = max(GeneralConstants.TipCapsule.minimumWidth, min(width, (area / 2).rounded(.down)))
            area = 2 * width
        }
        area = area.rounded(.down)

        guard abs(area - capsuleAreaHeight) > 0.5 || abs(width - capsuleWidth) > 0.5 else { return }
        capsuleWidth = width
        capsuleAreaHeight = area
        tipCards.forEach { $0.setCapsuleSize(width: width, areaHeight: area) }
        view.layoutIfNeeded()
    }

    /// The column's height without the spare height the spacers take.
    private func naturalContentHeight() -> CGFloat {
        contentStack.systemLayoutSizeFitting(
            CGSize(width: contentStack.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    private var contentOverflows: Bool {
        let needed = (contentTopConstraint?.constant ?? contentTopInset) + naturalContentHeight() + contentBottomInset
        return needed > scrollView.bounds.height + 0.5
    }

    /// A medium sheet too short for its content even with the smallest capsules first tightens
    /// its gaps (`Layout.Tight`), which keeps it medium when it's only a line short. If it
    /// still doesn't fit (the Duo's cover display, a short window), it moves to the large
    /// detent, with the standard gaps, instead of scrolling the picker or the gate out of view.
    /// It's measured, not guessed from the window's size, and each step happens once.
    private func growToLargeDetentIfNeeded() {
        guard usesMediumDetent,
              let sheet = sheetPresentationController,
              successContainer.isHidden,
              scrollView.bounds.height > 0,
              contentStack.bounds.width > 0,
              contentOverflows else { return }

        if !usesTightSpacing {
            UIView.performWithoutAnimation {
                setTightSpacing(true)
                updateCapsuleSizes()
            }
            guard contentOverflows else { return }
        }

        usesMediumDetent = false
        UIView.performWithoutAnimation { setTightSpacing(false) }
        let grow = { sheet.detents = [.large()] }
        if view.window != nil, !isBeingPresented {
            sheet.animateChanges(grow)
        } else {
            grow()
        }
    }

    /// The full-height sheet has room to spare, so the heart and the gate's icon sit above
    /// centered texts; the medium sheet keeps them beside the texts, level with the title's top.
    private func updateIconPlacement() {
        let stacked = !usesMediumDetent
        guard appliedStackedIcons != stacked else { return }
        appliedStackedIcons = stacked
        tipCards.forEach { $0.restingColor = capsuleRestingColor }

        for row in [headerStack, gateContainer] {
            row.axis = stacked ? .vertical : .horizontal
            row.alignment = stacked ? .fill : .top
            row.spacing = stacked ? Layout.stackedIconSpacing : Layout.iconToTextSpacing
        }
        let textAlignment: NSTextAlignment = stacked ? .center : .natural
        [titleLabel, openSourceNoteLabel, gateTitleLabel, gateSubtitleLabel].forEach { $0.textAlignment = textAlignment }
        // Stacked, an icon spans the column (centered by its content mode), so it mustn't hug
        // its glyph or the column would shrink to the icon's width.
        heroIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: stacked ? Layout.stackedHeroIconPointSize : Layout.iconPointSize,
            weight: .semibold
        )
        let iconHugging: UILayoutPriority = stacked ? .defaultLow : .required
        [heroIconView, gateIconView].forEach { $0.setContentHuggingPriority(iconHugging, for: .horizontal) }
        if stacked {
            NSLayoutConstraint.deactivate(iconWidthConstraints)
        } else {
            NSLayoutConstraint.activate(iconWidthConstraints)
        }
    }

    /// On iOS 26 the full-height sheet turns opaque (white in light mode), where the grouped
    /// white capsules would vanish; there they take the secondary background instead.
    private var capsuleRestingColor: UIColor {
        if #available(iOS 26.0, *), !usesMediumDetent {
            return .secondarySystemBackground
        }
        return .secondarySystemGroupedBackground
    }

    private func setTightSpacing(_ tight: Bool) {
        usesTightSpacing = tight
        contentBottomConstraint?.constant = -contentBottomInset
        let footerGap = tight ? Layout.Tight.footerSpacing : Layout.footerSpacing
        footerStack.spacing = footerGap
        scrollBottomToFooterConstraint?.constant = -footerGap
        let headerGap = tight ? Layout.Tight.headerSpacing : Layout.headerSpacing
        headerTextStack.spacing = headerGap
        gateTextStack.spacing = headerGap
        if appliedTableFold == nil {
            contentTopConstraint?.constant = contentTopInset
            contentStack.setCustomSpacing(sectionSpacing, after: headerRow)
        } else {
            // The table pose recomputes its own split from the new gaps.
            appliedTableFold = nil
            updateTableFoldLayout()
        }
        view.layoutIfNeeded()
    }

    // MARK: - Internet Gate

    private func showInternetGate() {
        setGateVisible(true)
        retryButton.isHidden = true
        successContainer.isHidden = true
    }

    private func showNormalContent() {
        setGateVisible(false)
        successContainer.isHidden = true
    }

    /// The gate's text replaces the picker, and its slider replaces the send button.
    private func setGateVisible(_ visible: Bool) {
        gateRow.isHidden = !visible
        gateEnableButton.isHidden = !visible
        cardsStack.isHidden = visible
        actionButton.isHidden = visible
    }

    private func gateEnableButtonTapped() {
        SettingsStore.shared.beginTemporaryInternetOverride()
        didEnableInternetForSession = true
        HapticFeedbackManager.shared.impact(intensity: .medium)

        let gateViews: [UIView] = [gateContainer, gateEnableButton]
        let pickerViews: [UIView] = [cardsStack, actionButton]

        UIView.animate(withDuration: 0.2, animations: {
            gateViews.forEach { $0.alpha = 0 }
        }, completion: { _ in
            self.setGateVisible(false)
            gateViews.forEach { $0.alpha = 1 }
            pickerViews.forEach { $0.alpha = 0 }
            self.successContainer.isHidden = true
            self.view.layoutIfNeeded()

            UIView.animate(withDuration: 0.25) {
                pickerViews.forEach { $0.alpha = 1 }
            }
        })

        loadProducts()
    }

    // MARK: - Cards

    private func rebuildCards(for newTiers: [Tier]) {
        tipCards.forEach { $0.removeFromSuperview() }
        tipCards.removeAll()
        tiers = newTiers
        selectedTierIndex = nil
        updateActionButtonState()

        for (index, tier) in newTiers.enumerated() {
            let meta = index < tierMetas.count
                ? tierMetas[index]
                : (title: tier.title, imageName: "mid-tip", symbolSize: CGFloat(32), heightRatio: CGFloat(1))
            let card = TipTier(
                title: meta.title,
                imageName: meta.imageName,
                imageSize: meta.symbolSize,
                price: tier.price
            )
            card.heightRatio = meta.heightRatio
            card.restingColor = capsuleRestingColor
            card.setCapsuleSize(width: capsuleWidth, areaHeight: capsuleAreaHeight)
            card.addAction(UIAction { [weak self] _ in
                self?.selectTier(at: index, haptic: true)
            }, for: .touchUpInside)
            cardsStack.addArrangedSubview(card)
            tipCards.append(card)
        }
        // The sheet opens with the middle tier chosen, so the send button is ready at once.
        selectTier(at: newTiers.count / 2, haptic: false)
        view.setNeedsLayout()
    }

    private func selectTier(at index: Int, haptic: Bool) {
        guard tiers.indices.contains(index) else { return }
        if haptic {
            HapticFeedbackManager.shared.selection()
        }
        selectedTierIndex = index
        for (cardIndex, card) in tipCards.enumerated() {
            card.setSelected(cardIndex == index, animated: haptic)
        }
        updateActionButtonState()
    }

    private var selectedTier: Tier? {
        guard let index = selectedTierIndex, tiers.indices.contains(index) else { return nil }
        return tiers[index]
    }

    private func ctaButtonTapped() {
        guard let product = selectedTier?.product else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        Task { @MainActor in
            await manager.purchase(product)
        }
    }

    private func updateActionButtonState() {
        if let tier = selectedTier {
            actionButton.title = String(format: Strings.sendTipFormat, tier.price)
            actionButton.isEnabled = true
        } else {
            actionButton.title = Strings.selectAmount
            actionButton.isEnabled = false
        }
    }

    // MARK: - State Handling

    private func handlePurchaseState(_ state: TipJarManager.PurchaseState) {
        switch state {
        case .idle:
            setCardsEnabled(true)
            loadingIndicator.stopAnimating()

        case .purchasing:
            setCardsEnabled(false)
            loadingIndicator.startAnimating()

        case .success:
            loadingIndicator.stopAnimating()
            HapticFeedbackManager.shared.success()
            showSuccess()

        case .failed(let message):
            loadingIndicator.stopAnimating()
            setCardsEnabled(true)
            HapticFeedbackManager.shared.error()
            showError(message)
        }
    }

    private func setCardsEnabled(_ enabled: Bool) {
        tipCards.forEach { $0.isEnabled = enabled }
        retryButton.isEnabled = enabled
        actionButton.isEnabled = enabled && selectedTier != nil
    }

    private func showSuccess() {
        if let tier = selectedTier, let index = selectedTierIndex {
            let name = (index < tierMetas.count ? tierMetas[index].title : tier.title)
                .replacingOccurrences(of: "\n", with: " ")
            successDetailLabel.text = Strings.thankYouDetail(tier: name, price: tier.price)
            successDetailLabel.isHidden = false
        } else {
            successDetailLabel.isHidden = true
        }

        let fadingOut: [UIView] = [scrollView, footerStack]

        UIView.animate(withDuration: 0.2, animations: {
            fadingOut.forEach { $0.alpha = 0 }
        }, completion: { _ in
            fadingOut.forEach { $0.isHidden = true }
            self.successContainer.isHidden = false
            self.successContainer.alpha = 0
            self.successCapsule.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            self.view.layoutIfNeeded()

            UIView.animate(withDuration: 0.25) {
                self.successContainer.alpha = 1
            }
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.8,
                options: [],
                animations: { self.successCapsule.transform = .identity }
            )
            UIAccessibility.post(notification: .announcement, argument: Strings.thankYou)
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            #if DEBUG
            if self._previewState != nil { return }
            #endif
            self.dismiss(animated: true)
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: Strings.error,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: CommonStrings.ok, style: .default) { [weak self] _ in
            self?.manager.resetPurchaseState()
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
private struct TipJarPreview: UIViewControllerRepresentable {
    let state: TipJarViewController.PreviewState

    func makeUIViewController(context: Context) -> TipJarViewController {
        TipJarViewController(previewState: state)
    }

    func updateUIViewController(_ uiViewController: TipJarViewController, context: Context) {}
}

@available(iOS 17.0, *)
#Preview("Tip Jar — Normal") {
    TipJarPreview(state: .normal)
        .preferredColorScheme(.light)
}

@available(iOS 17.0, *)
#Preview("Tip Jar — Internet Gate") {
    TipJarPreview(state: .gate)
}

@available(iOS 17.0, *)
#Preview("Tip Jar — Success") {
    TipJarPreview(state: .success)
}

@available(iOS 17.0, *)
#Preview("Tip Jar — Failed") {
    TipJarPreview(state: .failed)
}
#endif
