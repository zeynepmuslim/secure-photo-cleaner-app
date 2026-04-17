//
//  ProcessingLoadingViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Photos
import SwiftUI
import UIKit

private enum Strings {
    static let cancel = CommonStrings.cancel
    static let analyzingFileSizes = NSLocalizedString("processing.analyzingFileSizes", comment: "Analyzing file sizes progress text")
    static let calculating = NSLocalizedString("processing.calculating", comment: "Calculating progress text")
    static let scanningFaces = NSLocalizedString("processing.scanningFaces", comment: "Scanning faces progress text")
    static let initializingDetector = NSLocalizedString("processing.initializingDetector", comment: "Initializing detector progress text")
    static let loadingPhotos = NSLocalizedString("processing.loadingPhotos", comment: "Loading photos progress text")
    static let warmingUp = NSLocalizedString("processing.warmingUp", comment: "Warming up progress text")
    static func estimateRemaining(seconds: Double) -> String {
        String(format: NSLocalizedString("processing.estimateRemaining", comment: "Estimated time remaining, e.g. 'Est: 3.2s remaining'"), seconds)
    }
}

struct ProcessingConfig {
    let titleText: String
    let initialEstimateText: String
    let filterContext: FilterContext
    let isFilterResultMode: Bool
    let processAssets: ([PHAsset]) async -> AsyncStream<ProcessingResult>

    static func largeFiles() -> ProcessingConfig {
        ProcessingConfig(
            titleText: Strings.analyzingFileSizes,
            initialEstimateText: Strings.calculating,
            filterContext: .largeFiles,
            isFilterResultMode: false,
            processAssets: { assets in
                await PhotoProcessor.shared.processAssetsForLargeFiles(assets)
            }
        )
    }

    static func eyesClosed() -> ProcessingConfig {
        ProcessingConfig(
            titleText: Strings.scanningFaces,
            initialEstimateText: Strings.initializingDetector,
            filterContext: .eyesClosed,
            isFilterResultMode: true,
            processAssets: { assets in
                await PhotoProcessor.shared.processAssetsForEyesClosed(assets, progressInterval: 5)
            }
        )
    }
}

