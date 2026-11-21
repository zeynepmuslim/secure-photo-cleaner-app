//
//  SimilarHelpSampleCardView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let store = NSLocalizedString("similarHelp.store", comment: "Store action label")
    static let storeDone = NSLocalizedString("similarGroup.storeDone", comment: "Store button while store mode is on")
    static let confirm = NSLocalizedString("similarPhotos.confirm", comment: "Confirm button")
    static let keep = NSLocalizedString("similarHelp.keep", comment: "Keep action label")
    static let delete = NSLocalizedString("similarHelp.delete", comment: "Delete action label")
    static let sampleTitle = String(
        format: NSLocalizedString("similarGroup.setTitle", comment: "Set title with number, e.g. 'Set #1'"), 1)
    static func sampleMeta(count: Int, size: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("similarGroup.subtitle", comment: "A set's photo count and size, e.g. '4 photos · 14.2 MB'"),
            count, size)
    }
    static func photoAccessibility(number: Int, state: SimilarPhotoState) -> String {
        let stateName: String
        switch state {
        case .keep: stateName = keep
        case .delete: stateName = delete
        case .store: stateName = store
        }
        return String(
            format: NSLocalizedString(
                "similarHelp.photoAccessibility", comment: "VoiceOver: a sample photo and its mark, e.g. 'Photo 2, Keep'"),
            number, stateName)
    }
}

/// The help sheet's sample set (board "Similar photos · help sheet · keep, bin and store
/// targets"): the real set card's look with four drawn photos. It works like the real card
/// (tap to switch keep and delete, Store mode, Confirm) but is local to the sheet: nothing
/// reaches PhotoKit or the stores. While nobody touches it, the second photo hops through the
/// three marks; a touch pauses the loop and puts the photo back on the user's own mark, and a
/// few idle seconds later the loop picks up again from the marks the user left.
final class SimilarHelpSampleCardView: UIView {

    /// What the user has done with the sample, for the sheet's hints
    enum SampleStep {
        /// A photo switched keep ↔ delete
        case toggled
        /// A photo went to the store box
        case stored
        case confirmed
    }

    private enum Layout {
        static let padding = GeneralConstants.EdgePadding.cardInner
        static let bottomPadding: CGFloat = 16
        static let stampSize = CGSize(width: 12, height: 30)
        static let stampCapsuleWidth: CGFloat = 10
        static let stampToText: CGFloat = 12
        static let pillHeight: CGFloat = 34
        static let pillInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        static let pillFontSize: CGFloat = 14
        static let pillIconSize: CGFloat = 12
        static let headerToPhotos: CGFloat = 12
        static let photosToFooter: CGFloat = 14
        static let minimumThumbnailSpacing: CGFloat = 8
        static let minimumThumbnailSide: CGFloat = 44
        static let chipSpacing: CGFloat = 12

        static let idleInterval: TimeInterval = 1.4
        /// How long the card waits after the last touch before the loop starts again (its first
        /// hop lands one `idleInterval` later, about 4.4 s after the touch)
        static let idleResumeDelay: TimeInterval = 3
        static let hopHeight: CGFloat = 12
        static let hopDuration: TimeInterval = 0.34
        static let hopDamping: CGFloat = 0.6
        static let pressScale: CGFloat = 0.9
        static let pressDuration: TimeInterval = 0.15
        /// The photo the idle loop plays with
        static let idleIndex = 1
        static let sampleBytes: Int64 = 14_200_000
    }

    /// The four drawn photos: a top, middle and bottom color and the gradient's angle (board values)
    private static let tiles: [(colors: [UInt32], angle: CGFloat)] = [
        ([0x9DB9D8, 0x5C7FA8, 0xE9E2C8], 150),
        ([0xC8D9B0, 0x6E9A55, 0x3F5E36], 170),
        ([0xF2C9A0, 0xD9895A, 0x7A4A3A], 190),
        ([0xB9C7D6, 0x7F93A8, 0xD8E0E8], 210)
    ]

    private static let defaultStates: [SimilarPhotoState] = [.keep, .keep, .delete, .delete]

    // MARK: - Callbacks

