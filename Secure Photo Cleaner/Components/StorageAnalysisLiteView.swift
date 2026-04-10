//
//  StorageAnalysisLiteView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 1.02.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let storageLabel = NSLocalizedString("storageLite.storage", comment: "Storage section title")
    static let analyzing = NSLocalizedString("storageLite.analyzing", comment: "Analyzing progress text")
    static let unableToAnalyze = NSLocalizedString("storageLite.unableToAnalyze", comment: "Error message when analysis fails")
    static let tryAgain = NSLocalizedString("storageLite.tryAgain", comment: "Try again button")
    static let notAnalyzedYet = NSLocalizedString("storageLite.notAnalyzedYet", comment: "Message when storage not yet analyzed")
    static let analyzeStorage = NSLocalizedString("storageLite.analyzeStorage", comment: "Analyze storage button")
    static let used = NSLocalizedString("storageLite.used", comment: "Used storage label")
    static let available = NSLocalizedString("storageLite.available", comment: "Available storage label")
    static let photos = NSLocalizedString("storageLite.photos", comment: "Photos label")
    static let videos = NSLocalizedString("storageLite.videos", comment: "Videos label")
    static let other = NSLocalizedString("storageLite.other", comment: "Other storage label")
    static let generalStorageInfo = NSLocalizedString("storageLite.generalStorageInfo", comment: "General storage info footer")
    static func usageLabel(usedGB: String, totalGB: String) -> String {
        String(format: NSLocalizedString("storageLite.usageLabel", comment: "Usage label, e.g. 'Usage: 32 GB / 64 GB'"), usedGB, totalGB)
    }
    static func savedLabel(formatted: String) -> String {
        String(format: NSLocalizedString("storageLite.savedLabel", comment: "Saved space label, e.g. 'Saved: 2.3 GB'"), formatted)
    }
    static func lastAnalyzed(date: String) -> String {
        String(format: NSLocalizedString("storageLite.lastAnalyzed", comment: "Last analyzed date, e.g. 'Last analyzed: 5 minutes ago'"), date)
    }
}

final class StorageAnalysisLiteView: UIView {

    var onRefreshTapped: (() -> Void)?

    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let headerStack: UIStackView = {
        let stack = UIStackView()
        return stack
    }()

    private let deviceLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.storageLabel
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let usageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()

    private let storageBar: SegmentedBarView = {
        let bar = SegmentedBarView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.clipsToBounds = true
        bar.layer.cornerRadius = 4
        return bar
    }()

