//
//  StorageAnalysisLiteView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 1.02.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let analyzing = NSLocalizedString("storageAnalysis.analyzing", comment: "Analyzing progress text")
    static let unableToAnalyze = NSLocalizedString("storageAnalysis.unableToAnalyze", comment: "Error when analysis fails")
    static let tryAgain = NSLocalizedString("storageAnalysis.tryAgain", comment: "Try again button")
    static let notAnalyzedYet = NSLocalizedString("storageAnalysis.notAnalyzedYet", comment: "Not yet analyzed message")
    static let analyzeStorage = NSLocalizedString("storageAnalysis.analyzeStorage", comment: "Analyze storage button")
    static let storageBreakdown = NSLocalizedString("storageAnalysis.storageBreakdown", comment: "Storage breakdown section title")
    static let onThisDevice = NSLocalizedString("storageAnalysis.onThisDevice", comment: "On this device section")
    static let iCloudOnly = NSLocalizedString("storageAnalysis.iCloudOnly", comment: "iCloud only section")
    static let totalLibrary = NSLocalizedString("storageAnalysis.totalLibrary", comment: "Total library section")
    static let allPhotosAndVideos = NSLocalizedString("storageAnalysis.allPhotosAndVideos", comment: "All photos and videos subtitle")
    static let used = NSLocalizedString("storageAnalysis.used", comment: "Used storage label")
    static let available = NSLocalizedString("storageAnalysis.available", comment: "Available storage label")
    static let saved = NSLocalizedString("storageAnalysis.saved", comment: "Saved storage label")
    static let photos = NSLocalizedString("storageAnalysis.photos", comment: "Photos label")
    static let videos = NSLocalizedString("storageAnalysis.videos", comment: "Videos label")
    static let other = NSLocalizedString("storageAnalysis.other", comment: "Other storage label")
    static let generalStorageInfoOnly = NSLocalizedString("storageAnalysis.generalStorageInfoOnly", comment: "General storage info footer")
    static let iCloudActiveInfo = NSLocalizedString("storageAnalysis.iCloudActiveInfo", comment: "Info shown when iCloud Photos is enabled")
    static func iCloudBannerText(count: Int, size: String, percentage: Int) -> String {
        String(format: NSLocalizedString("storageAnalysis.iCloudBannerText", comment: "iCloud banner, e.g. 'iCloud Photo Library detected. 500 items (2.3 GB, 45%%) are stored only in iCloud.'"), count, size, percentage)
    }
    static func lastAnalyzed(date: String) -> String {
        String(format: NSLocalizedString("storageAnalysis.lastAnalyzed", comment: "Last analyzed date"), date)
    }
    static func lastAnalyzedStale(date: String) -> String {
        String(format: NSLocalizedString("storageAnalysis.lastAnalyzedStale", comment: "Stale analysis date with refresh hint"), date)
    }
    static func mediaCountSubtitle(photosCount: Int, videosCount: Int) -> String {
        String(format: NSLocalizedString("storageAnalysis.mediaCountSubtitle", comment: "Media count, e.g. '500 photos, 30 videos'"), photosCount, videosCount)
    }
}

final class StorageAnalysisView: UIView {

    var onRefreshTapped: (() -> Void)?

    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let storageBar: SegmentedBarView = {
        let bar = SegmentedBarView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.clipsToBounds = true
        bar.layer.cornerRadius = 4
        return bar
    }()

