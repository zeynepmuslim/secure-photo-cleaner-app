//
//  HomeViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 24.01.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let navTitle = NSLocalizedString("home.navTitle", comment: "Home tab title")
    static let photosTitle = NSLocalizedString("home.photosTitle", comment: "Photos section title")
    static let videosTitle = NSLocalizedString("home.videosTitle", comment: "Videos section title")
    static let browseByMonth = NSLocalizedString("home.browseByMonth", comment: "Browse by month section header")
    static let luckyItem = NSLocalizedString("home.luckyItem", comment: "Lucky bar item title (random month and filter)")
}

private enum HomeLayout {
    /// Between Home's cards and groups (also the fold gap when fully open).
    static let cardSpacing: CGFloat = 16
}

final class HomeViewController: UIViewController {

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = HomeLayout.cardSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let storageAnalysisView: StorageAnalysisLiteView = {
        let view = StorageAnalysisLiteView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultHigh, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        return view
    }()

    private let dashboardCard: DashboardCard = {
        let card = DashboardCard()
        card.setContentHuggingPriority(.defaultLow, for: .vertical)
        card.setContentCompressionResistancePriority(.required, for: .vertical)
        return card
    }()

    private let quickAccessStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setContentHuggingPriority(.defaultLow, for: .vertical)
        stack.setContentCompressionResistancePriority(UILayoutPriority(200), for: .vertical)
        return stack
    }()

    private let quickPhotosCard: FilterCard = {
        let card = FilterCard()
        card.configure(
            icon: "photo.fill",
            title: Strings.photosTitle,
            subtitle: Strings.browseByMonth,
            tintColor: .photo100
        )
        return card
    }()

    private let quickVideosCard: FilterCard = {
        let card = FilterCard()
        card.configure(
            icon: "video.fill",
            title: Strings.videosTitle,
            subtitle: Strings.browseByMonth,
            tintColor: .video100
        )
        return card
    }()


    private let photoLibraryService = PhotoLibraryService.shared
    private let statsStore = StatsStore.shared
    private let storageManager = StorageAnalysisManager.shared
    private let cardManager = DashboardCardManager.shared

    private var totalPhotosCount: Int = 0
    private var isFirstLaunch: Bool = false
    private var hasNavigatedAway: Bool = false   // to prevent show direct response from async
    private var dashboardRefreshTask: Task<Void, Never>?
    private var hasRunStartupFlow = false
    private var contentLeadingConstraint: NSLayoutConstraint?
    private var contentTrailingConstraint: NSLayoutConstraint?
    private var contentBottomConstraint: NSLayoutConstraint?
    private var contentBottomToViewConstraint: NSLayoutConstraint?
    private var quickAccessMaxHeightConstraint: NSLayoutConstraint?

    // iPhone Duo inner display: overview (storage + tiles) and dashboard sit on either
    // side of the fold. Home's own padding and margins stay the same.
    private let overviewStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = HomeLayout.cardSpacing
        return stack
    }()
    private var overviewEdgeToFoldConstraint: NSLayoutConstraint?
    /// Axis the content is split along at the fold; nil means the single column.
    private var foldSplitAxis: NSLayoutConstraint.Axis?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        navigationItem.title = "Purgio"
        tabBarItem.title = Strings.navTitle
        setupUI()
        setupConstraint()
        setupNotifications()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        updateStorageAnalysisView()
        refreshDashboardCard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasRunStartupFlow else { return }
        hasRunStartupFlow = true
        runStartupFlow()
    }

    private func runStartupFlow() {
        guard presentedViewController == nil else { return }

        if !OnboardingStore.shared.hasCompletedOnboarding {
            let onboarding = OnboardingViewController()
            if let sheet = onboarding.sheetPresentationController {
                if #available(iOS 16.0, *) {
                    let threeQuarterDetent = UISheetPresentationController.Detent.custom { context in
                        context.maximumDetentValue * 0.75
                    }
                    sheet.detents = [threeQuarterDetent]
                } else {
                    sheet.detents = [.large()]
                }
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
            onboarding.onDismiss = { [weak self] in
                self?.runStartupFlow()
            }
            present(onboarding, animated: true)
            return
        }

        if photoLibraryService.authorizationStatus() == .notDetermined {
            let permission = AskPermissionBoardingViewController()
            permission.isModalInPresentation = true
            present(permission, animated: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hasNavigatedAway = true
    }

    deinit {
        dashboardRefreshTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisDidStart),
            name: .storageAnalysisDidStart,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisDidFetchBasicInfo),
            name: .storageAnalysisDidFetchBasicInfo,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisDidComplete),
            name: .storageAnalysisDidComplete,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisDidFail),
            name: .storageAnalysisDidFail,
            object: nil
        )
    }

    @objc private func storageAnalysisDidStart() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStorageAnalysisView()
        }
    }

    @objc private func storageAnalysisDidFetchBasicInfo() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStorageAnalysisView()
        }
    }

    @objc private func storageAnalysisDidComplete(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateStorageAnalysisView()
            if let data = notification.userInfo?["data"] as? StorageAnalysisData {
                self.updateCardsFromAnalysis(data)
            }

            self.cardManager.invalidateContext()
            self.refreshDashboardCard()
        }
    }

    @objc private func storageAnalysisDidFail() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStorageAnalysisView()
        }
    }

    private func setupUI() {

        // Titled standard items (not customViews), so on iPhone Duo they move into the
        // vertical bar with the other screens' items
        navigationItem.rightBarButtonItem = .helpItem(target: self, action: #selector(handleHelpTap))
        navigationItem.leftBarButtonItem = .luckyItem(
            title: Strings.luckyItem, target: self, action: #selector(handleLuckyTap))

        quickAccessStack.addArrangedSubview(quickPhotosCard)
        quickAccessStack.addArrangedSubview(quickVideosCard)

        contentStack.addArrangedSubview(storageAnalysisView)
        contentStack.addArrangedSubview(quickAccessStack)
        contentStack.addArrangedSubview(dashboardCard)

        view.addSubview(contentStack)

        storageAnalysisView.onRefreshTapped = { [weak self] in
            self?.storageManager.startAnalysis()
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleStorageAnalysisTap))
        tapGesture.delegate = self
        storageAnalysisView.addGestureRecognizer(tapGesture)

        quickPhotosCard.addTarget(self, action: #selector(handleQuickPhotosTap), for: .touchUpInside)
        quickVideosCard.addTarget(self, action: #selector(handleQuickVideosTap), for: .touchUpInside)


        isFirstLaunch = !cardManager.hasEverGeneratedContent
        let initialContent = cardManager.getCachedOrDefaultContent()
        dashboardCard.configure(with: initialContent) { [weak self] action in
            self?.handleCardAction(action)
        }

        updateStorageAnalysisView()
    }

    private func setupConstraint() {
        let leading = contentStack.leadingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: GeneralConstants.EdgePadding.content)
        let trailing = contentStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        let bottom = contentStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        let bottomToView = contentStack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        contentLeadingConstraint = leading
        contentTrailingConstraint = trailing
        contentBottomConstraint = bottom
        contentBottomToViewConstraint = bottomToView

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            leading,
            trailing,
            bottom,

            storageAnalysisView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110),
            dashboardCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),

            quickAccessStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
        ])

        let quickAccessMaxHeight = quickAccessStack.heightAnchor.constraint(lessThanOrEqualToConstant: 100)
        quickAccessMaxHeight.isActive = true
        quickAccessMaxHeightConstraint = quickAccessMaxHeight

        updateOuterPaddingForTabBarShape()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateFoldSplit()
        updateOuterPaddingForTabBarShape()
    }

    /// Splits Home at the fold when one crosses the view (inactive included, so the
    /// columns don't jump when the device folds). A vertical fold puts the two groups
    /// side by side; a horizontal one stacks them above and below it.
    private func updateFoldSplit() {
        let fold = FoldRegion.splittingFold(in: view)
        let axis: NSLayoutConstraint.Axis? = fold.map { $0.height > $0.width ? .horizontal : .vertical }
        if axis != foldSplitAxis {
            rebuildContent(splitAlong: axis)
        }

        guard let fold = fold, let axis = axis else { return }
        let foldStart = axis == .horizontal ? fold.minX : fold.minY
        let foldLength = axis == .horizontal ? fold.width : fold.height
        let foldCenter = foldStart + foldLength / 2
        // Fully open, the groups keep the regular 16pt card spacing, centered on the fold
        // line. Folded, they clear the whole region (its frame already includes the
        // margins content keeps from the fold), never less than the card spacing.
        let isFolded = FoldRegion.activeFold(in: view) != nil
        let spacing = isFolded ? max(HomeLayout.cardSpacing, foldLength) : HomeLayout.cardSpacing
        let overviewEdge = foldCenter - spacing / 2
        if overviewEdgeToFoldConstraint?.constant != overviewEdge {
            overviewEdgeToFoldConstraint?.constant = overviewEdge
        }
        if contentStack.spacing != spacing {
            contentStack.spacing = spacing
        }
    }

    private func rebuildContent(splitAlong axis: NSLayoutConstraint.Axis?) {
        foldSplitAxis = axis
        overviewEdgeToFoldConstraint?.isActive = false
        overviewEdgeToFoldConstraint = nil
        (contentStack.arrangedSubviews + overviewStack.arrangedSubviews).forEach { $0.removeFromSuperview() }

        guard let axis = axis else {
            contentStack.axis = .vertical
            contentStack.spacing = HomeLayout.cardSpacing
            quickAccessMaxHeightConstraint?.isActive = true
            contentStack.addArrangedSubview(storageAnalysisView)
            contentStack.addArrangedSubview(quickAccessStack)
            contentStack.addArrangedSubview(dashboardCard)
            return
        }

        // Tiles grow to fill the overview group instead of capping at 100pt
        quickAccessMaxHeightConstraint?.isActive = false
        overviewStack.addArrangedSubview(storageAnalysisView)
        overviewStack.addArrangedSubview(quickAccessStack)
        contentStack.axis = axis
        contentStack.addArrangedSubview(overviewStack)
        contentStack.addArrangedSubview(dashboardCard)

        let edgeToFold = axis == .horizontal
            ? overviewStack.trailingAnchor.constraint(equalTo: view.leadingAnchor)
            : overviewStack.bottomAnchor.constraint(equalTo: view.topAnchor)
        edgeToFold.isActive = true
        overviewEdgeToFoldConstraint = edgeToFold
    }

    private func updateOuterPaddingForTabBarShape() {
        guard let railSide = DuoLayout.railSide(tabBarController, in: view) else {
            contentBottomToViewConstraint?.isActive = false
            contentBottomConstraint?.isActive = true
            contentLeadingConstraint?.constant = GeneralConstants.EdgePadding.content
            contentTrailingConstraint?.constant = -GeneralConstants.EdgePadding.content
            contentBottomConstraint?.constant = -16
            updateCardCorners(isVerticalRail: false)
            return
        }

        // The rail is on the app's outer edge: trailing on the full display, leading in
        // Split View on the left half. Content keeps 6pt from the rail either way.
        let isLeftToRight = view.effectiveUserInterfaceLayoutDirection == .leftToRight
        let railIsLeading = (railSide == .left) == isLeftToRight
        // Rail leading (Split View on the left half): the 6pt gap moves next to the rail
        // and the far edge gets the standard content padding.
        let nextToRail = DuoLayout.RailPadding.nextToRail
        let content = GeneralConstants.EdgePadding.content
        contentLeadingConstraint?.constant = railIsLeading ? nextToRail : content
        contentTrailingConstraint?.constant = railIsLeading ? -content : -nextToRail

        contentBottomConstraint?.isActive = false
        contentBottomToViewConstraint?.constant = -DuoLayout.RailPadding.bottom
        contentBottomToViewConstraint?.isActive = true

        updateCardCorners(isVerticalRail: true)
    }

    /// On the vertical rail the card in the device's bottom corner follows its curve: the
    /// dashboard, or the Photos tile when the groups sit side by side at the fold.
    private func updateCardCorners(isVerticalRail: Bool) {
        // The cards' frames are only final once the stacks are laid out
        if isVerticalRail { contentStack.layoutIfNeeded() }
        [dashboardCard, quickPhotosCard, quickVideosCard].forEach {
            $0.updateCardCorners(followingDeviceCorner: isVerticalRail)
        }
    }

    private func updateStorageAnalysisView() {
        storageAnalysisView.update(with: storageManager.currentState)
    }

    private func updateCardsFromAnalysis(_ data: StorageAnalysisData) {
        totalPhotosCount = data.photosCount
    }

    @objc private func handleHelpTap() {
        let onboardingVC = OnboardingViewController()

        if let sheet = onboardingVC.sheetPresentationController {
            if #available(iOS 16.0, *) {
                let threeQuarterDetent = UISheetPresentationController.Detent.custom { context in
                    return context.maximumDetentValue * 0.75
                }
                sheet.detents = [threeQuarterDetent]
            } else {
                sheet.detents = [.large()]
            }
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }

        HapticFeedbackManager.shared.impact(intensity: .medium)
        present(onboardingVC, animated: true)
    }

    @objc private func handleLuckyTap() {
        let luckyVC = LuckyPickerSheetViewController()

        luckyVC.onSelect = { [weak self] mediaType, monthKey, filterContext in
            self?.dismiss(animated: true) {
                self?.navigateToLuckyTarget(mediaType: mediaType, monthKey: monthKey, filterContext: filterContext)
            }
        }

        if let sheet = luckyVC.sheetPresentationController {
            if #available(iOS 16.0, *) {
                let compactDetent = UISheetPresentationController.Detent.custom { _ in
                    return 360
                }
                sheet.detents = [compactDetent]
            } else {
                sheet.detents = [.medium()]
            }
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }

        HapticFeedbackManager.shared.impact(intensity: .medium)
        present(luckyVC, animated: true)
    }

    @objc private func handleStorageAnalysisTap() {
        if storageManager.iCloudPhotosSyncOn {
            return
        }

        HapticFeedbackManager.shared.impact(intensity: .medium)

        DispatchQueue.main.async { [weak self] in   // to prevent freeze
            let sheetVC = StorageAnalysisBottomSheet()
            self?.present(sheetVC, animated: true)
        }
    }

    private func refreshDashboardCard() {
        if photoLibraryService.authorizationStatus() == .notDetermined {
            return
        }
        dashboardRefreshTask?.cancel()
        dashboardRefreshTask = Task { [weak self] in
            guard let self else { return }
            let content = await cardManager.generateSmartCard()
            guard !Task.isCancelled else { return }

            if hasNavigatedAway {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    dashboardCard.updateContent(content) { [weak self] action in
                        self?.handleCardAction(action)
                    }
                }
            }
        }
    }

    // MARK: - Data Loading
    private func loadData() {
        if photoLibraryService.authorizationStatus() == .notDetermined {
            return
        }

        if let cachedData = storageManager.cachedData {
            updateCardsFromAnalysis(cachedData)
        }

        updateStorageAnalysisView()
        storageManager.refreshIfNeeded()
        refreshDashboardCard()
    }

    // MARK: - Card Action Handling
    private func handleCardAction(_ action: DashboardCardAction) {
        HapticFeedbackManager.shared.impact(intensity: .light)

        switch action {
        case .viewLargestVideos(let monthKey):
            navigateToLargeFiles(monthKey: monthKey, mediaType: .video)

        case .viewSimilarPhotos(let monthKey):
            navigateToSimilarPhotos(monthKey: monthKey)

        case .viewScreenshots(let monthKey):
            navigateToScreenshots(monthKey: monthKey)

        case .viewOldestYear(let year):
            navigateToOldestYear(year)

        case .resumeMonth(let monthKey, let mediaType):
            navigateToMonthReview(monthKey: monthKey, mediaType: mediaType)

        case .browsePhotos:
            navigateToPhotos()

        case .browseVideos:
            navigateToVideos()

        case .none:
            navigateToPhotos()
        }
    }

    // MARK: - Navigation
    private func navigateOnTab(index: Int, pushing viewController: UIViewController) {
        tabBarController?.selectedIndex = index
        guard let nav = tabBarController?.viewControllers?[index] as? UINavigationController else { return }
        nav.popToRootViewController(animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            nav.pushViewController(viewController, animated: true)
        }
    }

    private func navigateToSimilarPhotos(monthKey: String?) {
        let monthTitle = monthKey.flatMap { cardManager.formatMonthKey($0) }
        let vc = SimilarPhotosViewController(
            assets: nil,
            monthTitle: monthTitle,
            monthKey: monthKey,
            mediaType: .image
        )
        vc.navigationSource = .dashboard
        navigateOnTab(index: 1, pushing: vc)
    }

    private func navigateToLargeFiles(monthKey: String?, mediaType: PHAssetMediaType) {
        if let monthKey = monthKey {
            let monthTitle = cardManager.formatMonthKey(monthKey)
            let vc = MonthReviewViewController(
                monthTitle: monthTitle,
                monthKey: monthKey,
                mediaType: mediaType,
                filterContext: .largeFiles
            )
            vc.navigationSource = .dashboard
            let tabIndex = mediaType == .video ? 2 : 1
            navigateOnTab(index: tabIndex, pushing: vc)
        } else {
            navigateToVideos()
        }
    }

    private func navigateToScreenshots(monthKey: String?) {
        if let monthKey = monthKey {
            let monthTitle = cardManager.formatMonthKey(monthKey)
            let vc = MonthReviewViewController(
                monthTitle: monthTitle,
                monthKey: monthKey,
                mediaType: .image,
                filterContext: .screenshots
            )
            vc.navigationSource = .dashboard
            navigateOnTab(index: 1, pushing: vc)
        } else {
            navigateToPhotos()
        }
    }

    private func navigateToOldestYear(_ year: String) {
        tabBarController?.selectedIndex = 1
        if let nav = tabBarController?.viewControllers?[1] as? UINavigationController {
            nav.popToRootViewController(animated: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: .filterByYear,
                object: nil,
                userInfo: ["year": year]
            )
        }
    }

    private func navigateToMonthReview(monthKey: String, mediaType: PHAssetMediaType) {
        let monthTitle = cardManager.formatMonthKey(monthKey)

        let vc = MonthFilterCardsViewController(
            monthTitle: monthTitle,
            monthKey: monthKey,
            mediaType: mediaType
        )
        let tabIndex = mediaType == .video ? 2 : 1
        navigateOnTab(index: tabIndex, pushing: vc)
    }

    private func navigateToLuckyTarget(mediaType: PHAssetMediaType, monthKey: String, filterContext: FilterContext) {
        let monthTitle = cardManager.formatMonthKey(monthKey)
        let vc = MonthReviewViewController(
            monthTitle: monthTitle,
            monthKey: monthKey,
            mediaType: mediaType,
            filterContext: filterContext
        )
        vc.navigationSource = .luckyPicker
        let tabIndex = mediaType == .video ? 2 : 1
        navigateOnTab(index: tabIndex, pushing: vc)
    }

    private func navigateToPhotos() {
        tabBarController?.selectedIndex = 1
        if let nav = tabBarController?.viewControllers?[1] as? UINavigationController {
            nav.popToRootViewController(animated: false)
        }
    }

    private func navigateToVideos() {
        tabBarController?.selectedIndex = 2
        if let nav = tabBarController?.viewControllers?[2] as? UINavigationController {
            nav.popToRootViewController(animated: false)
        }
    }

    @objc private func handleQuickPhotosTap() {
        navigateToPhotos()
    }

    @objc private func handleQuickVideosTap() {
        navigateToVideos()
    }
}

// MARK: - UIGestureRecognizerDelegate

extension HomeViewController: UIGestureRecognizerDelegate {   // tp prevent overlap taps
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view is UIControl)
    }
}

@available(iOS 17.0, *)
#Preview {
    HomeViewController()
}
