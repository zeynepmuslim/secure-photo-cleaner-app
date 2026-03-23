//
//  StorageAnalysisBottomSheet.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 1.02.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let sheetTitle = "Storage Analysis"
    static let analyzing  = "Analyzing..."
    static func progressLabel(phase: String, progress: Int) -> String {
        "\(phase.capitalized)... \(progress)%"
    }
}

final class StorageAnalysisBottomSheet: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.sheetTitle
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var storageAnalysisView: StorageAnalysisView = {
        let view = StorageAnalysisView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let loadingContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let analysisProgressRing: AnalysisProgressRing = {
        let view = AnalysisProgressRing()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let analysisProgressLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.analyzing
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let storageManager = StorageAnalysisManager.shared
    private var hasLoadedContent = false

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        configureSheet()
    }

    private func configureSheet() {
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [
                    .custom { context in
                        return context.maximumDetentValue * 0.55
                    }
                ]
            } else {
                sheet.detents = [.medium()]
            }
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupConstraint()

        loadingContainerView.isHidden = false
        analysisProgressRing.startIndeterminate()
        analysisProgressLabel.text = Strings.analyzing
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasLoadedContent else { return }
        hasLoadedContent = true

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupStorageAnalysisViewDeferred()
            self.setupNotifications()
            self.updateSheetContent()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        view.backgroundColor = .mainBackground

        loadingContainerView.addSubview(analysisProgressRing)
        loadingContainerView.addSubview(analysisProgressLabel)

        view.addSubview(titleLabel)
        view.addSubview(loadingContainerView)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            loadingContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            loadingContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            loadingContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            loadingContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            analysisProgressRing.widthAnchor.constraint(equalToConstant: 48),
            analysisProgressRing.heightAnchor.constraint(equalToConstant: 48),
            analysisProgressRing.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            analysisProgressRing.centerYAnchor.constraint(equalTo: loadingContainerView.centerYAnchor, constant: -16),

            analysisProgressLabel.topAnchor.constraint(equalTo: analysisProgressRing.bottomAnchor, constant: 12),
            analysisProgressLabel.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            analysisProgressLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: loadingContainerView.leadingAnchor, constant: 16),
            analysisProgressLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: loadingContainerView.trailingAnchor, constant: -16)

        ])
    }

    private func setupStorageAnalysisViewDeferred() {
        storageAnalysisView.onRefreshTapped = { [weak self] in
            HapticFeedbackManager.shared.impact(intensity: .light)
            self?.storageManager.startAnalysis()
        }

        view.addSubview(storageAnalysisView)

        NSLayoutConstraint.activate([
            storageAnalysisView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            storageAnalysisView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            storageAnalysisView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageStateChanged),
            name: .storageAnalysisDidStart,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageStateChanged),
            name: .storageAnalysisDidFetchBasicInfo,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageStateChanged),
            name: .storageAnalysisDidComplete,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageStateChanged),
            name: .storageAnalysisDidFail,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProgressUpdate(_:)),
            name: .storageAnalysisDidUpdateProgress,
            object: nil
        )
    }

    private func updateSheetContent() {
        let state = storageManager.currentState

        switch state {
        case .loading, .loadingWithBasicInfo:
            loadingContainerView.isHidden = false
            storageAnalysisView.isHidden = true
            analysisProgressRing.startIndeterminate()
            analysisProgressLabel.text = Strings.analyzing

        case .loaded, .idle, .error:
            loadingContainerView.isHidden = true
            storageAnalysisView.isHidden = false
            storageAnalysisView.update(with: state)
        }
    }

    @objc private func storageStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.hasLoadedContent else { return }
            self.updateSheetContent()
        }
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
            self.analysisProgressRing.setProgress(CGFloat(progress) / 100.0)
            self.analysisProgressLabel.text = Strings.progressLabel(phase: phase, progress: progress)
        }
    }
}

// MARK: - Preview
@available(iOS 17.0, *)
#Preview {
    StorageAnalysisBottomSheet()
}
