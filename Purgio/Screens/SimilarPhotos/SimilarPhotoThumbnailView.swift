//
//  SimilarPhotoThumbnailView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

/// A photo of a similar set as its mark shows it: a 3pt border and a corner badge in the
/// state's color, and a desaturated, faded image when it's marked delete. `PhotoGridCell`
/// hosts it for real assets; the help sheet's sample set uses it with drawn placeholders.
final class SimilarPhotoThumbnailView: UIView {

    private enum Layout {
        static let cornerRadius: CGFloat = 10
        static let borderWidth: CGFloat = 3
        static let badgeSize: CGFloat = 18
        static let badgeInset: CGFloat = 6
        static let badgeIconSize: CGFloat = 9
        /// A photo marked for deletion fades back behind the ones that stay
        static let deleteAlpha: CGFloat = 0.72
        static let stateChangeDuration: TimeInterval = 0.15
    }

    /// Grayscale copies of the images marked delete, by `grayscaleCacheKey`
    private static let grayscaleCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    /// The image as taken; the view shows its grayscale copy while the state is delete
    var image: UIImage? {
        didSet { applyImage() }
    }

    /// What the grayscale copy is cached under (an asset id); nil converts on every change
    var grayscaleCacheKey: String?

    private(set) var state: SimilarPhotoState?

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let badgeView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Layout.badgeSize / 2
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let badgeIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .white
        imageView.contentMode = .center
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        layer.cornerRadius = Layout.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true
        backgroundColor = .systemGray5

        addSubview(imageView)
        addSubview(badgeView)
        badgeView.addSubview(badgeIconView)

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
                (self: SimilarPhotoThumbnailView, _: UITraitCollection) in
                self.applyBorderColor()
            }
        }
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            badgeView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.badgeInset),
            badgeView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.badgeInset),
            badgeView.widthAnchor.constraint(equalToConstant: Layout.badgeSize),
            badgeView.heightAnchor.constraint(equalToConstant: Layout.badgeSize),

            badgeIconView.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            badgeIconView.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor)
        ])
    }

    // MARK: - State

    /// Shows a mark, or none with nil. Animated, the change cross-dissolves.
    func applyState(_ state: SimilarPhotoState?, animated: Bool = false) {
        guard animated, window != nil else {
            setState(state)
            return
        }
        UIView.transition(
            with: self, duration: Layout.stateChangeDuration,
            options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState]
        ) {
            self.setState(state)
        }
    }

    private func setState(_ state: SimilarPhotoState?) {
        self.state = state
        layer.borderWidth = state == nil ? 0 : Layout.borderWidth
        applyBorderColor()

        badgeView.isHidden = state == nil
        if let state {
            badgeView.backgroundColor = state.color
            badgeIconView.image = UIImage(
                systemName: state.badgeIcon,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.badgeIconSize, weight: .bold))
        }
        applyImage()
    }

    private func applyBorderColor() {
        layer.borderColor = (state?.color ?? .clear).resolvedColor(with: traitCollection).cgColor
    }

    /// The image as its state shows it: delete is desaturated and faded, the rest as taken.
    private func applyImage() {
        guard state == .delete else {
            imageView.image = image
            imageView.alpha = 1
            return
        }
        imageView.alpha = Layout.deleteAlpha
        guard let original = image else {
            imageView.image = nil
            return
        }
        guard let key = grayscaleCacheKey as NSString? else {
            imageView.image = GrayscaleConverter.apply(to: original) ?? original
            return
        }
        if let cached = Self.grayscaleCache.object(forKey: key) {
            imageView.image = cached
            return
        }
        let gray = GrayscaleConverter.apply(to: original) ?? original
        Self.grayscaleCache.setObject(gray, forKey: key)
        imageView.image = gray
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyBorderColor()
        }
    }

    // MARK: - Store mode wiggle

    func startShake() {
        guard layer.animation(forKey: "wiggle") == nil else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation")
        animation.values = [-0.03, 0.03, -0.03]
        animation.duration = 0.25
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "wiggle")
    }

    func stopShake() {
        layer.removeAnimation(forKey: "wiggle")
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    private struct SimilarPhotoThumbnailPreview: UIViewRepresentable {
        let state: SimilarPhotoState?

        func makeUIView(context: Context) -> SimilarPhotoThumbnailView {
            let view = SimilarPhotoThumbnailView()
            let size = CGSize(width: 120, height: 120)
            view.image = UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.systemTeal.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            view.applyState(state)
            return view
        }

        func updateUIView(_ uiView: SimilarPhotoThumbnailView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("States") {
        HStack(spacing: 12) {
            SimilarPhotoThumbnailPreview(state: .keep).frame(width: 72, height: 72)
            SimilarPhotoThumbnailPreview(state: .delete).frame(width: 72, height: 72)
            SimilarPhotoThumbnailPreview(state: .store).frame(width: 72, height: 72)
            SimilarPhotoThumbnailPreview(state: nil).frame(width: 72, height: 72)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
#endif
