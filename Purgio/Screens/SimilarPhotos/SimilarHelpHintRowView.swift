//
//  SimilarHelpHintRowView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let done = NSLocalizedString("similarHelp.hintDone", comment: "VoiceOver: a help hint the user has already done")
}

/// One hint of the Similar Photos help sheet: a small colored capsule with a glyph and one
/// line that starts with a bold lead. One VoiceOver element. Its `status` follows what the
/// user has done with the sample: upcoming hints are dimmed, the next one is at full strength
/// and done ones end with a green check.
final class SimilarHelpHintRowView: UIView {

    enum Status {
        case upcoming
        case active
        case done
    }

    private enum Layout {
        static let capsuleSize = CGSize(width: 22, height: 36)
        static let glyphSize: CGFloat = 14
        static let capsuleToText: CGFloat = 12
        static let fontSize: CGFloat = 15
        static let checkSize: CGFloat = 14
        static let textToCheck: CGFloat = 8
        static let upcomingAlpha: CGFloat = 0.45
        static let statusDuration: TimeInterval = 0.25
    }

    private(set) var status: Status = .active
    private var baseAccessibilityLabel = ""

    private let capsuleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Layout.capsuleSize.width / 2
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// The capsule's lower half in a second color, for a hint about switching between two marks
    private let bottomHalfView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let glyphView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let checkView: UIImageView = {
        let imageView = UIImageView(image: UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.checkSize, weight: .bold)))
        imageView.tintColor = ThemeManager.Colors.statusGreen
        imageView.contentMode = .center
        imageView.alpha = 0
        imageView.isHidden = true
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    /// The text runs to the edge, or stops before the check once the hint is done
    private var textToEdgeConstraint: NSLayoutConstraint?
    private var textToCheckConstraint: NSLayoutConstraint?

    // MARK: - Init

    /// - Parameters:
    ///   - color: the capsule's color, or its upper half's when `bottomColor` is set
    ///   - bottomColor: the lower half's color, for a hint that switches between two marks
    ///   - glyphColor: the glyph on the capsule: white, ink on yellow, or `.label` on gray
    init(
        systemImage: String, color: UIColor, bottomColor: UIColor? = nil, glyphColor: UIColor,
        lead: String, text: String
    ) {
        super.init(frame: .zero)
        setupUI()
        setupConstraint()

        capsuleView.backgroundColor = color
        bottomHalfView.backgroundColor = bottomColor
        bottomHalfView.isHidden = bottomColor == nil
        glyphView.tintColor = glyphColor
        glyphView.image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.glyphSize, weight: .bold))

        let attributed = NSMutableAttributedString(
            string: lead,
            attributes: [
                .font: UIFont.systemFont(ofSize: Layout.fontSize, weight: .semibold),
                .foregroundColor: UIColor.label
            ])
        attributed.append(NSAttributedString(
            string: " " + text,
            attributes: [
                .font: UIFont.systemFont(ofSize: Layout.fontSize),
                .foregroundColor: UIColor.secondaryLabel
            ]))
        textLabel.attributedText = attributed

        isAccessibilityElement = true
        baseAccessibilityLabel = lead + " " + text
        accessibilityLabel = baseAccessibilityLabel
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(capsuleView)
        capsuleView.addSubview(bottomHalfView)
        capsuleView.addSubview(glyphView)
        addSubview(textLabel)
        addSubview(checkView)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Layout.capsuleSize.height),

            capsuleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsuleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            capsuleView.widthAnchor.constraint(equalToConstant: Layout.capsuleSize.width),
            capsuleView.heightAnchor.constraint(equalToConstant: Layout.capsuleSize.height),

            bottomHalfView.leadingAnchor.constraint(equalTo: capsuleView.leadingAnchor),
            bottomHalfView.trailingAnchor.constraint(equalTo: capsuleView.trailingAnchor),
            bottomHalfView.bottomAnchor.constraint(equalTo: capsuleView.bottomAnchor),
            bottomHalfView.heightAnchor.constraint(equalTo: capsuleView.heightAnchor, multiplier: 0.5),

            glyphView.centerXAnchor.constraint(equalTo: capsuleView.centerXAnchor),
            glyphView.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor),

            textLabel.leadingAnchor.constraint(equalTo: capsuleView.trailingAnchor, constant: Layout.capsuleToText),
            textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            textLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            textLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),

            checkView.trailingAnchor.constraint(equalTo: trailingAnchor),
            checkView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        let toEdge = textLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        toEdge.isActive = true
        textToEdgeConstraint = toEdge
        textToCheckConstraint = textLabel.trailingAnchor.constraint(
            equalTo: checkView.leadingAnchor, constant: -Layout.textToCheck)
    }

    // MARK: - Status

    func setStatus(_ status: Status, animated: Bool) {
        guard status != self.status else { return }
        self.status = status
        let isDone = status == .done
        accessibilityLabel = isDone ? baseAccessibilityLabel + ", " + Strings.done : baseAccessibilityLabel

        // Swap which edge the text ends at before the fade, so the check never overlaps it
        textToEdgeConstraint?.isActive = !isDone
        textToCheckConstraint?.isActive = isDone
        if isDone { checkView.isHidden = false }

        let changes = {
            self.alpha = status == .upcoming ? Layout.upcomingAlpha : 1
            self.checkView.alpha = isDone ? 1 : 0
            self.layoutIfNeeded()
        }
        let completion: (Bool) -> Void = { _ in
            if self.status != .done { self.checkView.isHidden = true }
        }
        guard animated, window != nil else {
            changes()
            completion(true)
            return
        }
        UIView.animate(
            withDuration: Layout.statusDuration, delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: changes, completion: completion)
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    private struct SimilarHelpHintRowPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> SimilarHelpHintRowView {
            SimilarHelpHintRowView(
                systemImage: "arrow.up.and.down", color: ThemeManager.Colors.statusGreen,
                bottomColor: ThemeManager.Colors.statusRed, glyphColor: .white,
                lead: "Tap a photo", text: "to switch keep ↔ delete")
        }

        func updateUIView(_ uiView: SimilarHelpHintRowView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Hint row") {
        SimilarHelpHintRowPreview()
            .frame(height: 36)
            .padding()
    }
#endif
