//
//  HomeViewController.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 24.01.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let navTitle = "Home"
    static let photosTitle = "Photos"
    static let videosTitle = "Videos"
    static let browseByMonth = "Browse by month"
}

final class HomeViewController: UIViewController {

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
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

    private let helpButton = HelpButton()
    private let luckyButton = LuckyButton()

    private let photoLibraryService = PhotoLibraryService.shared
    private let statsStore = StatsStore.shared
    private let storageManager = StorageAnalysisManager.shared
    private let cardManager = DashboardCardManager.shared

    private var totalPhotosCount: Int = 0
    private var isFirstLaunch: Bool = false
    private var hasNavigatedAway: Bool = false   // to prevent show direct response from async
    private var dashboardRefreshTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        title = Strings.navTitle

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

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: helpButton)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: luckyButton)

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

        helpButton.addTarget(self, action: #selector(handleHelpTap), for: .touchUpInside)
        luckyButton.addTarget(self, action: #selector(handleLuckyTap), for: .touchUpInside)

        isFirstLaunch = !cardManager.hasEverGeneratedContent
        let initialContent = cardManager.getCachedOrDefaultContent()
        dashboardCard.configure(with: initialContent) { [weak self] action in
            self?.handleCardAction(action)
        }

        updateStorageAnalysisView()
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            storageAnalysisView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110),
            dashboardCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),

            quickAccessStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            quickAccessStack.heightAnchor.constraint(lessThanOrEqualToConstant: 100)
        ])
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
        HapticFeedbackManager.shared.impact(intensity: .medium)

        DispatchQueue.main.async { [weak self] in   // to prevent freeze
            let sheetVC = StorageAnalysisBottomSheet()
            self?.present(sheetVC, animated: true)
        }
    }

    private func refreshDashboardCard() {
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
