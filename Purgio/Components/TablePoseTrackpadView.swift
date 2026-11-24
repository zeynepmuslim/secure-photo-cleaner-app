//
//  TablePoseTrackpadView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

/// A rounded white tray with a dashed swipe pad and the three directions around it: Store
/// (archivebox, yellow) on top, Delete (trash, red) on the left, Keep (checkmark, green) on the
/// right, a hint at the bottom. The sides are physical, like the drag (forced left-to-right).
/// MonthReview shows it on the base in the iPhone Duo table layout: `panGesture` drives the raised card exactly like a direct swipe. A mini box at the
/// top card's aspect ratio sits in the pad (`setPreview`) and follows its drag (`setPreviewTransform`).
final class TablePoseTrackpadView: UIView {

    /// VoiceOver custom actions (a drag can't be performed there).
    var onStore: (() -> Void)?
    var onDelete: (() -> Void)?
    var onKeep: (() -> Void)?

    /// Covers the whole tray, labels included; its owner adds the target.
    let panGesture = UIPanGestureRecognizer()

    private enum Layout {
        static let edgeInset: CGFloat = 18
        static let sideColumnWidth: CGFloat = 64
        static let padSpacing: CGFloat = 12
        static let padCornerRadius: CGFloat = 26
        static let dashPattern: [NSNumber] = [6, 5]
        /// Largest share of the pad the mini card takes, and its inner margin.
        static let previewMaxFraction: CGFloat = 0.6
        static let previewInset: CGFloat = 12
        static let previewCornerRadius: CGFloat = 10
        static let previewBorderWidth: CGFloat = 1
        /// The next mini card grows in from this scale, a little below the middle.
        static let previewEntryScale: CGFloat = 0.7
        static let previewEntryOffset: CGFloat = 10
    }

