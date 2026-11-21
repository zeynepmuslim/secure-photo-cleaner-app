//
//  SimilarHelpTargetsView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let photos = NSLocalizedString("similarHelp.targetPhotos", comment: "Where kept photos stay: the library")
    static let bin = NSLocalizedString("similarHelp.targetBin", comment: "Where deleted photos go: the bin")
    static let stored = NSLocalizedString("similarHelp.targetStored", comment: "Where stored photos go")
    static func accessibility(name: String, count: Int) -> String {
        String(
            format: NSLocalizedString(
                "similarHelp.targetAccessibility", comment: "VoiceOver: a target and how many photos it got, e.g. 'Bin, 2'"),
            name, count)
    }
}

/// Where the help sheet's sample photos go after Confirm (board "Similar photos · help sheet ·
/// keep, bin and store targets"): a pile of photos for the kept ones, the bin and the store
/// box, in equal thirds, each with its name and a count under it. The bin and the box are a
/// lid over a body, so the lid can open; the sheet runs the animation.
final class SimilarHelpTargetsView: UIView {

    enum Target: CaseIterable {
        case photos
        case bin
        case stored
    }

    private enum Layout {
        /// Points per icon unit (the bin is drawn 20×23, the box 21×19)
        static let iconScale: CGFloat = 2.9
        static let iconAreaHeight: CGFloat = 72
        static let iconToLabel: CGFloat = 8
        static let labelFontSize: CGFloat = 13

        static let pileSize = CGSize(width: 70, height: 66)
        static let pileCardSide: CGFloat = 46
        static let pileCardRadius: CGFloat = 9
        static let pileGlyphSize: CGFloat = 18

        /// How far under the body's top edge a photo aims, and how much further it drops behind it
        static let openingInset: CGFloat = 4
        static let dropDistance: CGFloat = 26

        static let lidOpenDuration: TimeInterval = 0.42
        static let squashDuration: TimeInterval = 0.2
    }

    /// A lid-and-body icon in icon units: the lid sits at the origin.
    private struct IconGeometry {
        let size: CGSize
        let lidSize: CGSize
        /// The point the lid turns around
        let lidHinge: CGPoint
        let bodyOrigin: CGPoint
        let bodySize: CGSize
        let openTranslation: CGPoint
        let openDegrees: CGFloat
        let squash: CGSize

        static let bin = IconGeometry(
            size: CGSize(width: 20, height: 23), lidSize: CGSize(width: 20, height: 6),
            lidHinge: CGPoint(x: 0.6, y: 5.4), bodyOrigin: CGPoint(x: 2.0, y: 5.8),
            bodySize: CGSize(width: 16, height: 17), openTranslation: CGPoint(x: -0.5, y: -2.6),
            openDegrees: -24, squash: CGSize(width: 1.05, height: 0.92))
        static let box = IconGeometry(
            size: CGSize(width: 21, height: 19), lidSize: CGSize(width: 21, height: 6),
            lidHinge: CGPoint(x: 10.25, y: 5.3), bodyOrigin: CGPoint(x: 1.0, y: 5.56),
            bodySize: CGSize(width: 18, height: 13), openTranslation: CGPoint(x: 0, y: -5.5),
            openDegrees: -9, squash: CGSize(width: 1.05, height: 0.92))
    }

    // MARK: - Views

    private let columnsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let pileView = UIView()
    private let pileFrontView = UIView()
    private let binIconView = UIView()
    private let binLidView = UIImageView(image: UIImage(resource: .binLid))
    private let binBodyView = UIImageView(image: UIImage(resource: .binBody))
    private let boxIconView = UIView()
    private let boxLidView = UIImageView(image: UIImage(resource: .storeBoxLid))
    private let boxBodyView = UIImageView(image: UIImage(resource: .storeBoxBody))

    private var columns: [Target: UIView] = [:]
    private var labels: [Target: UILabel] = [:]
    private var counts: [Target: Int] = [:]

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
        Target.allCases.forEach { updateLabel(for: $0) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        isUserInteractionEnabled = false
        addSubview(columnsStack)

        for target in Target.allCases {
            let column = UIView()
            column.isAccessibilityElement = true
            columns[target] = column
            columnsStack.addArrangedSubview(column)

            let label = UILabel()
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            label.translatesAutoresizingMaskIntoConstraints = false
            labels[target] = label
            column.addSubview(label)

            let icon = iconView(for: target)
            icon.translatesAutoresizingMaskIntoConstraints = false
            column.addSubview(icon)
        }

        setupPile()
        binIconView.tintColor = ThemeManager.Colors.statusRed
        boxIconView.tintColor = ThemeManager.Colors.statusYellow
        // Body first: the lid stays above it, and a photo falling in passes behind both
        for (icon, body, lid) in [(binIconView, binBodyView, binLidView), (boxIconView, boxBodyView, boxLidView)] {
            for part in [body, lid] {
                part.contentMode = .scaleToFill
                part.translatesAutoresizingMaskIntoConstraints = false
                icon.addSubview(part)
            }
        }
    }