    private let savedSpaceOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = .storageSavedBar
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let legendStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
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

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let refreshButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        button.setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: config), for: .normal)
        button.tintColor = .systemBlue
        button.imageView?.contentMode = .scaleAspectFit
        return button
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

    // Error state
    private let errorStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
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
        stack.spacing = 10
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

    override func layoutSubviews() {
        super.layoutSubviews()

        if let data = currentData, let percentage = currentAvailablePercentage {
            updateSavedSpaceOverlay(data: data, availablePercentage: percentage)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = 14
        layer.borderWidth = 0
        layer.borderColor = UIColor.separator.cgColor

        let isSmallScreen = UIScreen.main.bounds.width < 390
        if isSmallScreen {
            headerStack.axis = .vertical
            headerStack.alignment = .leading
            headerStack.spacing = 2
            usageLabel.textAlignment = .left
        } else {
            headerStack.axis = .horizontal
            headerStack.alignment = .center
            headerStack.distribution = .equalSpacing
            usageLabel.textAlignment = .right
        }

        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        analyzeButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        headerStack.addArrangedSubview(deviceLabel)
        headerStack.addArrangedSubview(usageLabel)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusStack.addArrangedSubview(statusLabel)
        statusStack.addArrangedSubview(spacer)
        statusStack.addArrangedSubview(refreshButton)

        let loadingTopRow = UIStackView()
        loadingTopRow.axis = .horizontal
        loadingTopRow.spacing = 10
        loadingTopRow.alignment = .center
        loadingTopRow.addArrangedSubview(circularProgress)
        loadingTopRow.addArrangedSubview(loadingLabel)
        loadingStack.addArrangedSubview(loadingTopRow)

        NSLayoutConstraint.activate([
            circularProgress.widthAnchor.constraint(equalToConstant: 22),
            circularProgress.heightAnchor.constraint(equalToConstant: 22)
        ])

        // Build error stack
        errorStack.addArrangedSubview(errorLabel)
        errorStack.addArrangedSubview(retryButton)

        // Build empty stack
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
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            storageBar.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    // MARK: - State Updates
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

        let usedBytes = totalBytes - availableBytes
        let usedGB = usedBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
        let totalGB = totalBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
        usageLabel.text = Strings.usageLabel(usedGB: usedGB, totalGB: totalGB)

        containerStack.addArrangedSubview(headerStack)
        containerStack.addArrangedSubview(storageBar)
        containerStack.setNeedsLayout()
        containerStack.layoutIfNeeded()

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
            text: Strings.used
        )
        items.append(usedItem)

        let availableItem = createLegendItem(
            color: .storageFree,
            text: Strings.available
        )
        items.append(availableItem)

        let spaceSaved = debugSavedBytesOverride ?? statsStore.spaceSavedBytes
        if spaceSaved > 0 {
            let savedItem = createLegendItem(
                color: .storageSavedLabel,
                text: Strings.savedLabel(formatted: spaceSaved.formattedBytes(allowedUnits: [.useGB, .useMB])),
                font: .systemFont(ofSize: 13, weight: .semibold),
                textColor: .storageSavedLabel
            )
            items.append(savedItem)
        }

        // Use 2-row layout on small screens (iPhone SE, 7, 8 = 375pt width)
        let isSmallScreen = UIScreen.main.bounds.width < 390

        if isSmallScreen && items.count > 2 {
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
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .equalSpacing
            for item in items {
                row.addArrangedSubview(item)
            }
            legendStack.addArrangedSubview(row)
        }

        containerStack.addArrangedSubview(legendStack)
        containerStack.addArrangedSubview(loadingStack)

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

        let usedGB = data.usedBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
        let totalGB = data.totalDeviceBytes.formattedBytes(allowedUnits: [.useGB, .useMB])
        usageLabel.text = Strings.usageLabel(usedGB: usedGB, totalGB: totalGB)

        containerStack.addArrangedSubview(headerStack)
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

        updateStatus(with: data)
        containerStack.addArrangedSubview(statusStack)
    }

    private func updateLegend(with data: StorageAnalysisData) {
        legendStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var items: [UIView] = []

        if data.photosBytes > 0 || data.videosBytes > 0 {
            if data.photosBytes > 0 {
                let photosItem = createLegendItem(
                    color: .photo100,
                    text: Strings.photos
                )
                items.append(photosItem)
            }

            if data.videosBytes > 0 {
                let videosItem = createLegendItem(
                    color: .video100,
                    text: Strings.videos
                )
                items.append(videosItem)
            }
        } else {
            let usedItem = createLegendItem(
                color: .storageUsed,
                text: Strings.used
            )
            items.append(usedItem)
        }

        let otherItem = createLegendItem(
            color: .storageOther,
            text: Strings.other
        )
        items.append(otherItem)

        let spaceSaved = statsStore.spaceSavedBytes
        if spaceSaved > 0 {
            let savedItem = createLegendItem(
                color: .storageSavedLabel,
                text: Strings.savedLabel(formatted: spaceSaved.formattedBytes(allowedUnits: [.useGB, .useMB])),
                font: .systemFont(ofSize: 13, weight: .semibold),
                textColor: .storageSavedLabel
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
        let hasDetailedData = data.photosBytes > 0 || data.videosBytes > 0

        if hasDetailedData {
            statusLabel.text = Strings.lastAnalyzed(date: data.formattedLastAnalysis)
        } else {
            statusLabel.text = Strings.generalStorageInfo
        }
    }

    private func createLegendItem(
        color: UIColor, text: String, font: UIFont = .systemFont(ofSize: 13, weight: .regular),
        textColor: UIColor = .label
    ) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 6
        container.alignment = .center

        let colorDot = UIView()
        colorDot.backgroundColor = color
        colorDot.layer.cornerRadius = 6
        colorDot.translatesAutoresizingMaskIntoConstraints = false
        colorDot.widthAnchor.constraint(equalToConstant: 12).isActive = true
        colorDot.heightAnchor.constraint(equalToConstant: 12).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = text
        titleLabel.font = font
        titleLabel.textColor = textColor

        container.addArrangedSubview(colorDot)
        container.addArrangedSubview(titleLabel)

        return container
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
        let overlayWidth = min(max(calculatedWidth, 6), barWidth)

        // When overlay fits within available, left-align within available segment.
        // When it overflows, grow leftward from right edge of bar into other segments.
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

    // MARK: - Actions
    @objc private func refreshTapped() {
        onRefreshTapped?()
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

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct StorageAnalysisLiteViewPreview: UIViewRepresentable {
        let configure: (StorageAnalysisLiteView) -> Void

        func makeUIView(context: Context) -> StorageAnalysisLiteView {
            let view = StorageAnalysisLiteView()
            configure(view)
            return view
        }

        func updateUIView(_ uiView: StorageAnalysisLiteView, context: Context) {
            configure(uiView)
        }

        func sizeThatFits(_ proposal: ProposedViewSize, uiView: StorageAnalysisLiteView, context: Context) -> CGSize? {
            return CGSize(width: proposal.width ?? 360, height: 160)
        }
    }

    @available(iOS 17.0, *)
    #Preview("Lite - Loading", traits: .sizeThatFitsLayout) {
        StorageAnalysisLiteViewPreview { view in
            view.update(with: .loading)
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Lite - Loaded", traits: .sizeThatFitsLayout) {
        StorageAnalysisLiteViewPreview { view in
            let data = StorageAnalysisData(
                photosCount: 1200,
                photosBytes: 12_000_000_000,
                videosCount: 140,
                videosBytes: 22_000_000_000,
                totalDeviceBytes: 128_000_000_000,
                availableBytes: 36_000_000_000,
                lastAnalysisDate: Date()
            )
            view.update(with: .loaded(data))
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Lite - Loaded (Stale)", traits: .sizeThatFitsLayout) {
        StorageAnalysisLiteViewPreview { view in
            let staleDate = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
            let data = StorageAnalysisData(
                photosCount: 1200,
                photosBytes: 12_000_000_000,
                videosCount: 140,
                videosBytes: 22_000_000_000,
                totalDeviceBytes: 128_000_000_000,
                availableBytes: 36_000_000_000,
                lastAnalysisDate: staleDate
            )
            view.update(with: .loaded(data))
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Lite - Error", traits: .sizeThatFitsLayout) {
        StorageAnalysisLiteViewPreview { view in
            view.update(with: .error(NSError(domain: "preview", code: 0)))
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Lite - Idle", traits: .sizeThatFitsLayout) {
        StorageAnalysisLiteViewPreview { view in
            view.update(with: .idle)
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Lite - With Space Saved", traits: .sizeThatFitsLayout) {
        StorageAnalysisLiteViewPreview { view in
            view.setDebugSavedBytesOverride(15_000_000_000)   // 15 GB saved

            let data = StorageAnalysisData(
                photosCount: 1200,
                photosBytes: 12_000_000_000,   // 12 GB photos
                videosCount: 140,
                videosBytes: 22_000_000_000,   // 22 GB videos
                totalDeviceBytes: 128_000_000_000,   // 128 GB device
                availableBytes: 44_500_000_000,   // 44.5 GB available (includes saved space)
                lastAnalysisDate: Date()
            )
            view.update(with: .loaded(data))
        }
        .padding()
    }
    @available(iOS 17.0, *)
    #Preview("Lite - Loading with Info", traits: .sizeThatFitsLayout) {
        StorageAnalysisLiteViewPreview { view in
            view.setDebugSavedBytesOverride(15_000_000_000)   // 15 GB saved

            view.update(
                with: .loadingWithBasicInfo(
                    totalBytes: 128_000_000_000,
                    availableBytes: 30_000_000_000
                ))
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Lite - Loading Progress", traits: .sizeThatFitsLayout) {
        StorageAnalysisLiteViewPreview { view in
            view.update(
                with: .loadingWithBasicInfo(
                    totalBytes: 128_000_000_000,
                    availableBytes: 30_000_000_000
                ))
            view.setDebugProgress(phase: "photos", progress: 65)
        }
        .padding()
    }
#endif