    private let previewCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.layer.borderWidth = Layout.previewBorderWidth
        view.layer.cornerRadius = Layout.previewCornerRadius
        view.layer.cornerCurve = .continuous
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }()

    private var previewAspectRatio: CGFloat = 1
    private var previewIdentifier: String?
    /// While the next mini card grows in, a resting card transform (identity) doesn't cut it short.
    private var isPreviewEntering = false

    private let padView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .quaternarySystemFill
        view.layer.cornerRadius = Layout.padCornerRadius
        view.layer.cornerCurve = .continuous
        view.isUserInteractionEnabled = false
        // The mini card slides out of the pad on a swipe
        view.clipsToBounds = true
        return view
    }()

    private let padBorderLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 1.5
        layer.lineDashPattern = Layout.dashPattern
        return layer
    }()

    private lazy var storeLabel = makeDirectionLabel(
        systemImage: "archivebox", iconSize: 18, color: ThemeManager.Colors.statusYellow, axis: .horizontal)
    private lazy var deleteLabel = makeDirectionLabel(
        systemImage: "trash", iconSize: 22, color: ThemeManager.Colors.statusRed, axis: .vertical)
    private lazy var keepLabel = makeDirectionLabel(
        systemImage: "checkmark", iconSize: 24, color: ThemeManager.Colors.statusGreen, axis: .vertical)

    private let hintLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
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
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.ActionGrip.trayCornerRadius
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = GeneralConstants.ActionGrip.Shadow.opacity
        layer.shadowOffset = CGSize(width: 0, height: GeneralConstants.ActionGrip.Shadow.offsetY)
        layer.shadowRadius = GeneralConstants.ActionGrip.Shadow.radius

        addSubview(padView)
        padView.layer.addSublayer(padBorderLayer)
        padView.addSubview(previewCardView)
        [storeLabel, deleteLabel, keepLabel].forEach { addSubview($0.stack) }
        addSubview(hintLabel)
        addGestureRecognizer(panGesture)

        // A drag's direction is physical (right keeps, left deletes, like the card), so the labels
        // stay put in right-to-left languages too: Delete on the left, Keep on the right
        ([self] + subviews + [storeLabel.stack, deleteLabel.stack, keepLabel.stack].flatMap(\.arrangedSubviews))
            .forEach { $0.semanticContentAttribute = .forceLeftToRight }

        // One VoiceOver element with an action per direction
        isAccessibilityElement = true
        updateBorderColor()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
                (self: TablePoseTrackpadView, _: UITraitCollection) in
                self.updateBorderColor()
            }
        }
    }

    private func setupConstraint() {
        let inset = Layout.edgeInset
        NSLayoutConstraint.activate([
            storeLabel.stack.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            storeLabel.stack.centerXAnchor.constraint(equalTo: centerXAnchor),

            hintLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            hintLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),

            deleteLabel.stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            deleteLabel.stack.widthAnchor.constraint(equalToConstant: Layout.sideColumnWidth),
            deleteLabel.stack.centerYAnchor.constraint(equalTo: padView.centerYAnchor),

            keepLabel.stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            keepLabel.stack.widthAnchor.constraint(equalToConstant: Layout.sideColumnWidth),
            keepLabel.stack.centerYAnchor.constraint(equalTo: padView.centerYAnchor),

            padView.topAnchor.constraint(equalTo: storeLabel.stack.bottomAnchor, constant: Layout.padSpacing),
            padView.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -Layout.padSpacing),
            padView.leadingAnchor.constraint(equalTo: deleteLabel.stack.trailingAnchor, constant: Layout.padSpacing),
            padView.trailingAnchor.constraint(equalTo: keepLabel.stack.leadingAnchor, constant: -Layout.padSpacing)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        padBorderLayer.frame = padView.bounds
        padBorderLayer.path = UIBezierPath(
            roundedRect: padView.bounds.insetBy(dx: 0.75, dy: 0.75),
            cornerRadius: Layout.padCornerRadius).cgPath
        layoutPreview()
    }

    /// The mini card is an overlay that moves with a transform, so it's placed with bounds and center.
    private func layoutPreview() {
        let available = padView.bounds.insetBy(dx: Layout.previewInset, dy: Layout.previewInset).size
        guard available.width > 0, available.height > 0 else { return }
        let maxSize = CGSize(
            width: available.width * Layout.previewMaxFraction,
            height: available.height * Layout.previewMaxFraction)
        let ratio = max(previewAspectRatio, 0.1)
        let width = floor(min(maxSize.width, maxSize.height * ratio))
        previewCardView.bounds = CGRect(x: 0, y: 0, width: width, height: floor(width / ratio))
        previewCardView.center = CGPoint(x: padView.bounds.midX, y: padView.bounds.midY)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
        }
    }

    private func updateBorderColor() {
        padBorderLayer.strokeColor = UIColor.systemGray4.resolvedColor(with: traitCollection).cgColor
        previewCardView.layer.borderColor = UIColor.systemGray3.resolvedColor(with: traitCollection).cgColor
    }

    // MARK: - Configuration

    func configure(storeTitle: String, deleteTitle: String, keepTitle: String, areaTitle: String, hint: String) {
        storeLabel.title.text = storeTitle
        deleteLabel.title.text = deleteTitle
        keepLabel.title.text = keepTitle
        hintLabel.text = hint

        accessibilityLabel = areaTitle
        accessibilityHint = hint
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: deleteTitle) { [weak self] _ in
                self?.onDelete?()
                return true
            },
            UIAccessibilityCustomAction(name: keepTitle) { [weak self] _ in
                self?.onKeep?()
                return true
            },
            UIAccessibilityCustomAction(name: storeTitle) { [weak self] _ in
                self?.onStore?()
                return true
            }
        ]
    }

    // MARK: - Preview

    /// Shows a mini box at the top card's aspect ratio (width / height). A new identifier (the
    /// next asset) starts back in the middle and fades in; nil hides it.
    func setPreview(aspectRatio: CGFloat?, identifier: String?) {
        if let ratio = aspectRatio, ratio > 0, ratio != previewAspectRatio {
            previewAspectRatio = ratio
            setNeedsLayout()
        }
        guard identifier != previewIdentifier else { return }
        previewIdentifier = identifier
        guard identifier != nil else {
            previewCardView.isHidden = true
            return
        }
        // The next card rises into the middle with a soft spring as the old one leaves
        isPreviewEntering = true
        UIView.performWithoutAnimation {
            previewCardView.layer.removeAllAnimations()
            previewCardView.alpha = 0
            previewCardView.isHidden = false
            layoutIfNeeded()
            previewCardView.transform = CGAffineTransform(translationX: 0, y: Layout.previewEntryOffset)
                .scaledBy(x: Layout.previewEntryScale, y: Layout.previewEntryScale)
        }
        UIView.animate(
            withDuration: 0.4, delay: 0.05, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.previewCardView.alpha = 1
            self.previewCardView.transform = .identity
        } completion: { _ in
            self.isPreviewEntering = false
        }
    }

    /// Moves the mini card like the real one: the same turn, the translation scaled down by the
    /// mini card's size relative to the card's width.
    func setPreviewTransform(_ cardTransform: CGAffineTransform, cardWidth: CGFloat) {
        guard cardWidth > 0, previewCardView.bounds.width > 0 else { return }
        // The entry spring already ends at rest; a drag that starts during it takes over
        if isPreviewEntering {
            guard !cardTransform.isIdentity else { return }
            isPreviewEntering = false
            previewCardView.layer.removeAllAnimations()
            previewCardView.alpha = 1
        }
        let scale = previewCardView.bounds.width / cardWidth
        var transform = cardTransform
        transform.tx *= scale
        transform.ty *= scale
        previewCardView.transform = transform
    }

    /// Ends a drag in progress with `.cancelled` (e.g. the pose changed under the finger).
    func cancelActiveDrag() {
        guard panGesture.state == .began || panGesture.state == .changed else { return }
        panGesture.isEnabled = false
        panGesture.isEnabled = true
    }


    // MARK: - Builders

    private func makeDirectionLabel(
        systemImage: String, iconSize: CGFloat, color: UIColor, axis: NSLayoutConstraint.Axis
    ) -> (stack: UIStackView, title: UILabel) {
        let icon = UIImageView(image: UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)))
        icon.tintColor = color
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.font = .systemFont(ofSize: 13, weight: .bold)
        title.textColor = .label
        title.textAlignment = .center
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.7

        let stack = UIStackView(arrangedSubviews: [icon, title])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = axis
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        return (stack, title)
    }

}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct TablePoseTrackpadPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> TablePoseTrackpadView {
            let trackpad = TablePoseTrackpadView()
            trackpad.configure(
                storeTitle: "Store", deleteTitle: "Delete", keepTitle: "Keep", areaTitle: "Swipe area",
                hint: "Swipe here · the photo above follows your finger")
            trackpad.setPreview(aspectRatio: 4.0 / 3.0, identifier: "preview")
            return trackpad
        }

        func updateUIView(_ uiView: TablePoseTrackpadView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Table pose trackpad") {
        TablePoseTrackpadPreview().frame(width: 545, height: 361)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
#endif