    private let legendStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.distribution = .fill
        return stack
    }()

    private let statusStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    private let statusDot: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let refreshButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: config), for: .normal)
        button.tintColor = .systemBlue
        return button
    }()

    // iCloud alert banner
    private let iCloudBanner: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemFill
        view.layer.cornerRadius = 10
        view.isHidden = true
        return view
    }()

    private let iCloudStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let iCloudIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        imageView.image = UIImage(systemName: "icloud.fill", withConfiguration: config)
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let iCloudLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    // Detailed breakdown section
    private let detailsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.isHidden = true
        return stack
    }()

    // Loading state
    private let loadingStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.isHidden = true
        return stack
    }()

    private let circularProgress: AnalysisProgressRing = {
        let view = AnalysisProgressRing()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.analyzing
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let savedSpaceOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = .storageSavedBar
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // Error state
    private let errorStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.isHidden = true
        return stack
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.unableToAnalyze
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemRed
        label.textAlignment = .center
        return label
    }()

    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = Strings.tryAgain
        config.image = UIImage(systemName: "arrow.clockwise")
        config.imagePadding = 6
        button.configuration = config
        button.tintColor = .systemBlue
        return button
    }()

    // Empty state
    private let emptyStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.isHidden = true
        return stack
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.notAnalyzedYet
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let analyzeButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = Strings.analyzeStorage
        config.cornerStyle = .capsule
        config.buttonSize = .small
        button.configuration = config
        return button
    }()

    private let statsStore = StatsStore.shared

    private var currentData: StorageAnalysisData?
    private var currentAvailablePercentage: CGFloat?
    private var debugSavedBytesOverride: Int64?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let data = currentData, let percentage = currentAvailablePercentage {
            updateSavedSpaceOverlay(data: data, availablePercentage: percentage)
        }
    }

    #if DEBUG
        func setDebugSavedBytesOverride(_ bytes: Int64?) {
            debugSavedBytesOverride = bytes
            if let data = currentData, let percentage = currentAvailablePercentage {
                updateSavedSpaceOverlay(data: data, availablePercentage: percentage)
            }
        }

        func setDebugProgress(phase: String, progress: Int) {
            circularProgress.setProgress(CGFloat(progress) / 100.0)
            loadingLabel.text = "\(phase.capitalized)... \(progress)%"
        }
    #endif

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = 14
        layer.borderWidth = 0
        layer.borderColor = UIColor.separator.cgColor

        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        analyzeButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusStack.addArrangedSubview(statusDot)
        statusStack.addArrangedSubview(statusLabel)
        statusStack.addArrangedSubview(spacer)
        statusStack.addArrangedSubview(refreshButton)

        iCloudStack.addArrangedSubview(iCloudIcon)
        iCloudStack.addArrangedSubview(iCloudLabel)
        iCloudBanner.addSubview(iCloudStack)

        let loadingTopRow = UIStackView()
        loadingTopRow.axis = .horizontal
        loadingTopRow.spacing = 10
        loadingTopRow.alignment = .center
        loadingTopRow.addArrangedSubview(circularProgress)
        loadingTopRow.addArrangedSubview(loadingLabel)
        loadingStack.addArrangedSubview(loadingTopRow)

        errorStack.addArrangedSubview(errorLabel)
        errorStack.addArrangedSubview(retryButton)

        emptyStack.addArrangedSubview(emptyLabel)
        emptyStack.addArrangedSubview(analyzeButton)

        addSubview(containerStack)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProgressUpdate(_:)),
            name: .storageAnalysisDidUpdateProgress,
            object: nil
        )
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),

            storageBar.heightAnchor.constraint(equalToConstant: 14),

            circularProgress.widthAnchor.constraint(equalToConstant: 22),
            circularProgress.heightAnchor.constraint(equalToConstant: 22),

            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),

            iCloudIcon.widthAnchor.constraint(equalToConstant: 24),
            iCloudIcon.heightAnchor.constraint(equalToConstant: 24),
            iCloudStack.topAnchor.constraint(equalTo: iCloudBanner.topAnchor, constant: 12),
            iCloudStack.leadingAnchor.constraint(equalTo: iCloudBanner.leadingAnchor, constant: 12),
            iCloudStack.trailingAnchor.constraint(equalTo: iCloudBanner.trailingAnchor, constant: -12),
            iCloudStack.bottomAnchor.constraint(equalTo: iCloudBanner.bottomAnchor, constant: -12)
        ])
    }

    func update(with state: StorageAnalysisState) {
        containerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch state {
        case .idle:
            showEmptyState()
        case .loading:
            showLoadingState()
        case .loadingWithBasicInfo(let totalBytes, let availableBytes):
            showLoadingWithBasicInfo(totalBytes: totalBytes, availableBytes: availableBytes)
        case .loaded(let data):
            showLoadedState(data)
        case .error:
            showErrorState()
        }
    }

    private func showEmptyState() {
        emptyStack.isHidden = false
        loadingStack.isHidden = true
        errorStack.isHidden = true
        containerStack.addArrangedSubview(emptyStack)
    }

    private func showLoadingState() {
        loadingStack.isHidden = false
        emptyStack.isHidden = true
        errorStack.isHidden = true
        circularProgress.startIndeterminate()
        loadingLabel.text = Strings.analyzing

        containerStack.addArrangedSubview(loadingStack)
    }

    private func showLoadingWithBasicInfo(totalBytes: Int64, availableBytes: Int64) {
        loadingStack.isHidden = false
        emptyStack.isHidden = true
        errorStack.isHidden = true
        circularProgress.startIndeterminate()
        loadingLabel.text = Strings.analyzing

        containerStack.addArrangedSubview(loadingStack)
        containerStack.addArrangedSubview(storageBar)
        containerStack.setNeedsLayout()
        containerStack.layoutIfNeeded()

        // Show storage bar with basic info
        let usedBytes = totalBytes - availableBytes
        let usedPercentage = CGFloat(usedBytes) / CGFloat(totalBytes)
        let availablePercentage = CGFloat(availableBytes) / CGFloat(totalBytes)
        storageBar.configure(segments: [
            .init(color: .storageUsed, percentage: usedPercentage),
            .init(color: .storageFree, percentage: availablePercentage)
        ])

        legendStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var items: [UIView] = []

        let usedItem = createLegendItem(
            color: .storageUsed,
            title: Strings.used,
            value: usedBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
        )
        items.append(usedItem)

        let availableItem = createLegendItem(
            color: .storageFree,
            title: Strings.available,
            value: availableBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
        )
        items.append(availableItem)

        let spaceSaved = debugSavedBytesOverride ?? statsStore.spaceSavedBytes
        if spaceSaved > 0 {
            let savedItem = createLegendItem(
                color: .storageSavedLabel,
                title: Strings.saved,
                value: spaceSaved.formattedBytes(allowedUnits: [.useGB, .useMB])
            )
            items.append(savedItem)
        }

        let isSmallScreen = UIScreen.main.bounds.width < 390

        if !isSmallScreen && items.count >= 5 {
            // 3 columns: (2, 2, 1) — last item vertically centered
            let col1 = UIStackView(arrangedSubviews: [items[0], items[2]])
            col1.axis = .vertical
            col1.alignment = .leading
            col1.spacing = 6

            let col2 = UIStackView(arrangedSubviews: [items[1], items[3]])
            col2.axis = .vertical
            col2.alignment = .leading
            col2.spacing = 6

            let lastItem = items[4]

            let columnsStack = UIStackView(arrangedSubviews: [col1, col2, lastItem])
            columnsStack.axis = .horizontal
            columnsStack.alignment = .center
            columnsStack.distribution = .fill
            columnsStack.spacing = 12

            col2.widthAnchor.constraint(equalTo: col1.widthAnchor).isActive = true

            legendStack.addArrangedSubview(columnsStack)
        } else if isSmallScreen && items.count >= 5 {
            // 3 rows: (2, 2, 1)
            let itemsPerRow = 2
            var rowStart = 0
            while rowStart < items.count {
                let rowEnd = min(rowStart + itemsPerRow, items.count)
                let row = UIStackView()
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.spacing = 12
                for i in rowStart..<rowEnd {
                    row.addArrangedSubview(items[i])
                }
                legendStack.addArrangedSubview(row)
                rowStart = rowEnd
            }
        } else if items.count > 3 || (isSmallScreen && items.count > 2) {
            // 2 rows: split at midpoint
            let row1 = UIStackView()
            row1.axis = .horizontal
            row1.distribution = .fillEqually
            row1.spacing = 12

            let row2 = UIStackView()
            row2.axis = .horizontal
            row2.distribution = .fillEqually
            row2.spacing = 12

            let midPoint = (items.count + 1) / 2
            for (index, item) in items.enumerated() {
                if index < midPoint {
                    row1.addArrangedSubview(item)
                } else {
                    row2.addArrangedSubview(item)
                }
            }

            legendStack.addArrangedSubview(row1)
            if !row2.arrangedSubviews.isEmpty {
                legendStack.addArrangedSubview(row2)
            }
        } else {
            // Single row
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .equalSpacing
            for item in items {
                row.addArrangedSubview(item)
            }
            legendStack.addArrangedSubview(row)
        }
        containerStack.addArrangedSubview(legendStack)

        let partialData = StorageAnalysisData(
            photosCount: 0, photosBytes: 0,
            videosCount: 0, videosBytes: 0,
            totalDeviceBytes: totalBytes,
            availableBytes: availableBytes,
            lastAnalysisDate: Date()
        )
        updateSavedSpaceOverlay(data: partialData, availablePercentage: availablePercentage)
    }

    private func showErrorState() {
        errorStack.isHidden = false
        loadingStack.isHidden = true
        emptyStack.isHidden = true
        containerStack.addArrangedSubview(errorStack)
    }

    private func showLoadedState(_ data: StorageAnalysisData) {
        loadingStack.isHidden = true
        emptyStack.isHidden = true
        errorStack.isHidden = true

        if data.iCloudPhotosSyncOn {
            iCloudBanner.isHidden = true
            detailsStack.isHidden = true

            containerStack.addArrangedSubview(storageBar)
            containerStack.setNeedsLayout()
            containerStack.layoutIfNeeded()

            let usedPercentage = CGFloat(data.usedBytes) / CGFloat(data.totalDeviceBytes)
            let availablePercentage = CGFloat(data.availableBytes) / CGFloat(data.totalDeviceBytes)

            var segments: [SegmentedBarView.Segment] = []
            segments.append(.init(color: .storageUsed, percentage: usedPercentage))
            if availablePercentage > 0 {
                segments.append(.init(color: .storageFree, percentage: availablePercentage))
            }
            storageBar.configure(segments: segments)

            updateSavedSpaceOverlay(data: data, availablePercentage: availablePercentage)

            updateLegend(with: data)
            containerStack.addArrangedSubview(legendStack)

            updateStatus(with: data)
            containerStack.addArrangedSubview(statusStack)
            return
        }

        if data.iCloudPhotosSyncOn && data.hasCloudOnlyItems {
            updateICloudBanner(with: data)
            iCloudBanner.isHidden = false
            containerStack.addArrangedSubview(iCloudBanner)
        } else {
            iCloudBanner.isHidden = true
        }

        containerStack.addArrangedSubview(storageBar)

        containerStack.setNeedsLayout()
        containerStack.layoutIfNeeded()

        var segments: [SegmentedBarView.Segment] = []

        let photosPercentage = data.photosBytes > 0 ? CGFloat(data.photosBytes) / CGFloat(data.totalDeviceBytes) : 0
        if photosPercentage > 0 {
            segments.append(.init(color: .photo100, percentage: photosPercentage))
        }

        let videosPercentage = data.videosBytes > 0 ? CGFloat(data.videosBytes) / CGFloat(data.totalDeviceBytes) : 0
        if videosPercentage > 0 {
            segments.append(.init(color: .video100, percentage: videosPercentage))
        }

        let otherPercentage = data.otherBytes > 0 ? CGFloat(data.otherBytes) / CGFloat(data.totalDeviceBytes) : 0
        if otherPercentage > 0 {
            segments.append(.init(color: .storageOther, percentage: otherPercentage))
        }

        let availablePercentage =
            data.availableBytes > 0 ? CGFloat(data.availableBytes) / CGFloat(data.totalDeviceBytes) : 0
        if availablePercentage > 0 {
            segments.append(.init(color: .storageAvailable, percentage: availablePercentage))
        }

        storageBar.configure(segments: segments)

        updateSavedSpaceOverlay(data: data, availablePercentage: availablePercentage)

        updateLegend(with: data)
        containerStack.addArrangedSubview(legendStack)

        if data.iCloudPhotosSyncOn {
            updateDetailsStack(with: data)
            detailsStack.isHidden = false
            containerStack.addArrangedSubview(detailsStack)
        } else {
            detailsStack.isHidden = true
        }

        updateStatus(with: data)
        containerStack.addArrangedSubview(statusStack)
    }

    private func updateICloudBanner(with data: StorageAnalysisData) {
        let cloudOnlyCount = data.totalCloudOnlyCount
        let cloudOnlySize = data.totalCloudOnlyBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
        let percentage = Int(data.cloudOnlyPercentage)

        iCloudLabel.text = Strings.iCloudBannerText(count: cloudOnlyCount, size: cloudOnlySize, percentage: percentage)
    }

    private func updateDetailsStack(with data: StorageAnalysisData) {
        detailsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        detailsStack.addArrangedSubview(separator)

        let titleLabel = UILabel()
        titleLabel.text = Strings.storageBreakdown
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        detailsStack.addArrangedSubview(titleLabel)

        let onDeviceRow = createDetailRow(
            icon: "iphone",
            iconColor: .secondaryLabel,
            title: Strings.onThisDevice,
            subtitle: Strings.mediaCountSubtitle(photosCount: data.photosCount, videosCount: data.videosCount),
            value: data.totalLocalMediaBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
        )
        detailsStack.addArrangedSubview(onDeviceRow)

        if data.hasCloudOnlyItems {
            let cloudRow = createDetailRow(
                icon: "icloud",
                iconColor: .secondaryLabel,
                title: Strings.iCloudOnly,
                subtitle: Strings.mediaCountSubtitle(
                    photosCount: data.photosInCloudOnlyCount, videosCount: data.videosInCloudOnlyCount),
                value: data.totalCloudOnlyBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
            )
            detailsStack.addArrangedSubview(cloudRow)
        }

        let totalRow = createDetailRow(
            icon: "photo.on.rectangle.angled",
            iconColor: .secondaryLabel,
            title: Strings.totalLibrary,
            subtitle: Strings.allPhotosAndVideos,
            value: data.totalOriginalBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
        )
        detailsStack.addArrangedSubview(totalRow)
    }

    private func createDetailRow(icon: String, iconColor: UIColor, title: String, subtitle: String, value: String)
        -> UIView
    {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 12
        container.alignment = .center

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        container.addArrangedSubview(iconView)
        container.addArrangedSubview(textStack)
        container.addArrangedSubview(valueLabel)

        return container
    }

    private func updateLegend(with data: StorageAnalysisData) {
        legendStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var items: [UIView] = []

        if data.iCloudPhotosSyncOn {
            let usedItem = createLegendItem(
                color: .storageUsed,
                title: Strings.used,
                value: data.usedBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
            )
            items.append(usedItem)

            let availableItem = createLegendItem(
                color: .storageAvailable,
                title: Strings.available,
                value: data.availableBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
            )
            items.append(availableItem)

            let spaceSaved = debugSavedBytesOverride ?? statsStore.spaceSavedBytes
            if spaceSaved > 0 {
                let savedItem = createLegendItem(
                    color: .storageSavedLabel,
                    title: Strings.saved,
                    value: spaceSaved.formattedBytes(allowedUnits: [.useGB, .useMB])
                )
                items.append(savedItem)
            }

            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .equalSpacing
            for item in items {
                row.addArrangedSubview(item)
            }
            legendStack.addArrangedSubview(row)
            return
        }

        let suffix = data.iCloudPhotosSyncOn ? " (local)" : ""

        if data.photosBytes > 0 {
            let photosItem = createLegendItem(
                color: .photo100,
                title: Strings.photos + suffix,
                value: data.photosBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
            )
            items.append(photosItem)
        }

        if data.videosBytes > 0 {
            let videosItem = createLegendItem(
                color: .video100,
                title: Strings.videos + suffix,
                value: data.videosBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
            )
            items.append(videosItem)
        }

        if data.photosBytes > 0 || data.videosBytes > 0 {
            let otherItem = createLegendItem(
                color: .storageOther,
                title: Strings.other,
                value: data.otherBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
            )
            items.append(otherItem)
        } else {
            let usedItem = createLegendItem(
                color: .storageUsed,
                title: Strings.used,
                value: data.usedBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
            )
            items.append(usedItem)
        }

        let availableItem = createLegendItem(
            color: .storageAvailable,
            title: Strings.available,
            value: data.availableBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
        )
        items.append(availableItem)

        let spaceSaved = debugSavedBytesOverride ?? statsStore.spaceSavedBytes
        if spaceSaved > 0 {
            let savedItem = createLegendItem(
                color: .storageSavedLabel,
                title: Strings.saved,
                value: spaceSaved.formattedBytes(allowedUnits: [.useGB, .useMB])
            )
            items.append(savedItem)
        }

        let isSmallScreen = UIScreen.main.bounds.width < 390

        if !isSmallScreen && items.count >= 5 {
            // 3 columns: (2, 2, 1) — last item vertically centered
            let col1 = UIStackView(arrangedSubviews: [items[0], items[2]])
            col1.axis = .vertical
            col1.alignment = .leading
            col1.spacing = 6

            let col2 = UIStackView(arrangedSubviews: [items[1], items[3]])
            col2.axis = .vertical
            col2.alignment = .leading
            col2.spacing = 6

            let lastItem = items[4]

            let columnsStack = UIStackView(arrangedSubviews: [col1, col2, lastItem])
            columnsStack.axis = .horizontal
            columnsStack.alignment = .center
            columnsStack.distribution = .fill
            columnsStack.spacing = 12

            col2.widthAnchor.constraint(equalTo: col1.widthAnchor).isActive = true

            legendStack.addArrangedSubview(columnsStack)
        } else if isSmallScreen && items.count >= 5 {
            // 3 rows: (2, 2, 1)
            let itemsPerRow = 2
            var rowStart = 0
            while rowStart < items.count {
                let rowEnd = min(rowStart + itemsPerRow, items.count)
                let row = UIStackView()
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.spacing = 12
                for i in rowStart..<rowEnd {
                    row.addArrangedSubview(items[i])
                }
                legendStack.addArrangedSubview(row)
                rowStart = rowEnd
            }
        } else if items.count > 3 || (isSmallScreen && items.count > 2) {
            // 2 rows: split at midpoint
            let row1 = UIStackView()
            row1.axis = .horizontal
            row1.distribution = .fillEqually
            row1.spacing = 12

            let row2 = UIStackView()
            row2.axis = .horizontal
            row2.distribution = .fillEqually
            row2.spacing = 12

            let midPoint = (items.count + 1) / 2
            for (index, item) in items.enumerated() {
                if index < midPoint {
                    row1.addArrangedSubview(item)
                } else {
                    row2.addArrangedSubview(item)
                }
            }

            legendStack.addArrangedSubview(row1)
            if !row2.arrangedSubviews.isEmpty {
                legendStack.addArrangedSubview(row2)
            }
        } else {
            // Single row
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .equalSpacing
            for item in items {
                row.addArrangedSubview(item)
            }
            legendStack.addArrangedSubview(row)
        }
    }

    private func updateStatus(with data: StorageAnalysisData) {
        if data.iCloudPhotosSyncOn {
            statusDot.backgroundColor = .systemBlue
            statusLabel.text = Strings.iCloudActiveInfo
            statusLabel.textColor = .secondaryLabel
            refreshButton.isHidden = true
            return
        }

        refreshButton.isHidden = false

        let hasDetailedData = data.photosBytes > 0 || data.videosBytes > 0

        guard hasDetailedData else {
            statusDot.backgroundColor = .systemGray
            statusLabel.text = Strings.generalStorageInfoOnly
            statusLabel.textColor = .secondaryLabel
            return
        }

        let freshness = data.freshness

        switch freshness {
        case .fresh:
            statusDot.backgroundColor = .systemGreen
            statusLabel.text = Strings.lastAnalyzed(date: data.formattedLastAnalysis)
            statusLabel.textColor = .secondaryLabel
        case .recent:
            statusDot.backgroundColor = .systemYellow
            statusLabel.text = Strings.lastAnalyzed(date: data.formattedLastAnalysis)
            statusLabel.textColor = .secondaryLabel
        case .stale:
            statusDot.backgroundColor = .systemRed
            statusLabel.text = Strings.lastAnalyzedStale(date: data.formattedLastAnalysis)
            statusLabel.textColor = .systemOrange
        }
    }

    private func createLegendItem(color: UIColor, title: String, value: String) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4
        container.alignment = .leading

        let colorDot = UIView()
        colorDot.backgroundColor = color
        colorDot.layer.cornerRadius = 4
        colorDot.translatesAutoresizingMaskIntoConstraints = false
        colorDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        colorDot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let titleStack = UIStackView()
        titleStack.axis = .horizontal
        titleStack.spacing = 6
        titleStack.alignment = .center

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabel

        titleStack.addArrangedSubview(colorDot)
        titleStack.addArrangedSubview(titleLabel)
        container.addArrangedSubview(titleStack)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = .label
        container.addArrangedSubview(valueLabel)

        return container
    }

    // MARK: - Action
    @objc private func refreshTapped() {
        onRefreshTapped?()
    }

    private func updateSavedSpaceOverlay(data: StorageAnalysisData, availablePercentage: CGFloat) {
        self.currentData = data
        self.currentAvailablePercentage = availablePercentage

        let spaceSaved = debugSavedBytesOverride ?? statsStore.spaceSavedBytes

        guard spaceSaved > 0, data.totalDeviceBytes > 0 else {
            savedSpaceOverlay.isHidden = true
            return
        }

        let savedPercentage = CGFloat(spaceSaved) / CGFloat(data.totalDeviceBytes)

        let barWidth = self.storageBar.bounds.width
        guard barWidth > 0 else { return }

        if savedSpaceOverlay.superview != storageBar {
            savedSpaceOverlay.removeFromSuperview()
            storageBar.addSubview(savedSpaceOverlay)
        }
        storageBar.bringSubviewToFront(savedSpaceOverlay)

        savedSpaceOverlay.isHidden = false

        let usedPercentage = 1.0 - availablePercentage
        let separatorWidth: CGFloat = 2

        let availableStartX = (barWidth * usedPercentage) + separatorWidth
        let calculatedWidth = barWidth * savedPercentage
        let overlayWidth = min(max(calculatedWidth, 0), barWidth)

        let startX: CGFloat
        if availableStartX + overlayWidth <= barWidth {
            startX = max(0, availableStartX)
        } else {
            startX = max(0, barWidth - overlayWidth)
        }

        savedSpaceOverlay.backgroundColor = .storageSavedBar

        savedSpaceOverlay.frame = CGRect(
            x: startX,
            y: 0,
            width: overlayWidth,
            height: storageBar.bounds.height
        )
    }

    @objc private func handleProgressUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let phase = userInfo["phase"] as? String,
            let progress = userInfo["progress"] as? Int
        else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.circularProgress.setProgress(CGFloat(progress) / 100.0)
            self.loadingLabel.text = "\(phase.capitalized)... \(progress)%"
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Loading") {
    let view = StorageAnalysisView()
    view.update(with: .loading)
    return view
}

