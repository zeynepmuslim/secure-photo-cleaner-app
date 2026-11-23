//
//  PhotoGrowPresenter.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.11.2026.
//

import UIKit

/// Grows an image out of a view into a large rounded photo over a blur on the window; a tap
/// anywhere (or the optional close button) shrinks it back. The grown photo follows the window:
/// it is placed again whenever the overlay lays out (rotation, cover ↔ inner display) or the
/// host calls `relayout()` (the fold's state changed). The host owns one, hides its source view in `onWillShow` and shows
/// it again in `onDidDismiss`, and dismisses without animation when the source leaves its window.
/// Used by `PrivacyShieldArtView` (its sample photos) and `HistoryDetailBottomSheet` (its media card).
final class PhotoGrowPresenter: NSObject {

    private enum Timing {
        static let grow: TimeInterval = 0.4
        static let shrink: TimeInterval = 0.3
        static let reducedMotionFade: TimeInterval = 0.25
        static let imageSwap: TimeInterval = 0.2
    }

    private enum Layout {
        /// Kept clear between the close button and the grown photo.
        static let closeClearance: CGFloat = 8
    }

    /// The grown photo's corner radius.
    static let grownCornerRadius = GeneralConstants.CornerRadius.card * 1.5

    // MARK: - Callbacks

    /// Right before the photo leaves its source: hide the source view.
    var onWillShow: (() -> Void)?
    /// The photo reached its grown frame.
    var onDidShow: (() -> Void)?
    /// Right before the photo shrinks back: remove what the host added to the overlay.
    var onWillDismiss: (() -> Void)?
    /// The overlay is gone: show the source view.
    var onDidDismiss: (() -> Void)?
    /// When set, a tap on the photo calls this instead of shrinking it (a video's play / pause).
    var onImageTap: (() -> Void)?
    /// The grown photo moved to a new frame (the window or the fold changed): place what the
    /// host added to the overlay again.
    var onLayout: (() -> Void)?

    // MARK: - State

    var isPresented: Bool { overlay != nil }
    /// The overlay on the window; hosts add their own controls to it while the photo is grown.
    var overlayView: UIView? { overlay }
    /// The grown photo; hosts add a player layer to it.
    var imageView: UIImageView? { photoView }

    private var overlay: OverlayView?
    private var blurView: UIVisualEffectView?
    private var photoView: UIImageView?
    private var sourceFrame: (() -> CGRect?)?
    private var sourceCornerRadius: CGFloat = 0
    private var didFinishGrowing = false
    private var availableRect: ((UIWindow) -> CGRect)?
    private var grownRatio: CGFloat = 1
    private var maximumSide: CGFloat = .greatestFiniteMagnitude
    private var closeButton: CloseButton?

    // MARK: - Present

