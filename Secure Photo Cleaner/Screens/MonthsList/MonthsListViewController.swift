//
//  MonthsListViewController.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UIKit

extension Notification.Name {
    static let filterByYear = Notification.Name("filterByYear")
}

private enum Strings {
    static let allowAccessMessage = NSLocalizedString("monthsList.allowAccessMessage", comment: "Message asking user to allow photo access")
    static let allowPhotoAccess = NSLocalizedString("monthsList.allowPhotoAccess", comment: "Allow photo access button")
    static let accessDenied = NSLocalizedString("monthsList.accessDenied", comment: "Photo access denied message")
    static let openSettings = NSLocalizedString("monthsList.openSettings", comment: "Open Settings button")
    static let status = NSLocalizedString("monthsList.status", comment: "Status section header")
    static let allYears = NSLocalizedString("monthsList.allYears", comment: "All years filter option")
    static let year = NSLocalizedString("monthsList.year", comment: "Year filter label")
    static let filter = NSLocalizedString("monthsList.filter", comment: "Filter button label")
}

final class MonthsListViewController: UIViewController {

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.separatorInsetReference = .fromCellEdges
//        table.backgroundColor = .red
        table.backgroundColor = .mainBackground
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 80
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    private let helpButton = HelpButton()

    private let permissionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let permissionLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.allowAccessMessage
        label.textColor = .textSecondary
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()

    private let permissionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(Strings.allowPhotoAccess, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return button
    }()

    // Skeleton loading
    private var skeletonListView: SkeletonMonthListView?

    // iOS 26+ top gradient blur view
    private var topGradientView: GradientView?

    // MARK: - Private Services

    private let photoLibraryService = PhotoLibraryService.shared
    private let progressStore = ReviewProgressStore.shared

    // MARK: - Private State

    // Data Source
    private var allMonths: [MonthItem] = []
    private var yearSections: [YearSection] = []

    // Filters
    private var activeYearFilter: String? = nil   // nil = All Years
    private var activeStatusFilter: FilterStatus = .all
    private var filterBarButton: UIBarButtonItem?

    // Access to global bin button controller
    private var binController: FloatingBinButtonController? {
        tabBarController as? FloatingBinButtonController
    }

    // MARK: - Constants

    private let mediaType: PHAssetMediaType

    // MARK: - Computed Strings

    private var isVideo: Bool { mediaType == .video }
    private var mediaTitle: String { isVideo ? "Videos" : "Photos" }
    private var noItemsTitle: String { isVideo ? "No Videos Yet" : "No Photos Yet" }
    private var limitedAccessMessage: String {
        isVideo
            ? "Your photo access is limited. Select more videos to start reviewing by month."
            : "Your photo access is limited. Select more photos to start reviewing by month."
    }
    private var noContentMessage: String {
        isVideo
            ? "Take some videos or import them to your library to get started!"
            : "Take some photos or import them to your library to get started!"
    }
    private var selectMediaTitle: String { isVideo ? "Select Videos" : "Select Photos" }
    // MARK: - Init

    init(mediaType: PHAssetMediaType) {
        self.mediaType = mediaType
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground

        // Set navigation title
        title = mediaTitle
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        setupUI()
        setupConstraint()
        configureTopGradientView()
        setupFilterButton()
        updatePermissionState()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Ensure gradient stays on top during tab switches
        if #available(iOS 26.0, *) {
            if let gradientView = topGradientView {
                view.bringSubviewToFront(gradientView)
            }
        }

        // Reload months to show updated progress
        loadMonths()