final class ProcessingLoadingViewController: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = .systemBlue
        progress.trackTintColor = .secondarySystemFill
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let estimateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(Strings.cancel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(.systemRed, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let photoLibraryService = PhotoLibraryService.shared

    private let monthKey: String
    private let monthTitle: String
    private let mediaType: PHAssetMediaType
    private let config: ProcessingConfig
    private var assets: [PHAsset] = []
    private var shouldFetchAssets = false
    private var processingTask: Task<Void, Never>?
    private var startTime: Date?
    var navigationSource: NavigationSource = .manual

    init(monthTitle: String, monthKey: String, assets: [PHAsset], mediaType: PHAssetMediaType, config: ProcessingConfig)
    {
        self.monthTitle = monthTitle
        self.monthKey = monthKey
        self.assets = assets
        self.mediaType = mediaType
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    init(monthTitle: String, monthKey: String, mediaType: PHAssetMediaType, config: ProcessingConfig) {
        self.monthTitle = monthTitle
        self.monthKey = monthKey
        self.mediaType = mediaType
        self.config = config
        self.shouldFetchAssets = true
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupUI()
        setupConstraint()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldFetchAssets {
            fetchAssetsAndProcess()
        } else {
            startProcessing()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            processingTask?.cancel()
            assets.removeAll()
        }
    }

    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(progressView)
        view.addSubview(countLabel)
        view.addSubview(estimateLabel)
        view.addSubview(cancelButton)

        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)

        titleLabel.text = config.titleText
        countLabel.text = "0/\(assets.count)"
        estimateLabel.text = config.initialEstimateText
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            progressView.heightAnchor.constraint(equalToConstant: 8),

            countLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 12),
            countLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            estimateLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 8),
            estimateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            cancelButton.topAnchor.constraint(equalTo: estimateLabel.bottomAnchor, constant: 30),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func fetchAssetsAndProcess() {
        titleLabel.text = Strings.loadingPhotos
        countLabel.text = ""
        estimateLabel.text = ""

        let binnedSet = Set(DeleteBinStore.shared.loadAssetIds())
        let keptSet = Set(KeptAssetsStore.shared.loadAssetIds())
        let storedSet = Set(WillBeStoredStore.shared.loadAssetIds())

        Task {
            let fetchedAssets = await photoLibraryService.fetchPhotos(forMonthKey: monthKey, mediaType: mediaType)

            if self.config.isFilterResultMode {
                self.assets = fetchedAssets
            } else {
                self.assets = fetchedAssets.filter { asset in
                    let id = asset.localIdentifier
                    return !binnedSet.contains(id) && !keptSet.contains(id) && !storedSet.contains(id)
                }
            }

            await MainActor.run {
                self.countLabel.text = "0/\(self.assets.count)"
                self.titleLabel.text = self.config.titleText
                self.startProcessing()
            }
        }
    }

    private func startProcessing() {
        startTime = Date()

        let validAssets: [PHAsset]
        if config.isFilterResultMode {
            validAssets = assets
        } else {
            let binnedSet = Set(DeleteBinStore.shared.loadAssetIds())
            let keptSet = Set(KeptAssetsStore.shared.loadAssetIds())
            let storedSet = Set(WillBeStoredStore.shared.loadAssetIds())
            validAssets = assets.filter { asset in
                let id = asset.localIdentifier
                return !binnedSet.contains(id) && !keptSet.contains(id) && !storedSet.contains(id)
            }
        }

//        print(
//            "[PROCESSING DEBUG] startProcessing: \(assets.count) total assets, \(validAssets.count) after filtering binned/kept"
//        )
        estimateLabel.text = Strings.warmingUp

        processingTask = Task {
            let stream = await config.processAssets(validAssets)

            for await result in stream {
                switch result {
                case .progress(let progress):
                    await MainActor.run {
                        self.updateProgress(current: progress.current, total: progress.total)
                    }
                case .completed(let resultAssets):
                    await MainActor.run {
                        self.navigateToResults(with: resultAssets)
                    }
                case .cancelled:
                    break
                }
            }
        }
    }

    private func updateProgress(current: Int, total: Int) {
        let progress = Float(current) / Float(total)
        progressView.setProgress(progress, animated: true)
        countLabel.text = "\(current)/\(total)"

        if let startTime = startTime, current > 0 {
            let elapsed = Date().timeIntervalSince(startTime)
            let avgTime = elapsed / Double(current)
            let remaining = avgTime * Double(total - current)
            estimateLabel.text = Strings.estimateRemaining(seconds: remaining)
        }
    }

    // MARK: - Actions
    @objc private func handleCancel() {
        processingTask?.cancel()
        navigationController?.popViewController(animated: true)
    }

    private func navigateToResults(with filteredReviewAssets: [ReviewAsset]) {
//        print(
//            "[PROCESSING DEBUG] navigateToResults: passing \(filteredReviewAssets.count) assets, filterContext: \(config.filterContext), isFilterResultMode: \(config.isFilterResultMode)"
//        )
        let reviewVC = MonthReviewViewController(
            monthTitle: monthTitle,
            monthKey: monthKey,
            mediaType: mediaType,
            filterContext: config.filterContext
        )

        reviewVC.setPreComputedAssets(filteredReviewAssets)
        reviewVC.navigationSource = navigationSource

        if config.isFilterResultMode {
            reviewVC.isFilterResultMode = true
        }

        if let navController = navigationController {
            var viewControllers = navController.viewControllers
            viewControllers.removeLast()
            viewControllers.append(reviewVC)
            navController.setViewControllers(viewControllers, animated: true)
        }
    }
}

@available(iOS 17.0, *)
#Preview("Eyes Closed") {
    UINavigationController(
        rootViewController: ProcessingLoadingViewController(
            monthTitle: "January", monthKey: "2024-01", assets: [], mediaType: .image, config: .eyesClosed()))
}

@available(iOS 17.0, *)
#Preview("Large Files") {
    UINavigationController(
        rootViewController: ProcessingLoadingViewController(
            monthTitle: "February", monthKey: "2024-02", assets: [], mediaType: .image, config: .largeFiles()))
}