    /// - Parameters:
    ///   - aspectRatio: width / height of the grown photo; the image's own when nil.
    ///   - maximumSide: the grown photo's longer side never passes this.
    ///   - accessibilityLabel: the grown photo's VoiceOver label; nil leaves it out of VoiceOver.
    ///   - availableRect: the room the photo may fill, in window coordinates; the safe area when
    ///     nil. `EdgePadding.content` is kept clear inside it.
    ///   - showsCloseButton: a close button in the top leading corner of the window's safe area.
    ///   - sourceFrame: the source's frame in window coordinates, asked again when shrinking
    ///     (the source can move); nil when it is gone.
    func present(
        in window: UIWindow, image: UIImage, aspectRatio: CGFloat? = nil, sourceCornerRadius: CGFloat,
        maximumSide: CGFloat = .greatestFiniteMagnitude, accessibilityLabel: String? = nil,
        showsCloseButton: Bool = false,
        availableRect: ((UIWindow) -> CGRect)? = nil, sourceFrame: @escaping () -> CGRect?
    ) {
        guard overlay == nil, let start = sourceFrame() else { return }
        HapticFeedbackManager.shared.impact(intensity: .light)

        let overlay = OverlayView(frame: window.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.accessibilityViewIsModal = true
        overlay.onEscape = { [weak self] in self?.dismiss(animated: true) }
        overlay.onLayout = { [weak self] in self?.relayout() }

        let blurView = UIVisualEffectView(effect: nil)
        blurView.frame = overlay.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addSubview(blurView)

        let photoView = UIImageView(image: image)
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.layer.cornerCurve = .continuous
        photoView.isAccessibilityElement = accessibilityLabel != nil
        photoView.accessibilityLabel = accessibilityLabel
        photoView.accessibilityTraits = .image
        overlay.addSubview(photoView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        overlay.addGestureRecognizer(tap)

        if showsCloseButton {
            let button = CloseButton()
            button.accessibilityLabel = CommonStrings.close
            button.alpha = 0
            button.addTarget(self, action: #selector(handleCloseTap), for: .touchUpInside)
            overlay.addSubview(button)
            let safeArea = overlay.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(
                    equalTo: safeArea.leadingAnchor, constant: GeneralConstants.EdgePadding.medium),
                button.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: GeneralConstants.EdgePadding.medium)
            ])
            closeButton = button
        }

        window.addSubview(overlay)
        self.overlay = overlay
        self.blurView = blurView
        self.photoView = photoView
        self.sourceFrame = sourceFrame
        self.sourceCornerRadius = sourceCornerRadius
        didFinishGrowing = false
        onWillShow?()

        let imageRatio = image.size.height > 0 ? image.size.width / image.size.height : 1
        self.availableRect = availableRect
        self.grownRatio = aspectRatio ?? imageRatio
        self.maximumSide = maximumSide
        let end = grownFrame(in: window)
        let closeButton = closeButton

        let finish: (Bool) -> Void = { [weak self, weak overlay] _ in
            guard let self, let overlay, self.overlay === overlay else { return }
            self.didFinishGrowing = true
            // The window or the fold may have changed while the photo grew.
            self.relayout()
            UIAccessibility.post(notification: .screenChanged, argument: photoView)
            self.onDidShow?()
        }

        if UIAccessibility.isReduceMotionEnabled {
            photoView.frame = end
            photoView.layer.cornerRadius = Self.grownCornerRadius
            photoView.alpha = 0
            UIView.animate(withDuration: Timing.reducedMotionFade, animations: {
                blurView.effect = UIBlurEffect(style: .systemThinMaterial)
                photoView.alpha = 1
                closeButton?.alpha = 1
            }, completion: finish)
        } else {
            photoView.frame = start
            photoView.layer.cornerRadius = sourceCornerRadius
            UIView.animate(
                withDuration: Timing.grow, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8,
                animations: {
                    blurView.effect = UIBlurEffect(style: .systemThinMaterial)
                    photoView.frame = end
                    photoView.layer.cornerRadius = Self.grownCornerRadius
                    closeButton?.alpha = 1
                }, completion: finish)
        }
    }

    /// The grown photo's frame for the window as it is now.
    private func grownFrame(in window: UIWindow) -> CGRect {
        var room = (availableRect?(window) ?? window.bounds.inset(by: window.safeAreaInsets))
            .insetBy(dx: GeneralConstants.EdgePadding.content, dy: GeneralConstants.EdgePadding.content)
        let frame = Self.grownFrame(ratio: grownRatio, in: room, maximumSide: maximumSide)
        // A photo that would reach under the close button starts below it instead.
        guard closeButton != nil else { return frame }
        let button = closeButtonFrame(in: window)
        guard frame.intersects(button.insetBy(dx: -Layout.closeClearance, dy: -Layout.closeClearance)) else {
            return frame
        }
        let top = button.maxY + Layout.closeClearance
        guard top < room.maxY else { return frame }
        room = CGRect(x: room.minX, y: top, width: room.width, height: room.maxY - top)
        return Self.grownFrame(ratio: grownRatio, in: room, maximumSide: maximumSide)
    }

    /// Where the close button sits: the top leading corner of the window's safe area.
    private func closeButtonFrame(in window: UIWindow) -> CGRect {
        let safeArea = window.bounds.inset(by: window.safeAreaInsets)
        let side = GeneralConstants.ButtonSize.medium
        let inset = GeneralConstants.EdgePadding.medium
        let isRightToLeft = window.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let x = isRightToLeft ? safeArea.maxX - inset - side : safeArea.minX + inset
        return CGRect(x: x, y: safeArea.minY + inset, width: side, height: side)
    }

    /// Places the grown photo again for the window's size and the fold as they are now. The
    /// overlay calls it on every layout pass; a host calls it when the fold's state changes.
    func relayout() {
        guard didFinishGrowing, let overlay, let window = overlay.window, let photoView else { return }
        let frame = grownFrame(in: window)
        guard photoView.frame != frame else { return }
        let apply = {
            photoView.frame = frame
            self.onLayout?()
            overlay.layoutIfNeeded()
        }
        if UIAccessibility.isReduceMotionEnabled {
            apply()
        } else {
            UIView.animate(
                withDuration: Timing.grow, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8,
                options: .beginFromCurrentState, animations: apply)
        }
    }