    /// The user did one of the sample's steps
    var onStep: ((SampleStep) -> Void)?
    var onConfirm: (() -> Void)?

    // MARK: - State

    /// The marks on screen: the user's marks, with the idle loop's mark on the photo it plays with
    private(set) var states = SimilarHelpSampleCardView.defaultStates
    /// The user's own marks; the idle loop never changes them
    private var userStates = SimilarHelpSampleCardView.defaultStates
    private var isStoreMode = false
    private var isTouching = false
    private var isFinished = false
    private var isIdleLoopRunning = false
    private var idleWorkItem: DispatchWorkItem?
    private var resumeWorkItem: DispatchWorkItem?
    private var appliedThumbnailSide: CGFloat = 0

    /// The photos' largest side; the sheet lowers it to 60 when it's short on height
    var maximumThumbnailSide: CGFloat = 72 {
        didSet { if maximumThumbnailSide != oldValue { setNeedsLayout() } }
    }

    var counts: (kept: Int, deleted: Int, stored: Int) {
        (states.filter { $0 == .keep }.count,
         states.filter { $0 == .delete }.count,
         states.filter { $0 == .store }.count)
    }

    // MARK: - Views

    private let stampView: ReviewStampView = {
        let view = ReviewStampView()
        view.capsuleWidth = Layout.stampCapsuleWidth
        view.status = .notStarted
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.sampleTitle
        label.font = ThemeManager.Fonts.titleFont(size: 16, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 1
        stack.isAccessibilityElement = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var storeButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(self, action: #selector(handleStoreToggle), for: .touchUpInside)
        return button
    }()

    private lazy var confirmButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        return button
    }()

    private let photosStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// The four sample photos, leading first
    private(set) var thumbnailViews: [SimilarPhotoThumbnailView] = []
    private var thumbnailSizeConstraints: [NSLayoutConstraint] = []
    private var photosHeightConstraint: NSLayoutConstraint?

    private let chipsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Layout.chipSpacing
        stack.alignment = .center
        stack.isAccessibilityElement = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let keepChip = SimilarSetCardView.makeChip(for: .keep)
    private let deleteChip = SimilarSetCardView.makeChip(for: .delete)
    private let storeChip = SimilarSetCardView.makeChip(for: .store)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
        setupTouchRecognizer()
        applyStoreButtonStyle(highlighted: false, animated: false)
        applyStates(animatedIndex: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous

        metaLabel.text = Strings.sampleMeta(
            count: Self.tiles.count, size: Layout.sampleBytes.formattedBytes())
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(metaLabel)
        textStack.accessibilityLabel = [titleLabel.text, metaLabel.text].compactMap { $0 }.joined(separator: ", ")

        for (index, tile) in Self.tiles.enumerated() {
            let thumbnail = SimilarPhotoThumbnailView()
            thumbnail.translatesAutoresizingMaskIntoConstraints = false
            thumbnail.image = Self.makeTileImage(colors: tile.colors, angle: tile.angle)
            thumbnail.grayscaleCacheKey = "similarHelp.tile.\(index)"
            thumbnail.tag = index
            thumbnail.isAccessibilityElement = true
            thumbnail.accessibilityTraits = .button
            thumbnail.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handlePhotoTap(_:))))
            thumbnailViews.append(thumbnail)
            photosStack.addArrangedSubview(thumbnail)
        }

        [keepChip, deleteChip, storeChip].forEach { chipsStack.addArrangedSubview($0.view) }

        confirmButton.configure(
            title: Strings.confirm,
            style: .regular,
            backgroundColor: .systemGray5,
            foregroundColor: .label,
            fontSize: Layout.pillFontSize,
            contentInsets: Layout.pillInsets)

        addSubview(stampView)
        addSubview(textStack)
        addSubview(storeButton)
        addSubview(photosStack)
        addSubview(chipsStack)
        addSubview(confirmButton)

        accessibilityElements = [textStack, storeButton] + thumbnailViews + [confirmButton]
    }

    private func setupConstraint() {
        let side = maximumThumbnailSide
        for thumbnail in thumbnailViews {
            let width = thumbnail.widthAnchor.constraint(equalToConstant: side)
            let height = thumbnail.heightAnchor.constraint(equalToConstant: side)
            thumbnailSizeConstraints += [width, height]
        }
        appliedThumbnailSide = side
        // The row keeps the largest photo's height, so a hop never moves the footer
        let photosHeight = photosStack.heightAnchor.constraint(equalToConstant: side)
        photosHeightConstraint = photosHeight

        NSLayoutConstraint.activate(thumbnailSizeConstraints + [
            storeButton.topAnchor.constraint(equalTo: topAnchor, constant: Layout.padding),
            storeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.padding),
            storeButton.heightAnchor.constraint(equalToConstant: Layout.pillHeight),

            stampView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.padding),
            stampView.centerYAnchor.constraint(equalTo: storeButton.centerYAnchor),
            stampView.widthAnchor.constraint(equalToConstant: Layout.stampSize.width),
            stampView.heightAnchor.constraint(equalToConstant: Layout.stampSize.height),

            textStack.leadingAnchor.constraint(equalTo: stampView.trailingAnchor, constant: Layout.stampToText),
            textStack.centerYAnchor.constraint(equalTo: storeButton.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: storeButton.leadingAnchor, constant: -8),

            photosStack.topAnchor.constraint(equalTo: storeButton.bottomAnchor, constant: Layout.headerToPhotos),
            photosStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.padding),
            photosStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.padding),
            photosHeight,

            confirmButton.topAnchor.constraint(equalTo: photosStack.bottomAnchor, constant: Layout.photosToFooter),
            confirmButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.padding),
            confirmButton.heightAnchor.constraint(equalToConstant: Layout.pillHeight),
            confirmButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.bottomPadding),

            chipsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.padding),
            chipsStack.centerYAnchor.constraint(equalTo: confirmButton.centerYAnchor),
            chipsStack.trailingAnchor.constraint(lessThanOrEqualTo: confirmButton.leadingAnchor, constant: -8)
        ])
    }

    /// Any touch in the card pauses the idle loop; lifting the finger arms its resume. It
    /// doesn't take the touch from the controls.
    private func setupTouchRecognizer() {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleTouch(_:)))
        recognizer.minimumPressDuration = 0
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = self
        addGestureRecognizer(recognizer)
    }

    private static func makeTileImage(colors: [UInt32], angle: CGFloat) -> UIImage {
        let size = CGSize(width: 144, height: 144)
        let cgColors = colors.map { hex in
            UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1
            ).cgColor
        }
        return UIGraphicsImageRenderer(size: size).image { context in
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors as CFArray, locations: [0, 0.6, 1])
            else { return }
            // A CSS angle: 180° runs top to bottom
            let radians = angle * .pi / 180
            let direction = CGVector(dx: sin(radians), dy: -cos(radians))
            let half = size.width / 2
            let center = CGPoint(x: half, y: half)
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: center.x - direction.dx * half, y: center.y - direction.dy * half),
                end: CGPoint(x: center.x + direction.dx * half, y: center.y + direction.dy * half),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    // MARK: - Layout

    /// The photos' side for a card this wide: four across with at least 8pt between them.
    static func thumbnailSide(forCardWidth width: CGFloat, maximum: CGFloat) -> CGFloat {
        let available = width - 2 * Layout.padding - 3 * Layout.minimumThumbnailSpacing
        guard available > 0 else { return Layout.minimumThumbnailSide }
        return max(Layout.minimumThumbnailSide, min(maximum, floor(available / 4)))
    }

    /// Sizes the photos for a width before the card is measured.
    func prepareLayout(forWidth width: CGFloat) {
        let side = Self.thumbnailSide(forCardWidth: width, maximum: maximumThumbnailSide)
        guard side != appliedThumbnailSide else { return }
        appliedThumbnailSide = side
        thumbnailSizeConstraints.forEach { $0.constant = side }
        photosHeightConstraint?.constant = side
    }

    override func layoutSubviews() {
        prepareLayout(forWidth: bounds.width)
        super.layoutSubviews()
    }

    // MARK: - Appearance

    private func applyStoreButtonStyle(highlighted: Bool, animated: Bool) {
        let apply = {
            let foreground: UIColor = highlighted ? .inkOnYellow : .label
            let icon = UIImage(
                systemName: "archivebox.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.pillIconSize, weight: .semibold))?
                .withTintColor(highlighted ? .inkOnYellow : ThemeManager.Colors.statusYellow, renderingMode: .alwaysOriginal)
            self.storeButton.configure(
                title: self.isStoreMode ? Strings.storeDone : Strings.store,
                image: icon,
                style: highlighted ? .prominent : .regular,
                backgroundColor: highlighted ? ThemeManager.Colors.statusYellow : .systemGray5,
                foregroundColor: foreground,
                fontSize: Layout.pillFontSize,
                contentInsets: Layout.pillInsets)
        }
        guard animated, window != nil else {
            apply()
            return
        }
        UIView.transition(
            with: storeButton, duration: 0.15,
            options: [.transitionCrossDissolve, .allowUserInteraction], animations: apply)
    }

    /// Shows `states` on the photos and the chips; `animatedIndex` cross-dissolves that photo.
    private func applyStates(animatedIndex: Int?) {
        for (index, thumbnail) in thumbnailViews.enumerated() {
            thumbnail.applyState(states[index], animated: index == animatedIndex)
            thumbnail.accessibilityLabel = Strings.photoAccessibility(number: index + 1, state: states[index])
        }
        let (kept, deleted, stored) = counts
        keepChip.label.text = "\(kept)"
        deleteChip.label.text = "\(deleted)"
        storeChip.label.text = "\(stored)"
        keepChip.view.isHidden = kept == 0
        deleteChip.view.isHidden = deleted == 0
        storeChip.view.isHidden = stored == 0
    }

    // MARK: - Idle loop

    /// Starts the hop of the second photo, from the mark it shows now (the user's own). Never
    /// after Confirm, with Reduce Motion or with VoiceOver.
    func startIdleLoop() {
        guard !isFinished, !isIdleLoopRunning, !isTouching, !isStoreMode,
              !UIAccessibility.isReduceMotionEnabled, !UIAccessibility.isVoiceOverRunning else { return }
        isIdleLoopRunning = true
        scheduleIdleStep()
    }

    /// Pauses the loop (a touch, or the sheet leaving the screen) and drops a pending resume.
    func pauseIdleLoop() {
        isIdleLoopRunning = false
        idleWorkItem?.cancel()
        idleWorkItem = nil
        cancelResume()
    }

    private func scheduleIdleStep() {
        let item = DispatchWorkItem { [weak self] in self?.performIdleStep() }
        idleWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.idleInterval, execute: item)
    }

    private func performIdleStep() {
        guard isIdleLoopRunning else { return }
        let index = Layout.idleIndex
        switch states[index] {
        case .keep: states[index] = .delete
        case .delete: states[index] = .store
        case .store: states[index] = .keep
        }

        let thumbnail = thumbnailViews[index]
        UIView.animate(withDuration: Layout.hopDuration * 0.4, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            thumbnail.transform = CGAffineTransform(translationX: 0, y: -Layout.hopHeight)
        } completion: { _ in
            UIView.animate(
                withDuration: Layout.hopDuration, delay: 0, usingSpringWithDamping: Layout.hopDamping,
                initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                thumbnail.transform = .identity
            }
        }
        applyStates(animatedIndex: index)
        applyStoreButtonStyle(highlighted: states[index] == .store, animated: true)
        scheduleIdleStep()
    }

    /// Stops the loop while the user plays with the card. The hopping photo goes back to the
    /// user's own mark, except for a touch on Confirm, which keeps the marks on screen, so what
    /// gets confirmed is what was showing.
    private func pauseForInteraction(keepsShownMarks: Bool) {
        let wasRunning = isIdleLoopRunning
        pauseIdleLoop()

        let index = Layout.idleIndex
        if keepsShownMarks {
            userStates[index] = states[index]
        } else if states[index] != userStates[index] {
            states[index] = userStates[index]
            applyStates(animatedIndex: index)
        }
        if wasRunning, !isStoreMode {
            applyStoreButtonStyle(highlighted: false, animated: true)
        }
    }

    /// The loop picks up again once the card has been left alone for a while; not mid-touch,
    /// in Store mode (the user is choosing photos) or after Confirm.
    private func scheduleResume() {
        cancelResume()
        guard !isFinished, !isTouching, !isStoreMode else { return }
        let item = DispatchWorkItem { [weak self] in self?.startIdleLoop() }
        resumeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.idleResumeDelay, execute: item)
    }

    private func cancelResume() {
        resumeWorkItem?.cancel()
        resumeWorkItem = nil
    }

    // MARK: - Actions

    @objc private func handleTouch(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            isTouching = true
            let onConfirm = confirmButton.frame.contains(recognizer.location(in: self))
            pauseForInteraction(keepsShownMarks: onConfirm)
        case .ended, .cancelled, .failed:
            isTouching = false
            scheduleResume()
        default:
            break
        }
    }

    @objc private func handlePhotoTap(_ recognizer: UITapGestureRecognizer) {
        guard let index = recognizer.view?.tag, userStates.indices.contains(index) else { return }
        pauseForInteraction(keepsShownMarks: false)

        let step: SampleStep?
        if isStoreMode {
            userStates[index] = userStates[index] == .store ? Self.defaultStates[index] : .store
            step = userStates[index] == .store ? .stored : nil
        } else {
            switch userStates[index] {
            case .keep, .store: userStates[index] = .delete
            case .delete: userStates[index] = .keep
            }
            step = .toggled
        }
        states[index] = userStates[index]
        HapticFeedbackManager.shared.selection()
        applyStates(animatedIndex: index)
        UIAccessibility.post(notification: .layoutChanged, argument: thumbnailViews[index])
        if let step { onStep?(step) }
        // A quick tap can end before the touch recognizer begins; the tap arms the resume itself
        scheduleResume()
    }

    @objc private func handleStoreToggle() {
        pauseForInteraction(keepsShownMarks: false)
        isStoreMode.toggle()
        applyStoreButtonStyle(highlighted: isStoreMode, animated: true)
        thumbnailViews.forEach { isStoreMode ? $0.startShake() : $0.stopShake() }
        HapticFeedbackManager.shared.impact(intensity: isStoreMode ? .medium : .light)
        // Leaving Store mode lets the loop come back after the usual pause
        scheduleResume()
    }

    @objc private func handleConfirm() {
        pauseForInteraction(keepsShownMarks: true)
        isFinished = true
        if isStoreMode {
            isStoreMode = false
            thumbnailViews.forEach { $0.stopShake() }
        }
        applyStoreButtonStyle(highlighted: false, animated: true)
        // The demo runs once: nothing in the card answers after Confirm
        isUserInteractionEnabled = false
        accessibilityElements = [textStack]
        onStep?(.confirmed)
        onConfirm?()
    }

    // MARK: - Confirm animation hooks

    /// The Confirm pill's press: down to 0.9 and back.
    func pressConfirmButton() {
        let button = confirmButton
        UIView.animate(withDuration: Layout.pressDuration / 2, delay: 0, options: .curveEaseOut) {
            button.transform = CGAffineTransform(scaleX: Layout.pressScale, y: Layout.pressScale)
        } completion: { _ in
            UIView.animate(withDuration: Layout.pressDuration / 2, delay: 0, options: .curveEaseIn) {
                button.transform = .identity
            }
        }
    }

    /// The dashed capsule becomes the stamp; animated, it springs in from 0.6 with a slight overshoot.
    func setStamped(animated: Bool) {
        stampView.status = .done
        guard animated else { return }
        stampView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        UIView.animate(
            withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8
        ) {
            self.stampView.transform = .identity
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension SimilarHelpSampleCardView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    private struct SimilarHelpSampleCardPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> SimilarHelpSampleCardView {
            SimilarHelpSampleCardView()
        }

        func updateUIView(_ uiView: SimilarHelpSampleCardView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Sample set") {
        SimilarHelpSampleCardPreview()
            .frame(height: 200)
            .padding(24)
    }
#endif
