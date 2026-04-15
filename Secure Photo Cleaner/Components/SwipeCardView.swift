//
//  SwipeCardView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 4.01.2026.
//

import UIKit

private enum Strings {
    static let enableInternetAccess = NSLocalizedString("swipeCard.enableInternetAccess", comment: "Enable internet access button")
    static let lowQuality = NSLocalizedString("swipeCard.lowQuality", comment: "Low quality badge label")
    static func iCloudNotDownloaded(mediaTypeName: String) -> String {
        String(format: NSLocalizedString("swipeCard.iCloudNotDownloaded", comment: "iCloud not downloaded title, e.g. 'iCloud Photo Not Downloaded'"), mediaTypeName)
    }
    static func iCloudSubtitle(mediaTypeName: String) -> String {
        String(format: NSLocalizedString("swipeCard.iCloudSubtitle", comment: "iCloud subtitle explaining download requirement"), mediaTypeName.lowercased())
    }
    static func contentUnavailableTitle(mediaTypeName: String) -> String {
        String(format: NSLocalizedString("swipeCard.contentUnavailableTitle", comment: "Content unavailable title, e.g. 'Photo Unavailable'"), mediaTypeName)
    }
    static func contentUnavailableSubtitle(mediaTypeName: String) -> String {
        String(format: NSLocalizedString("swipeCard.contentUnavailableSubtitle", comment: "Content unavailable message"), mediaTypeName.lowercased())
    }
}

final class SwipeCardView: UIView {

    enum PlaceholderState {
        case none
        case iCloudUnavailable
        case contentUnavailable
    }

    var hasImage: Bool {
        return imageView.image != nil
    }