    /// The largest frame of the ratio that fits the room, centered in it.
    private static func grownFrame(ratio: CGFloat, in room: CGRect, maximumSide: CGFloat) -> CGRect {
        let ratio = ratio > 0 ? ratio : 1
        var width = max(min(room.width, room.height * ratio), 1)
        var height = width / ratio
        let longSide = max(width, height)
        if longSide > maximumSide {
            let scale = maximumSide / longSide
            width *= scale
            height *= scale
        }
        return CGRect(x: room.midX - width / 2, y: room.midY - height / 2, width: width, height: height)
    }

    /// Swaps the grown photo's image (a sharper version of the same photo).
    func setImage(_ image: UIImage) {
        guard let photoView else { return }
        guard !UIAccessibility.isReduceMotionEnabled else {
            photoView.image = image
            return
        }
        UIView.transition(with: photoView, duration: Timing.imageSwap, options: .transitionCrossDissolve) {
            photoView.image = image
        }
    }

    // MARK: - Dismiss

    func dismiss(animated: Bool) {
        guard let overlay else { return }
        let blurView = blurView
        let photoView = photoView
        let closeButton = closeButton
        self.closeButton = nil
        availableRect = nil
        let end = sourceFrame?()
        let radius = sourceCornerRadius
        self.overlay = nil
        self.blurView = nil
        self.photoView = nil
        sourceFrame = nil
        onWillDismiss?()

        let finish = { [weak self] in
            overlay.removeFromSuperview()
            self?.onDidDismiss?()
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
        // The source may have moved or gone while the photo was open.
        guard animated, overlay.window != nil, let end else {
            finish()
            return
        }
        overlay.isUserInteractionEnabled = false
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: Timing.reducedMotionFade, animations: {
                blurView?.effect = nil
                photoView?.alpha = 0
                closeButton?.alpha = 0
            }, completion: { _ in finish() })
        } else {
            UIView.animate(withDuration: Timing.shrink, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState], animations: {
                blurView?.effect = nil
                closeButton?.alpha = 0
                photoView?.frame = end
                photoView?.layer.cornerRadius = radius
            }, completion: { _ in finish() })
        }
    }

    // MARK: - Actions

    @objc private func handleCloseTap() {
        dismiss(animated: true)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        if let onImageTap, didFinishGrowing, let photoView,
           photoView.frame.contains(gesture.location(in: overlay)) {
            onImageTap()
            return
        }
        dismiss(animated: true)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension PhotoGrowPresenter: UIGestureRecognizerDelegate {
    /// Touches on what the host added to the overlay (a video's controls) are theirs.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touched = touch.view, let overlay else { return true }
        if touched === overlay { return true }
        if let blurView, touched.isDescendant(of: blurView) { return true }
        if let photoView, touched.isDescendant(of: photoView) { return true }
        return false
    }
}

// MARK: - OverlayView

/// The overlay on the window: modal for VoiceOver, and its escape gesture closes the photo.
private final class OverlayView: UIView {
    var onEscape: (() -> Void)?
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }

    override func accessibilityPerformEscape() -> Bool {
        onEscape?()
        return true
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    /// A thumbnail that grows on tap.
    private final class PhotoGrowPreviewController: UIViewController {
        private let presenter = PhotoGrowPresenter()

        private let thumbnail: UIImageView = {
            let size = CGSize(width: 400, height: 300)
            let image = UIGraphicsImageRenderer(size: size).image { context in
                UIColor.systemTeal.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = GeneralConstants.CornerRadius.card
            imageView.layer.cornerCurve = .continuous
            imageView.isUserInteractionEnabled = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            return imageView
        }()

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .mainBackground
            view.addSubview(thumbnail)
            NSLayoutConstraint.activate([
                thumbnail.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                thumbnail.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                thumbnail.widthAnchor.constraint(equalToConstant: 120),
                thumbnail.heightAnchor.constraint(equalToConstant: 90)
            ])
            thumbnail.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        }

        @objc private func handleTap() {
            guard let window = view.window, let image = thumbnail.image else { return }
            presenter.onWillShow = { [weak self] in self?.thumbnail.alpha = 0 }
            presenter.onDidDismiss = { [weak self] in self?.thumbnail.alpha = 1 }
            presenter.present(
                in: window, image: image, sourceCornerRadius: GeneralConstants.CornerRadius.card,
                showsCloseButton: true,
                sourceFrame: { [weak self] in
                    guard let self, self.thumbnail.window != nil else { return nil }
                    return self.thumbnail.convert(self.thumbnail.bounds, to: nil)
                })
        }
    }

    private struct PhotoGrowPreview: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> PhotoGrowPreviewController {
            PhotoGrowPreviewController()
        }

        func updateUIViewController(_ uiViewController: PhotoGrowPreviewController, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Tap to grow") {
        PhotoGrowPreview()
    }
#endif