@available(iOS 17.0, *)
#Preview("Loaded - Fresh") {
    let view = StorageAnalysisView()
    let data = StorageAnalysisData(
        photosCount: 1500,
        photosBytes: 15_000_000_000,
        videosCount: 200,
        videosBytes: 25_000_000_000,
        totalDeviceBytes: 128_000_000_000,
        availableBytes: 40_000_000_000,
        lastAnalysisDate: Date()
    )
    view.update(with: .loaded(data))
    return view
}

@available(iOS 17.0, *)
#Preview("Loaded - Stale") {
    let view = StorageAnalysisView()
    let staleDate = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
    let data = StorageAnalysisData(
        photosCount: 1500,
        photosBytes: 15_000_000_000,
        videosCount: 200,
        videosBytes: 25_000_000_000,
        totalDeviceBytes: 128_000_000_000,
        availableBytes: 40_000_000_000,
        lastAnalysisDate: staleDate
    )
    view.update(with: .loaded(data))
    return view
}

@available(iOS 17.0, *)
#Preview("Error") {
    let view = StorageAnalysisView()
    view.update(with: .error(NSError(domain: "test", code: 0)))
    return view
}

@available(iOS 17.0, *)
#Preview("Never Analyzed") {
    let view = StorageAnalysisView()
    view.update(with: .idle)
    return view
}

@available(iOS 17.0, *)
#Preview("iCloud Basic") {
    let view = StorageAnalysisView()
    let data = StorageAnalysisData(
        photosCount: 0,
        photosBytes: 0,
        videosCount: 0,
        videosBytes: 0,
        totalDeviceBytes: 128_000_000_000,
        availableBytes: 36_000_000_000,
        lastAnalysisDate: Date(),
        iCloudPhotosSyncOn: true
    )
    view.update(with: .loaded(data))
    return view
}

@available(iOS 17.0, *)
#Preview("iCloud Basic with Saved") {
    let view = StorageAnalysisView()
    view.setDebugSavedBytesOverride(8_000_000_000)

    let data = StorageAnalysisData(
        photosCount: 0,
        photosBytes: 0,
        videosCount: 0,
        videosBytes: 0,
        totalDeviceBytes: 128_000_000_000,
        availableBytes: 44_000_000_000,
        lastAnalysisDate: Date(),
        iCloudPhotosSyncOn: true
    )
    view.update(with: .loaded(data))
    return view
}