    private func setupPile() {
        let back = UIView()
        back.backgroundColor = .keepPileBack
        back.transform = CGAffineTransform(translationX: 7, y: -6).rotated(by: 12 * .pi / 180)
        let middle = UIView()
        middle.backgroundColor = .keepPileMiddle
        middle.transform = CGAffineTransform(translationX: -6, y: -3).rotated(by: -8 * .pi / 180)
        pileFrontView.backgroundColor = .systemGreen

        let glyph = UIImageView(
            image: UIImage(
                systemName: "photo",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.pileGlyphSize, weight: .semibold)))
        glyph.tintColor = .white
        glyph.contentMode = .center
        glyph.translatesAutoresizingMaskIntoConstraints = false
        pileFrontView.addSubview(glyph)

        for card in [back, middle, pileFrontView] {
            card.layer.cornerRadius = Layout.pileCardRadius
            card.layer.cornerCurve = .continuous
            card.translatesAutoresizingMaskIntoConstraints = false
            pileView.addSubview(card)
            NSLayoutConstraint.activate([
                card.widthAnchor.constraint(equalToConstant: Layout.pileCardSide),
                card.heightAnchor.constraint(equalToConstant: Layout.pileCardSide),
                card.centerXAnchor.constraint(equalTo: pileView.centerXAnchor),
                card.bottomAnchor.constraint(equalTo: pileView.bottomAnchor, constant: -10)
            ])
        }
        NSLayoutConstraint.activate([
            glyph.centerXAnchor.constraint(equalTo: pileFrontView.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: pileFrontView.centerYAnchor)
        ])
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            columnsStack.topAnchor.constraint(equalTo: topAnchor),
            columnsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            columnsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            columnsStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let scale = Layout.iconScale
        let iconSizes: [Target: CGSize] = [
            .photos: Layout.pileSize,
            .bin: CGSize(width: IconGeometry.bin.size.width * scale, height: IconGeometry.bin.size.height * scale),
            .stored: CGSize(width: IconGeometry.box.size.width * scale, height: IconGeometry.box.size.height * scale)
        ]
        for target in Target.allCases {
            guard let column = columns[target], let label = labels[target], let size = iconSizes[target] else { continue }
            let icon = iconView(for: target)
            // The icons stand on one line, whatever their height. The pile squashes from its
            // bottom edge, so its center (and anchor point) is that edge.
            let baseline = target == .photos ? icon.centerYAnchor : icon.bottomAnchor
            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: size.width),
                icon.heightAnchor.constraint(equalToConstant: size.height),
                icon.centerXAnchor.constraint(equalTo: column.centerXAnchor),
                baseline.constraint(equalTo: column.topAnchor, constant: Layout.iconAreaHeight),