    var onPlaceholderTap: (() -> Void)?
    var onICloudBadgeTap: (() -> Void)?
    var onEnableInternetTap: (() -> Void)?
    var onSkipTap: (() -> Void)?
    var assetIdentifier: String?
    var mediaType: MediaType = .photo

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.layer.cornerCurve = .continuous
        return imageView
    }()

    private let blurOverlay: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        return view
    }()

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.layer.cornerCurve = .continuous
        return imageView
    }()

    private let overlayView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        view.alpha = 0
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let placeholderContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .reviewCardBackground
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()

    private let placeholderIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "icloud.slash")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let placeholderTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let placeholderSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var enableInternetButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.configure(
            title: Strings.enableInternetAccess,
            systemImage: "network",
            style: .prominent,
            backgroundColor: .systemBlue,
            fontSize: 14,
            fontWeight: .semibold,
            iconSize: 14,
            contentInsets: NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 14)
        )
        button.addTarget(self, action: #selector(handleEnableInternetTap), for: .touchUpInside)
        return button
    }()

    private lazy var skipButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.configure(
            title: "Skip",
            systemImage: "chevron.right.2",
            style: .prominent,
            backgroundColor: .systemGray,
            fontSize: 14,
            fontWeight: .semibold,
            iconSize: 14,
            contentInsets: NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 14)
        )
        button.addTarget(self, action: #selector(handleSkipTap), for: .touchUpInside)
        return button
    }()

    private let placeholderStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }()

    private let sizeBadgeContainer: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.alpha = 0
        return view
    }()

    private let sizeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let iCloudBadgeContainer: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.alpha = 0
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }()

    private let iCloudIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "icloud")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let iCloudLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = Strings.lowQuality
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        return label
    }()

    private lazy var iCloudStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [iCloudIcon, iCloudLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {

        backgroundColor = .reviewCardBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8

        placeholderStack.addArrangedSubview(placeholderIcon)
        placeholderStack.addArrangedSubview(placeholderTitleLabel)
        placeholderStack.addArrangedSubview(placeholderSubtitleLabel)
        placeholderStack.addArrangedSubview(enableInternetButton)
        placeholderStack.addArrangedSubview(skipButton)

        let placeholderTap = UITapGestureRecognizer(target: self, action: #selector(handlePlaceholderTap))
        placeholderContainer.addGestureRecognizer(placeholderTap)

        let iCloudBadgeTap = UITapGestureRecognizer(target: self, action: #selector(handleICloudBadgeTap))
        iCloudBadgeContainer.addGestureRecognizer(iCloudBadgeTap)
        iCloudBadgeContainer.isUserInteractionEnabled = true

        addSubview(backgroundImageView)
        addSubview(blurOverlay)
        addSubview(imageView)
        addSubview(overlayView)

        addSubview(placeholderContainer)
        placeholderContainer.addSubview(placeholderStack)

        sizeBadgeContainer.contentView.addSubview(sizeLabel)
        addSubview(sizeBadgeContainer)

        iCloudBadgeContainer.contentView.addSubview(iCloudStack)
        addSubview(iCloudBadgeContainer)
    }

    private func setupConstraint() {
        let iCloudTopConstraint = iCloudBadgeContainer.topAnchor.constraint(equalTo: topAnchor, constant: 12)
        iCloudTopConstraint.priority = .defaultHigh

        let iCloudLeadingConstraint = iCloudBadgeContainer.leadingAnchor.constraint(
            equalTo: leadingAnchor, constant: 12)
        iCloudLeadingConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurOverlay.topAnchor.constraint(equalTo: topAnchor),
            blurOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),

            placeholderContainer.topAnchor.constraint(equalTo: topAnchor),
            placeholderContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            placeholderContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            placeholderIcon.widthAnchor.constraint(equalToConstant: 36),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 36),
            placeholderStack.centerXAnchor.constraint(equalTo: placeholderContainer.centerXAnchor),
            placeholderStack.centerYAnchor.constraint(equalTo: placeholderContainer.centerYAnchor),
            placeholderStack.leadingAnchor.constraint(
                greaterThanOrEqualTo: placeholderContainer.leadingAnchor, constant: 24),
            placeholderStack.trailingAnchor.constraint(
                lessThanOrEqualTo: placeholderContainer.trailingAnchor, constant: -24),

            skipButton.widthAnchor.constraint(equalTo: enableInternetButton.widthAnchor),

            sizeBadgeContainer.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            sizeBadgeContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            sizeBadgeContainer.heightAnchor.constraint(equalToConstant: 24),
            sizeBadgeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            sizeLabel.leadingAnchor.constraint(equalTo: sizeBadgeContainer.contentView.leadingAnchor, constant: 8),
            sizeLabel.trailingAnchor.constraint(equalTo: sizeBadgeContainer.contentView.trailingAnchor, constant: -8),
            sizeLabel.centerYAnchor.constraint(equalTo: sizeBadgeContainer.contentView.centerYAnchor),

            iCloudIcon.widthAnchor.constraint(equalToConstant: 18),
            iCloudIcon.heightAnchor.constraint(equalToConstant: 18),
            iCloudStack.leadingAnchor.constraint(equalTo: iCloudBadgeContainer.contentView.leadingAnchor, constant: 8),
            iCloudStack.trailingAnchor.constraint(
                equalTo: iCloudBadgeContainer.contentView.trailingAnchor, constant: -8),
            iCloudStack.centerYAnchor.constraint(equalTo: iCloudBadgeContainer.contentView.centerYAnchor),
            iCloudTopConstraint,
            iCloudLeadingConstraint,
            iCloudBadgeContainer.heightAnchor.constraint(equalToConstant: 32),
            iCloudBadgeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

    func configure(with image: UIImage?) {
        imageView.image = image
        backgroundImageView.image = image
        blurOverlay.isHidden = (image == nil)
    }

    func setPlaceholder(_ state: PlaceholderState) {
        switch state {
        case .none:
            placeholderContainer.isHidden = true
            placeholderTitleLabel.text = nil
            placeholderSubtitleLabel.text = nil
            placeholderIcon.image = UIImage(systemName: "icloud.slash")
            enableInternetButton.isHidden = true
            skipButton.isHidden = true
        case .iCloudUnavailable:
            placeholderIcon.image = UIImage(systemName: "icloud.slash")
            placeholderTitleLabel.text = Strings.iCloudNotDownloaded(mediaTypeName: mediaType.displayName)
            placeholderSubtitleLabel.text = Strings.iCloudSubtitle(mediaTypeName: mediaType.displayName)
            enableInternetButton.isHidden = false
            skipButton.isHidden = false
            placeholderContainer.isHidden = false
        case .contentUnavailable:
            placeholderIcon.image = UIImage(systemName: mediaType == .video ? "video.slash" : "photo")
            placeholderTitleLabel.text = Strings.contentUnavailableTitle(mediaTypeName: mediaType.displayName)
            placeholderSubtitleLabel.text = Strings.contentUnavailableSubtitle(mediaTypeName: mediaType.displayName)
            enableInternetButton.isHidden = false
            skipButton.isHidden = true
            placeholderContainer.isHidden = false
        }
    }

    @objc private func handlePlaceholderTap() {
        onPlaceholderTap?()
    }

    @objc private func handleICloudBadgeTap() {
        onICloudBadgeTap?()
    }

    @objc private func handleEnableInternetTap() {
        onEnableInternetTap?()
    }

    @objc private func handleSkipTap() {
        onSkipTap?()
    }

    func configureSize(_ sizeString: String?) {
        if let text = sizeString, !text.isEmpty {
            sizeLabel.text = text
            sizeBadgeContainer.alpha = 1.0
        } else {
            sizeLabel.text = nil
            sizeBadgeContainer.alpha = 0
        }
    }

    func setBadgeAlpha(_ alpha: CGFloat) {
        if sizeLabel.text != nil {
            sizeBadgeContainer.alpha = alpha
        }
    }

    var isPlaceholderVisible: Bool {
        !placeholderContainer.isHidden
    }

    var isICloudBadgeVisible: Bool {
        iCloudBadgeContainer.alpha > 0
    }

    func setICloudBadgeVisible(_ visible: Bool) {
        iCloudBadgeContainer.alpha = visible ? 1.0 : 0
    }

    func embedVideoLayer(_ videoLayer: CALayer) {
        videoLayer.frame = bounds
        layer.insertSublayer(videoLayer, above: imageView.layer)
    }

    func reset() {
        imageView.image = nil
        backgroundImageView.image = nil
        blurOverlay.isHidden = true
        assetIdentifier = nil

        transform = .identity
        alpha = 1.0
        overlayView.alpha = 0
        placeholderContainer.isHidden = true

        sizeLabel.text = nil
        sizeBadgeContainer.alpha = 0
        iCloudBadgeContainer.alpha = 0

        imageView.setNeedsLayout()
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct SwipeCardViewPreview: View {
        let configure: (SwipeCardView) -> Void

        var body: some View {
            SwipeCardViewPreviewRepresentable(configure: configure)
                .frame(width: 280, height: 360)
                .padding()
                .background(Color(UIColor.systemBackground))
        }
    }

    @available(iOS 17.0, *)
    private struct SwipeCardViewPreviewRepresentable: UIViewRepresentable {
        let configure: (SwipeCardView) -> Void

        func makeUIView(context: Context) -> SwipeCardView {
            let view = SwipeCardView(frame: .zero)
            configure(view)
            return view
        }

        func updateUIView(_ uiView: SwipeCardView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Card - Image") {
        SwipeCardViewPreview { view in
            view.configure(with: UIImage(systemName: "photo"))
            view.configureSize("2.4 MB")
        }
    }

    @available(iOS 17.0, *)
    #Preview("Card - iCloud Low Quality") {
        SwipeCardViewPreview { view in
            view.configure(with: UIImage(systemName: "photo.fill"))
            view.setICloudBadgeVisible(true)
            view.configureSize("3.1 MB")
        }
    }

    @available(iOS 17.0, *)
    #Preview("Card - iCloud Unavailable") {
        SwipeCardViewPreview { view in
            view.configure(with: nil)
            view.setPlaceholder(.iCloudUnavailable)
            view.configureSize("3.1 MB")
        }
    }

    @available(iOS 17.0, *)
    #Preview("Card - Unavailable") {
        SwipeCardViewPreview { view in
            view.configure(with: nil)
            view.setPlaceholder(.contentUnavailable)
            view.configureSize("1.2 MB")
        }
    }
#endif
