//
//  LuckyPickerSheetViewController.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 27.01.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let title              = NSLocalizedString("luckyPicker.title", comment: "I Feel Lucky sheet title")
    static let subtitle           = NSLocalizedString("luckyPicker.subtitle", comment: "Lucky picker subtitle")
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
    static func goToButton(media: String, monthTitle: String) -> String {
        String(format: NSLocalizedString("luckyPicker.goToButton", comment: "Go to button, e.g. 'Go to Photos · January 2025'"), media, monthTitle)
    }
}

final class LuckyPickerSheetViewController: UIViewController {

    struct MonthOption {
        let key: String
        let title: String
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

    private let actionButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.configure(
            style: .prominent,
            backgroundColor: .systemBlue,
            foregroundColor: .white,
            contentInsets: NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        )
        return button
    }()

    private let shuffleButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.configure(
            title: Strings.shuffleAgain,
            style: .regular,
            backgroundColor: .systemGray5,
            foregroundColor: .textPrimary,
            contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        )
        return button
    }()

    private let titleLabel: UILabel = {
        var label = UILabel()
        label.text = Strings.title
        label.font = ThemeManager.Fonts.boldTitle
        label.textColor = .textPrimary
        label.textAlignment = .left
        return label
    }()

    private let subtitleLabel: UILabel = {
        var label = UILabel()
        label.text = Strings.subtitle
        label.font = ThemeManager.Fonts.regularCaption
        label.textColor = .textSecondary
        label.textAlignment = .left
        return label
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        return stack
    }()

    private let valuesStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .equalSpacing
        return stack
    }()

    private let actionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        return stack
    }()

    private let mediaValueLabel = UILabel()
    private let monthValueLabel = UILabel()
    private let filterValueLabel = UILabel()

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
    private var animationTimer: Timer?

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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        setupUI()
        setupConstraint()
        loadMonths()
    }

    private func setupUI() {
        actionButton.addTarget(self, action: #selector(handleGoTap), for: .touchUpInside)

        configureValueLabel(mediaValueLabel, title: Strings.media)
        configureValueLabel(monthValueLabel, title: Strings.month)
        configureValueLabel(filterValueLabel, title: Strings.filter)

        shuffleButton.addTarget(self, action: #selector(handleShuffleTap), for: .touchUpInside)

        let mediaRow = makeValueRow(title: Strings.media, valueLabel: mediaValueLabel)
        let monthRow = makeValueRow(title: Strings.month, valueLabel: monthValueLabel)
        let filterRow = makeValueRow(title: Strings.filter, valueLabel: filterValueLabel)

        contentStack.addArrangedSubview(headerStack)
        headerStack.addArrangedSubview(UIView.spacer(height: 10))
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)

        contentStack.addArrangedSubview(valuesStack)
        valuesStack.addArrangedSubview(UIView.flexibleSpacer())
        valuesStack.addArrangedSubview(mediaRow)
        valuesStack.addArrangedSubview(monthRow)
        valuesStack.addArrangedSubview(filterRow)
        valuesStack.addArrangedSubview(UIView.flexibleSpacer())

        contentStack.addArrangedSubview(actionsStack)
        actionsStack.addArrangedSubview(shuffleButton)
        actionsStack.addArrangedSubview(actionButton)

        view.addSubview(contentStack)

        actionButton.isEnabled = false
        shuffleButton.isEnabled = false

        updateActionButtonTitle()
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            actionButton.heightAnchor.constraint(equalToConstant: 50),

            shuffleButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func loadMonths() {
        if let cachedPhotos = photoLibraryService.getCachedMonthBuckets(mediaType: .image),
            let cachedVideos = photoLibraryService.getCachedMonthBuckets(mediaType: .video)
        {
            photoMonths = cachedPhotos.map { MonthOption(key: $0.key, title: $0.title) }
            videoMonths = cachedVideos.map { MonthOption(key: $0.key, title: $0.title) }
            cacheAvailableMonths()
            selectRandomTarget()
            return
        }

        Task {
            async let photos = photoLibraryService.loadMonthBuckets(mediaType: .image)
            async let videos = photoLibraryService.loadMonthBuckets(mediaType: .video)

            let (loadedPhotos, loadedVideos) = await (photos, videos)

            await MainActor.run {
                photoMonths = loadedPhotos.map { MonthOption(key: $0.key, title: $0.title) }
                videoMonths = loadedVideos.map { MonthOption(key: $0.key, title: $0.title) }
                cacheAvailableMonths()
                selectRandomTarget()
            }
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

    private func selectRandomTarget() {
        let unfinishedPhotoMonths = availableMonths(for: .photos)
        let unfinishedVideoMonths = availableMonths(for: .videos)

        let photoAvailable = !unfinishedPhotoMonths.isEmpty
        let videoAvailable = !unfinishedVideoMonths.isEmpty

        if !photoAvailable && !videoAvailable {
            selectedFilter =
                photoFilters.randomElement()
                ?? FilterOption(title: Strings.filterAll, context: .none, systemImageName: "square.grid.2x2")
            actionButton.isEnabled = false
            updateActionButtonTitle()
            return
        }

        let mediaOptions: [MediaOption] = [
            photoAvailable ? .photos : nil,
            videoAvailable ? .videos : nil
        ].compactMap { $0 }

        selectedMedia = mediaOptions.randomElement() ?? .photos
        let monthOptions = selectedMedia == .photos ? unfinishedPhotoMonths : unfinishedVideoMonths
        selectedMonth = monthOptions.randomElement()
        let filterOptions = filters(for: selectedMedia)
        selectedFilter =
            filterOptions.randomElement()
            ?? FilterOption(title: Strings.filterAll, context: .none, systemImageName: "square.grid.2x2")

        updateDisplayedSelection(animated: true)

        if animationTimer == nil {
            actionButton.isEnabled = true
            shuffleButton.isEnabled = true
            updateActionButtonTitle()
        }
    }

    private func updateActionButtonTitle() {
        guard actionButton.isEnabled else {
            actionButton.configure(
                title: Strings.noMonthsAvailable,
                style: .prominent,
                backgroundColor: .systemBlue,
                foregroundColor: .white,
                contentInsets: NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            )
            return
        }

        let monthTitle = formatMonthTitle(from: selectedMonth?.key)
        let title = Strings.goToButton(media: selectedMedia.title, monthTitle: monthTitle)

        actionButton.configure(
            title: title,
            systemImage: selectedFilter.systemImageName,
            style: .prominent,
            backgroundColor: .systemBlue,
            foregroundColor: .white,
            contentInsets: NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        )

        if var config = actionButton.configuration {
            config.imagePlacement = .trailing
            actionButton.configuration = config
        }
    }

    private func formatMonthTitle(from key: String?) -> String {
        guard let key = key else { return Strings.noMonth }
        return DateFormatterManager.shared.shortMonth(fromMonthKey: key)
    }

    @objc private func handleGoTap() {
        guard let month = selectedMonth else { return }
        onSelect?(selectedMedia.mediaType, month.key, selectedFilter.context)
    }

    @objc private func handleShuffleTap() {
        startShuffleAnimation()
    }

    private func configureValueLabel(_ label: UILabel, title: String) {
        label.numberOfLines = 1
        label.textAlignment = .left
        label.font = ThemeManager.Fonts.titleFont(size: 18, weight: .bold)
        label.textColor = .textPrimary
        label.text = "—"
        label.accessibilityLabel = title
    }

    private func updateDisplayedSelection(animated: Bool) {
        let mediaText = selectedMedia.title
        let monthText = selectedMonth?.title ?? Strings.noMonth
        let filterText = selectedFilter.title

        if animated {
            UIView.transition(with: mediaValueLabel, duration: 0.2, options: .transitionCrossDissolve) {
                self.mediaValueLabel.text = mediaText
            }
            UIView.transition(with: monthValueLabel, duration: 0.2, options: .transitionCrossDissolve) {
                self.monthValueLabel.text = monthText
            }
            UIView.transition(with: filterValueLabel, duration: 0.2, options: .transitionCrossDissolve) {
                self.filterValueLabel.text = filterText
            }
        } else {
            mediaValueLabel.text = mediaText
            monthValueLabel.text = monthText
            filterValueLabel.text = filterText
        }
        updateActionButtonTitle()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startShuffleAnimation()
    }

    private func startShuffleAnimation() {
        animationTimer?.invalidate()
        actionButton.isEnabled = false
        shuffleButton.isEnabled = false
        updateActionButtonTitle()

        let endTime = Date().addingTimeInterval(2.0)
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: 0.12,
            repeats: true
        ) { [weak self] timer in
            guard let self = self else { return }

            if Date() >= endTime {
                timer.invalidate()
                self.animationTimer = nil
                self.selectRandomTarget()
                return
            }

            let media =
                [MediaOption.photos, MediaOption.videos].randomElement()
                ?? .photos
            let monthOptions = self.availableMonths(for: media)
            let filterOptions = self.filters(for: media)

            self.selectedMedia = media
            self.selectedMonth = monthOptions.randomElement()
            self.selectedFilter =
                filterOptions.randomElement()
                ?? FilterOption(title: Strings.filterAll, context: .none, systemImageName: "square.grid.2x2")
            self.updateDisplayedSelection(animated: true)
        }
    }

    private func makeValueRow(title: String, valueLabel: UILabel) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = ThemeManager.Fonts.semiboldBody
        titleLabel.textColor = .textSecondary
        titleLabel.textAlignment = .left

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .firstBaseline
        row.distribution = .fill
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(valueLabel)
        row.addArrangedSubview(UIView.flexibleSpacer())

        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        return row
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
