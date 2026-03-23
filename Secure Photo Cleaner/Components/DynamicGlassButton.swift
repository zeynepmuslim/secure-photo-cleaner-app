//
//  DynamicGlassButton.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 20.01.2026.
//

import UIKit

class DynamicGlassButton: UIButton {

    enum GlassStyle {
        case prominent
        case regular
    }

    private var _richAttributedTitle: NSAttributedString?
    private var _isApplyingRichTitle = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !_isApplyingRichTitle,
              let rich = _richAttributedTitle,
              let titleLabel else { return }
        _isApplyingRichTitle = true
        titleLabel.attributedText = rich
        titleLabel.textAlignment = .center
        
        let insets = configuration?.contentInsets ?? .zero
        titleLabel.frame = CGRect(
            x: insets.leading,
            y: insets.top,
            width: bounds.width - insets.leading - insets.trailing,
            height: bounds.height - insets.top - insets.bottom
        )
        _isApplyingRichTitle = false
    }

    private func setupButton() {
        translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 26.0, *) {
            configuration = UIButton.Configuration.prominentGlass()
        } else {
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .capsule
            configuration = config
        }

        configurationUpdateHandler = { button in
            UIView.animate(withDuration: 0.2) {
                button.alpha = button.isEnabled ? 1.0 : 0.5
            }
        }
    }

    func configure(
        title: String? = nil,
        attributedTitle: NSAttributedString? = nil,
        image: UIImage? = nil,
        systemImage: String? = nil,
        style: GlassStyle = .prominent,
        backgroundColor: UIColor,
        foregroundColor: UIColor = .white,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat = 0,
        fontSize: CGFloat = 17,
        fontWeight: UIFont.Weight = .semibold,
        iconSize: CGFloat = 17,
        iconWeight: UIImage.SymbolWeight = .semibold,
        contentInsets: NSDirectionalEdgeInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
    ) {

        var config: UIButton.Configuration

        if #available(iOS 26.0, *) {
            switch style {
            case .prominent:
                config = UIButton.Configuration.prominentGlass()
                self.tintColor = backgroundColor
                config.baseForegroundColor = foregroundColor
            case .regular:
                config = UIButton.Configuration.glass()
                self.tintColor = foregroundColor
                config.baseForegroundColor = foregroundColor
            }
        } else {
            switch style {
            case .prominent:
                config = UIButton.Configuration.filled()
                config.baseBackgroundColor = backgroundColor
                config.baseForegroundColor = foregroundColor
            case .regular:
                config = UIButton.Configuration.gray()
                config.baseBackgroundColor = backgroundColor
                config.baseForegroundColor = foregroundColor
            }
            config.cornerStyle = .capsule
        }

        if let attributedTitle = attributedTitle {
            _richAttributedTitle = attributedTitle
            config.attributedTitle = AttributedString(attributedTitle.string)
        } else {
            _richAttributedTitle = nil
            config.title = title
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
                return outgoing
            }
        }

        if let image = image {
            config.image = image
        } else if let systemImage = systemImage {
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: iconSize, weight: iconWeight)
            var symbolImage = UIImage(systemName: systemImage, withConfiguration: symbolConfig)

            if #available(iOS 26.0, *), style == .regular {
                symbolImage = symbolImage?.withTintColor(foregroundColor, renderingMode: .alwaysOriginal)
            }

            config.image = symbolImage
        }

        let hasTitle = title != nil || attributedTitle != nil
        if hasTitle && (image != nil || systemImage != nil) {
            config.imagePadding = 8
        } else {
            config.imagePadding = 0
        }

        if let borderColor = borderColor, borderWidth > 0 {
            config.background.strokeColor = borderColor
            config.background.strokeWidth = borderWidth
        }

        config.contentInsets = contentInsets

        configuration = config
    }

    func animateConfigure(
        title: String? = nil,
        systemImage: String? = nil,
        style: GlassStyle = .prominent,
        backgroundColor: UIColor,
        foregroundColor: UIColor = .white,
        duration: TimeInterval = 0.3,
        completion: (() -> Void)? = nil
    ) {
        isUserInteractionEnabled = false
        UIView.transition(with: self, duration: duration, options: .transitionCrossDissolve) {
            self.configure(
                title: title,
                systemImage: systemImage,
                style: style,
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor
            )
        } completion: { _ in
            self.isUserInteractionEnabled = true
            completion?()
        }
    }

}
#if DEBUG
    import SwiftUI

    struct GlassButtonPreview: UIViewRepresentable {
        let title: String?
        let systemImage: String?
        let style: DynamicGlassButton.GlassStyle
        let backgroundColor: UIColor
        let borderColor: UIColor?
        let borderWidth: CGFloat
        let fontSize: CGFloat
        let iconSize: CGFloat
        let insets: NSDirectionalEdgeInsets

        init(
            title: String? = nil,
            systemImage: String? = nil,
            style: DynamicGlassButton.GlassStyle = .prominent,
            backgroundColor: UIColor,
            borderColor: UIColor? = nil,
            borderWidth: CGFloat = 0,
            fontSize: CGFloat = 17,
            iconSize: CGFloat = 17,
            insets: NSDirectionalEdgeInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        ) {
            self.title = title
            self.systemImage = systemImage
            self.style = style
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.borderWidth = borderWidth
            self.fontSize = fontSize
            self.iconSize = iconSize
            self.insets = insets
        }

        func makeUIView(context: Context) -> DynamicGlassButton {
            let button = DynamicGlassButton()
            button.configure(
                title: title,
                systemImage: systemImage,
                style: style,
                backgroundColor: backgroundColor,
                borderColor: borderColor,
                borderWidth: borderWidth,
                fontSize: fontSize,
                iconSize: iconSize,
                contentInsets: insets
            )
            return button
        }

        func updateUIView(_ uiView: DynamicGlassButton, context: Context) {}
    }

    #Preview("Prominent Glass") {
        VStack(spacing: 30) {
            GlassButtonPreview(
                title: "Accept",
                systemImage: "checkmark",
                backgroundColor: .systemGreen,
                borderColor: .white.withAlphaComponent(0.5),
                borderWidth: 1,
                fontSize: 13,
                iconSize: 11,
                insets: NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            )
            .fixedSize()

            GlassButtonPreview(
                title: "Delete",
                systemImage: "trash.fill",
                backgroundColor: .systemRed,
                borderColor: .red.withAlphaComponent(0.3),
                borderWidth: 2,
                fontSize: 17,
                iconSize: 17,
                insets: NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
            )
            .fixedSize()

            GlassButtonPreview(
                title: "Continue",
                systemImage: "arrow.right",
                backgroundColor: .systemBlue,
                borderColor: .white,
                borderWidth: 0,
                fontSize: 22,
                iconSize: 22,
                insets: NSDirectionalEdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40)
            )
            .fixedSize()
        }
        .padding()
        .background(SharpBackgroundView())
    }

    #Preview("Regular Glass") {
        GlassButtonPreview(
            title: "Regular",
            systemImage: "star",
            style: .regular,
            backgroundColor: .clear
        )
        .fixedSize()
        .padding()
        .background(SharpBackgroundView())
    }

    #Preview("Icon Only") {
        GlassButtonPreview(
            systemImage: "trash.fill",
            style: .prominent,
            backgroundColor: .systemRed,
            iconSize: 24,
            insets: NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        )
        .fixedSize()
        .padding()
        .background(SharpBackgroundView())
    }

    #Preview("Large Custom") {
        GlassButtonPreview(
            title: "Big Button",
            systemImage: "plus",
            style: .prominent,
            backgroundColor: .systemGreen,
            fontSize: 24,
            iconSize: 24,
            insets: NSDirectionalEdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40)
        )
        .fixedSize()
        .padding()
        .background(SharpBackgroundView())
    }

    struct AttributedTitlePreview: UIViewRepresentable {
        func makeUIView(context: Context) -> DynamicGlassButton {
            let button = DynamicGlassButton()
            let textFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
            let separatorAttrs: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.4)
            ]

            let result = NSMutableAttributedString()

            // ✓ 1
            let keepEntries: [(icon: String, count: Int, color: UIColor)] = [
                ("checkmark", 1, .systemGreen),
                ("xmark", 2, .systemRed)
            ]

            for entry in keepEntries {
                if result.length > 0 {
                    result.append(NSAttributedString(string: " · ", attributes: separatorAttrs))
                }
                let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                if let iconImage = UIImage(systemName: entry.icon, withConfiguration: iconConfig)?
                    .withTintColor(entry.color, renderingMode: .alwaysOriginal)
                {
                    let attachment = NSTextAttachment()
                    attachment.image = iconImage
                    let iconHeight = iconImage.size.height
                    let iconWidth = iconImage.size.width
                    attachment.bounds = CGRect(
                        x: 0, y: (textFont.capHeight - iconHeight) / 2,
                        width: iconWidth, height: iconHeight)
                    result.append(NSAttributedString(attachment: attachment))
                }
                result.append(NSAttributedString(
                    string: " \(entry.count)",
                    attributes: [.font: textFont, .foregroundColor: entry.color]
                ))
            }

            result.append(NSAttributedString(
                string: "  Confirm",
                attributes: [.font: textFont, .foregroundColor: UIColor.white]
            ))

            button.configure(
                attributedTitle: result,
                style: .prominent,
                backgroundColor: .black,
                contentInsets: NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            )
            return button
        }

        func updateUIView(_ uiView: DynamicGlassButton, context: Context) {}
    }

    #Preview("Attributed Title") {
        AttributedTitlePreview()
            .fixedSize()
            .padding()
            .background(SharpBackgroundView())
    }

    struct SharpBackgroundView: View {
        var body: some View {
            ZStack {
                Color.white

                GeometryReader { geometry in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(Color.red)

                    Path { path in
                        path.move(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                        path.addLine(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(Color.red)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 30, height: 200)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
#endif