                label.topAnchor.constraint(equalTo: column.topAnchor, constant: Layout.iconAreaHeight + Layout.iconToLabel),
                label.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 2),
                label.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -2),
                label.bottomAnchor.constraint(equalTo: column.bottomAnchor)
            ])
        }

        constrainParts(lid: binLidView, body: binBodyView, in: binIconView, geometry: .bin)
        constrainParts(lid: boxLidView, body: boxBodyView, in: boxIconView, geometry: .box)

        pileView.layer.anchorPoint = CGPoint(x: 0.5, y: 1)
    }

    /// Places a lid and a body by the point each one turns or squashes around: the view's
    /// `center` is constrained to that point and its `anchorPoint` is the same point in the
    /// view's own unit space, so the transforms need no further offsets.
    private func constrainParts(lid: UIView, body: UIView, in icon: UIView, geometry: IconGeometry) {
        let scale = Layout.iconScale
        lid.layer.anchorPoint = CGPoint(
            x: geometry.lidHinge.x / geometry.lidSize.width, y: geometry.lidHinge.y / geometry.lidSize.height)
        body.layer.anchorPoint = CGPoint(x: 0.5, y: 1)

        NSLayoutConstraint.activate([
            lid.widthAnchor.constraint(equalToConstant: geometry.lidSize.width * scale),
            lid.heightAnchor.constraint(equalToConstant: geometry.lidSize.height * scale),
            lid.centerXAnchor.constraint(equalTo: icon.leadingAnchor, constant: geometry.lidHinge.x * scale),
            lid.centerYAnchor.constraint(equalTo: icon.topAnchor, constant: geometry.lidHinge.y * scale),

            body.widthAnchor.constraint(equalToConstant: geometry.bodySize.width * scale),
            body.heightAnchor.constraint(equalToConstant: geometry.bodySize.height * scale),
            body.centerXAnchor.constraint(
                equalTo: icon.leadingAnchor, constant: (geometry.bodyOrigin.x + geometry.bodySize.width / 2) * scale),
            body.centerYAnchor.constraint(
                equalTo: icon.topAnchor, constant: (geometry.bodyOrigin.y + geometry.bodySize.height) * scale)
        ])
    }

    private func iconView(for target: Target) -> UIView {
        switch target {
        case .photos: return pileView
        case .bin: return binIconView
        case .stored: return boxIconView
        }
    }

    // MARK: - Counts

    /// Shows how many photos a target got: "0" before any, then "+N". Announced to VoiceOver.
    func setCount(_ count: Int, for target: Target) {
        counts[target] = count
        updateLabel(for: target)
        if let label = columns[target]?.accessibilityLabel, count > 0 {
            UIAccessibility.post(notification: .announcement, argument: label)
        }
    }

    private func name(of target: Target) -> String {
        switch target {
        case .photos: return Strings.photos
        case .bin: return Strings.bin
        case .stored: return Strings.stored
        }
    }

    private func updateLabel(for target: Target) {
        let count = counts[target] ?? 0
        let font = UIFont.systemFont(ofSize: Layout.labelFontSize, weight: .semibold)
        let text = NSMutableAttributedString(
            string: name(of: target) + " ",
            attributes: [.font: font, .foregroundColor: UIColor.secondaryLabel])
        text.append(NSAttributedString(
            string: count > 0 ? "+\(count)" : "0",
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: Layout.labelFontSize, weight: .semibold),
                .foregroundColor: UIColor.label
            ]))
        labels[target]?.attributedText = text
        columns[target]?.accessibilityLabel = Strings.accessibility(name: name(of: target), count: count)
    }

    // MARK: - Animation

    /// Opens or shuts the bin's or the box's lid. Shutting springs, with a small overshoot.
    func setLidOpen(_ isOpen: Bool, for target: Target) {
        let lid: UIView
        let geometry: IconGeometry
        switch target {
        case .bin: (lid, geometry) = (binLidView, .bin)
        case .stored: (lid, geometry) = (boxLidView, .box)
        case .photos: return
        }
        if isOpen {
            let scale = Layout.iconScale
            UIView.animate(withDuration: Layout.lidOpenDuration, delay: 0, options: .curveEaseInOut) {
                lid.transform = CGAffineTransform(
                    translationX: geometry.openTranslation.x * scale, y: geometry.openTranslation.y * scale
                ).rotated(by: geometry.openDegrees * .pi / 180)
            }
        } else {
            UIView.animate(
                withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0,
                options: .beginFromCurrentState
            ) {
                lid.transform = .identity
            }
        }
    }

    /// A target takes a photo: it squashes from its bottom edge and comes back.
    func squash(_ target: Target) {
        let view: UIView
        let amount: CGSize
        switch target {
        case .photos: (view, amount) = (pileView, CGSize(width: 1.06, height: 0.94))
        case .bin: (view, amount) = (binBodyView, IconGeometry.bin.squash)
        case .stored: (view, amount) = (boxBodyView, IconGeometry.box.squash)
        }
        UIView.animate(withDuration: Layout.squashDuration / 2, delay: 0, options: .curveEaseOut) {
            view.transform = CGAffineTransform(scaleX: amount.width, y: amount.height)
        } completion: { _ in
            UIView.animate(withDuration: Layout.squashDuration / 2, delay: 0, options: .curveEaseIn) {
                view.transform = .identity
            }
        }
    }

    /// Where a photo flying to a target ends up, in `view`'s coordinates: the middle of the
    /// pile's front card, or just under the top edge of the bin's or the box's body.
    func landingPoint(for target: Target, in view: UIView) -> CGPoint {
        layoutIfNeeded()
        switch target {
        case .photos:
            return pileFrontView.convert(
                CGPoint(x: pileFrontView.bounds.midX, y: pileFrontView.bounds.midY), to: view)
        case .bin:
            return binIconView.convert(opening(of: .bin), to: view)
        case .stored:
            return boxIconView.convert(opening(of: .box), to: view)
        }
    }

    /// How far a photo drops behind a body after it reaches the opening
    var dropDistance: CGFloat { Layout.dropDistance }

    private func opening(of geometry: IconGeometry) -> CGPoint {
        CGPoint(
            x: (geometry.bodyOrigin.x + geometry.bodySize.width / 2) * Layout.iconScale,
            y: geometry.bodyOrigin.y * Layout.iconScale + Layout.openingInset)
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    private struct SimilarHelpTargetsPreview: UIViewRepresentable {
        let lidsOpen: Bool

        func makeUIView(context: Context) -> SimilarHelpTargetsView {
            let view = SimilarHelpTargetsView()
            if lidsOpen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    view.setLidOpen(true, for: .bin)
                    view.setLidOpen(true, for: .stored)
                    view.setCount(2, for: .bin)
                }
            }
            return view
        }

        func updateUIView(_ uiView: SimilarHelpTargetsView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Targets") {
        SimilarHelpTargetsPreview(lidsOpen: false)
            .frame(height: 100)
            .padding(24)
    }

    @available(iOS 17.0, *)
    #Preview("Lids open") {
        SimilarHelpTargetsPreview(lidsOpen: true)
            .frame(height: 100)
            .padding(24)
    }
#endif