        // Configure global bin button to show if there are items in bin
        configureGlobalBinButton()
    }

    // MARK: - Setup

    private func setupUI() {
        // Add targets
        tableView.dataSource = self
        tableView.delegate = self
        helpButton.addTarget(self, action: #selector(handleHelpTap), for: .touchUpInside)
        permissionButton.addTarget(self, action: #selector(handlePermissionTap), for: .touchUpInside)

        // Build view hierarchy
        permissionStack.addArrangedSubview(permissionLabel)
        permissionStack.addArrangedSubview(permissionButton)

        view.addSubview(tableView)
        view.addSubview(permissionStack)

        // Add content inset to tableView so content doesn't get hidden behind floating button
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            // TableView extends to full screen
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            permissionStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            permissionStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            permissionStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            permissionStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFilterByYear(_:)),
            name: .filterByYear,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePhotoLibraryChange),
            name: .photoLibraryDidChange,
            object: nil
        )
    }

    @objc private func handlePhotoLibraryChange() {
        loadMonths()
    }

    @objc private func handleFilterByYear(_ notification: Notification) {
        guard let year = notification.userInfo?["year"] as? String else { return }
        activeYearFilter = year
        applyFilters()

        // Scroll to top to show the filtered content
        if !yearSections.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }

    // MARK: - Bin Button

    private func configureGlobalBinButton() {
        let count = DeleteBinStore.shared.count
        binController?.configureBinButton(
            mode: .count(count),
            monthKey: nil,
            monthTitle: nil,
            tapHandler: { [weak self] in
                self?.handleBinTap()
            }
        )

        // Always show the bin button on Photos/Videos tabs
        binController?.showBinButton()
    }

    private func handleBinTap() {
        let binVC = DeleteBinViewController()
        navigationController?.pushViewController(binVC, animated: true)
    }

    // MARK: - Top Gradient

    private func configureTopGradientView() {
        // Only add gradient view on iOS 26+
        if #available(iOS 26.0, *) {
            let gradientView = GradientView()
            gradientView.translatesAutoresizingMaskIntoConstraints = false
            gradientView.isUserInteractionEnabled = false
            gradientView.colors = [
                .mainBackground,
                .mainBackground.withAlphaComponent(0)
            ]
            gradientView.locations = [0.0, 1.0]
            gradientView.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientView.endPoint = CGPoint(x: 0.5, y: 1.0)
            view.addSubview(gradientView)

            self.topGradientView = gradientView

            // Layout constraints - spans from top of view to bottom of navigation bar (includes Dynamic Island)
            NSLayoutConstraint.activate([
                gradientView.topAnchor.constraint(equalTo: view.topAnchor),
                gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                gradientView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
            ])
        }
    }

    // MARK: - Empty State

    private func updateEmptyState() {
        if yearSections.isEmpty {
            let isLimited = photoLibraryService.authorizationStatus() == .limited
            let emptyStateView = EmptyStateView()
            emptyStateView.configure(
                icon: "photo.on.rectangle.angled",
                iconColor: .systemGray,
                title: noItemsTitle,
                message: isLimited ? limitedAccessMessage : noContentMessage,
                actionTitle: isLimited ? selectMediaTitle : nil,
                onAction: isLimited
                    ? { [weak self] in
                        self?.presentLimitedLibraryPicker()
                    } : nil
            )
            tableView.backgroundView = emptyStateView
            emptyStateView.show(animated: true)
        } else {
            tableView.backgroundView = nil
        }
    }

    private func presentLimitedLibraryPicker() {
        guard #available(iOS 14.0, *) else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
    }

    // MARK: - Permission

    private func updatePermissionState() {
        let status = photoLibraryService.authorizationStatus()
        switch status {
        case .authorized, .limited:
            permissionStack.isHidden = true
            tableView.isHidden = false
            loadMonths()
        case .notDetermined:
            permissionLabel.text = Strings.allowAccessMessage
            permissionButton.setTitle(Strings.allowPhotoAccess, for: .normal)
            permissionStack.isHidden = false
            tableView.isHidden = true
        default:
            permissionLabel.text = Strings.accessDenied
            permissionButton.setTitle(Strings.openSettings, for: .normal)
            permissionStack.isHidden = false
            tableView.isHidden = true
        }
    }

    // MARK: - Data Loading

    private func loadMonths() {
        showSkeletonLoading()
        Task {
            let buckets = await photoLibraryService.loadMonthBuckets(mediaType: mediaType)
            let allMonths = buckets.map { bucket -> MonthItem in
                // Load progress for this month with media type
                let progress = self.progressStore.getProgress(forMonthKey: bucket.key, mediaType: self.mediaType)

                // Sync originalTotalCount if live count has diverged from stored value
                var syncedTotal = progress.originalTotalCount
                if progress.originalTotalCount > 0 && bucket.totalCount != progress.originalTotalCount {
                    let newTotal = bucket.totalCount
                    let oldTotal = progress.originalTotalCount
                    ReviewProgressStore.shared.saveProgress(
                        forMonthKey: bucket.key,
                        mediaType: self.mediaType,
                        currentIndex: progress.currentIndex,
                        reviewedCount: progress.reviewedCount,
                        deletedCount: progress.deletedCount,
                        keptCount: progress.keptCount,
                        storedCount: progress.storedCount,
                        originalTotalCount: newTotal
                    )
                    if newTotal > oldTotal {
                        MonthFilterStatusStore.shared.clearAllFinishedFilters(monthKey: bucket.key)
                    }
                    syncedTotal = newTotal
                }

                return MonthItem(
                    title: bucket.title,
                    key: bucket.key,
                    currentPhotoCount: bucket.totalCount,
                    reviewedCount: progress.reviewedCount,
                    keptCount: progress.keptCount,
                    deletedCount: progress.deletedCount,
                    storedCount: progress.storedCount,
                    originalTotalCount: syncedTotal,
                    mediaType: self.mediaType
                )
            }

            self.allMonths = allMonths
            self.applyFilters()
            self.hideSkeletonLoading()
        }
    }

    // MARK: - Skeleton Loading

    private func showSkeletonLoading() {
        // Only show skeleton if we don't have data yet
        guard yearSections.isEmpty else { return }

        tableView.isHidden = true

        if skeletonListView == nil {
            let skeleton = SkeletonMonthListView(rowCount: 8)
            skeleton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(skeleton)

            NSLayoutConstraint.activate([
                skeleton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                skeleton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                skeleton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                skeleton.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            self.skeletonListView = skeleton
            skeleton.startAnimating()
        }
        skeletonListView?.isHidden = false
    }

    private func hideSkeletonLoading() {
        tableView.isHidden = false
        skeletonListView?.fadeOut()
        skeletonListView = nil
    }

    // MARK: - Filters

    private var hasActiveFilter: Bool {
        activeYearFilter != nil || activeStatusFilter != .all
    }

    private func updateResetButton() {
        if hasActiveFilter {
            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            let image = UIImage(systemName: "arrow.counterclockwise", withConfiguration: config)
            let resetButton = UIBarButtonItem(
                image: image,
                style: .plain,
                target: self,
                action: #selector(handleResetFiltersTap)
            )
            resetButton.tintColor = .textPrimary
            navigationItem.leftBarButtonItem = resetButton
        } else {
            navigationItem.leftBarButtonItem = nil
        }
    }

    @objc private func handleResetFiltersTap() {
        activeYearFilter = nil
        activeStatusFilter = .all
        applyFilters()
    }

    private func applyFilters() {
        // 1. Filter
        let filteredMonths = allMonths.filter { month in
            // Year Filter
            if let yearFilter = activeYearFilter {
                let year = month.key.components(separatedBy: "-").first ?? ""
                if year != yearFilter {
                    return false
                }
            }

            // Status Filter
            switch activeStatusFilter {
            case .all:
                return true
            case .completed:
                let total = month.originalTotalCount > 0 ? month.originalTotalCount : month.currentPhotoCount
                return total > 0 && month.reviewedCount >= total
            case .inProgress:
                let total = month.originalTotalCount > 0 ? month.originalTotalCount : month.currentPhotoCount
                return month.reviewedCount > 0 && month.reviewedCount < total
            case .notStarted:
                return month.reviewedCount == 0
            }
        }

        // 2. Group by Year
        var sections: [YearSection] = []
        var currentYear: String?
        var currentMonths: [MonthItem] = []

        for month in filteredMonths {
            let yearString = month.key.components(separatedBy: "-").first ?? ""
            let sectionYear = yearString.count == 4 ? yearString : "Older"

            if sectionYear != currentYear {
                if let y = currentYear {
                    sections.append(YearSection(year: y, months: currentMonths))
                }
                currentYear = sectionYear
                currentMonths = []
            }
            currentMonths.append(month)
        }
        if let y = currentYear {
            sections.append(YearSection(year: y, months: currentMonths))
        }

        self.yearSections = sections

        // 3. Reload
        setupFilterButton()   // Update menu selection state and available years
        updateResetButton()   // Show/hide reset button based on active filters
        tableView.reloadData()
        updateEmptyState()
    }

    private func setupFilterButton() {
        // Collect available years from local months + cache (so menu is ready before loadMonths completes)
        let localYears = Set(allMonths.compactMap { $0.key.components(separatedBy: "-").first })
        let cachedYears = Set(photoLibraryService.getCachedYears(mediaType: mediaType))
        let years = localYears.union(cachedYears).sorted(by: >)

        // Status Actions
        let statusActions = FilterStatus.allCases.map { status in
            UIAction(title: status.rawValue, state: activeStatusFilter == status ? .on : .off) { [weak self] _ in
                self?.activeStatusFilter = status
                self?.applyFilters()
            }
        }
        let statusMenu = UIMenu(title: Strings.status, options: .displayInline, children: statusActions)

        // Year Actions
        var yearActions: [UIAction] = []

        // "All Years" option
        let allYearsAction = UIAction(title: Strings.allYears, state: activeYearFilter == nil ? .on : .off) {
            [weak self] _ in
            self?.activeYearFilter = nil
            self?.applyFilters()
        }
        yearActions.append(allYearsAction)

        // Specific years
        for year in years {
            let action = UIAction(title: year, state: activeYearFilter == year ? .on : .off) { [weak self] _ in
                self?.activeYearFilter = year
                self?.applyFilters()
            }
            yearActions.append(action)
        }

        let yearMenu = UIMenu(title: Strings.year, options: .displayInline, children: yearActions)

        // Main Menu
        let menu = UIMenu(title: Strings.filter, children: [statusMenu, yearMenu])

        if let existing = filterBarButton {
            existing.menu = menu
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            let image = UIImage(systemName: "line.3.horizontal.decrease.circle", withConfiguration: config)
            let barButton = UIBarButtonItem(title: nil, image: image, primaryAction: nil, menu: menu)
            barButton.tintColor = .textPrimary
            filterBarButton = barButton
            navigationItem.rightBarButtonItems = [barButton, UIBarButtonItem(customView: helpButton)]
        }
    }

    // MARK: - Actions

    @objc private func handleHelpTap() {
        let onboardingVC = OnboardingViewController()

        // Configure as native bottom sheet
        if let sheet = onboardingVC.sheetPresentationController {
            if #available(iOS 16.0, *) {
                let threeQuarterDetent = UISheetPresentationController.Detent.custom { context in
                    return context.maximumDetentValue * 0.75
                }
                sheet.detents = [threeQuarterDetent]
            } else {
                sheet.detents = [.large()]   // Fallback for older iOS
            }
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            // Don't set preferredCornerRadius - let system use device corners automatically
        }

        // Haptic feedback
        HapticFeedbackManager.shared.impact(intensity: .medium)

        present(onboardingVC, animated: true)
    }

    @objc private func handlePermissionTap() {
        let status = photoLibraryService.authorizationStatus()
        if status == .notDetermined {
            Task {
                _ = await photoLibraryService.requestAuthorization()
                updatePermissionState()
            }
        } else {
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension MonthsListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return yearSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return yearSections[section].months.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return yearSections[section].year
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.font = ThemeManager.Fonts.titleFont(size: 22, weight: .bold)
            header.textLabel?.textColor = .textPrimary
            header.textLabel?.text = header.textLabel?.text
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "MonthCell"
        let cell =
            tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? MonthListCell
            ?? MonthListCell(style: .default, reuseIdentifier: reuseIdentifier)

        let item = yearSections[indexPath.section].months[indexPath.row]
        cell.configure(with: item)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = yearSections[indexPath.section].months[indexPath.row]
        let viewController = MonthFilterCardsViewController(
            monthTitle: item.title, monthKey: item.key, mediaType: mediaType)
        navigationController?.pushViewController(viewController, animated: true)
    }
}

@available(iOS 17.0, *)
#Preview("Photos") {
    UINavigationController(rootViewController: MonthsListViewController(mediaType: .image))
}

@available(iOS 17.0, *)
#Preview("Videos") {
    UINavigationController(rootViewController: MonthsListViewController(mediaType: .video))
}
