//
//  PrivacyShieldArtView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 22.11.2026.
//

import UIKit

/// The photo access sheet's art (board "Photo access sheet · frame, line and lock"): a drawn
/// phone of the device the app runs on, holding the seven bundled sample photos
/// (`photo1_large`…`photo7_large`, the ones the old soap bubble showed), with a green line 20pt
/// around its frame (concentric corners) and a lock in a break at the bottom center. Nothing animates.
///
/// Everything is sized from the view's own bounds in `layoutSubviews`. The phone variant is
/// read from the window (its safe area, size class and aspect) on every layout pass, since the
/// Duo can fold and unfold under the sheet. Never the user's photos: the sheet shows before access.
final class PrivacyShieldArtView: UIView {

    enum DeviceVariant: Equatable {
        case homeButton
        case notch
        case dynamicIsland
        case duoCover
        case duoInnerUpright
        case duoInnerSideways
    }

    // MARK: - Layout constants

    private enum Layout {
        /// The green line: its gap to the phone's frame, its width, and the break at the
        /// bottom center that holds the lock.
        static let lineGap: CGFloat = 20
        static let lineWidth: CGFloat = 2
        static let lineBreak: CGFloat = 36
        static let lockPointSize: CGFloat = 21
        /// The metal band around the glass, and the black bezel inside it (share of the short side).
        static let phoneFrameWidth: CGFloat = 1
        static let phoneBezelRatio: CGFloat = 0.024
        /// Outer corner radius as a share of the short side.
        static let phoneCornerRatio: CGFloat = 0.15
        static let duoInnerCornerRatio: CGFloat = 0.11
        /// The Duo cover: round on the outer side, nearly square along the hinge.
        static let duoCoverOuterCornerRatio: CGFloat = 0.15
        static let duoCoverHingeCornerRatio: CGFloat = 0.035
        /// The Duo's 84pt status strip: along the physical right edge of the 466pt cover and the
        /// 951pt-wide inner display held sideways, along the top of the 951pt-tall upright one.
        static let duoCoverStripRatio: CGFloat = 84.0 / 466
        static let duoInnerUprightStripRatio: CGFloat = 84.0 / 951
        static let duoInnerSidewaysStripRatio: CGFloat = 84.0 / 951
        /// A home-button phone: side bezels (share of the width) and forehead / chin (share of the height).
        static let homeButtonSideBezelRatio: CGFloat = 0.06
        static let homeButtonChinRatio: CGFloat = 0.125
        /// A tile's standard corner radius, and the enlarged photo's at the start and end of its flight.
        static let tileRadius: CGFloat = 5
    }

    /// The bundled sample photos, one per tile (400×400, sharp enough for the largest tile).
    private static let samplePhotoNames = (1...7).map { "photo\($0)_large" }

    /// Uneven tile heights per column (relative weights), from the board.
    private static let columnWeights: [Int: [[CGFloat]]] = [
        2: [[24.4, 33.9, 21.7, 28.5], [29.0, 46.1, 37.5]],
        3: [[33.2, 46.1, 29.5], [66.6, 47.2], [62.6, 51.2]],
        4: [[56.2, 78.0], [62.6, 71.6], [74.0, 60.3], [139.3]],
    ]

    // MARK: - Views

    /// The flat art: the line, the phone and the lock. It's what the folded snapshot renders, so
    /// all three fold with the phone; its frame is the phone's outset evenly, so its center is the hinge.
    private let flatArtView = UIView()

    /// The green line around the phone's frame, open at the bottom center for the lock
    /// (an open path, not a mask, so `render(in:)` draws it).
    private let lineLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.lineWidth = Layout.lineWidth
        layer.lineCap = .round
        layer.lineJoin = .round
        return layer
    }()

    private let lockView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.tintColor = .systemGreen
        return view
    }()

    private static let lockSymbol = UIImage(
        systemName: "lock.fill",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.lockPointSize, weight: .semibold))

    /// Holds the drawn phone; `bodyLayer` draws its body.
    private let phoneView = UIView()

    /// The lit screen inside the bezel, drawn by `screenLayer` (a shape, not a mask, so the
    /// folded snapshot's `render(in:)` draws it).
    private let screenView = UIView()
    private let screenLayer = CAShapeLayer()
    private static let screenColor: UIColor = .artPhoneScreen

    /// While the Duo is partly folded, the phone shows as a snapshot cut in two halves, each
    /// turned around the hinge in perspective: a book held open sideways, a laptop upright.
    private let foldedView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()
    private let firstHalfView = UIImageView()
    private let secondHalfView = UIImageView()

    private let speakerView: UIView = {
        let view = PrivacyShieldArtView.makeDetailView()
        view.backgroundColor = .systemGray
        return view
    }()
    private let homeButtonView: UIView = {
        let view = PrivacyShieldArtView.makeDetailView()
        view.layer.borderWidth = 1
        return view
    }()
    private let notchView = PrivacyShieldArtView.makeDetailView()
    private let islandView = PrivacyShieldArtView.makeDetailView()
    private let cameraHoleView = PrivacyShieldArtView.makeDetailView()
    /// The time in the Duo's status strip, as a short gray bar.
    private let statusMarkView: UIView = {
        let view = PrivacyShieldArtView.makeDetailView()
        view.backgroundColor = .systemGray3
        return view
    }()
    /// The inner display's fold, a faint line across the screen.
    private let creaseView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray3.withAlphaComponent(0.35)
        return view
    }()
    /// The body (black bezel) with the metal band as its stroke, so each corner can have its own radius.
    private let bodyLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.black.cgColor
        layer.lineWidth = 1
        return layer
    }()


    /// The photo tiles. Each shows its photo already cut to its own rounded shape
    /// (`renderTile(at:)`): the corners in the screen's corners follow the screen's radius, and
    /// clipping in the bitmap keeps the folded snapshot's `render(in:)` exact without masks.
    private let tileViews: [UIImageView] = PrivacyShieldArtView.samplePhotoNames.map { _ in
        UIImageView()
    }
    private var samplePhotos: [UIImage?] = PrivacyShieldArtView.samplePhotoNames.map { _ in nil }
    private var tileCorners: [Corners] = PrivacyShieldArtView.samplePhotoNames.map { _ in Corners(all: 0) }

    /// The enlarged photo (an easter egg: the sample photos are the developer's), over the window.
    private var photoOverlay: UIView?
    private var enlargedTileIndex: Int?

    private var phoneBuiltFor: (variant: DeviceVariant, size: CGSize, isFolded: Bool)?
    private(set) var deviceVariant: DeviceVariant = .dynamicIsland
    /// The body's corner radii, which the line grows by its distance to stay concentric.
    private var phoneCorners = Corners(all: 0)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Hidden from VoiceOver; a tap on a photo only enlarges it.
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
        isAccessibilityElement = false
        accessibilityElementsHidden = true

        addSubview(flatArtView)
        flatArtView.layer.addSublayer(lineLayer)
        flatArtView.addSubview(phoneView)
        flatArtView.addSubview(lockView)

        phoneView.addSubview(screenView)
        tileViews.forEach(phoneView.addSubview)
        loadSamplePhotos()

        [speakerView, homeButtonView, notchView, islandView, cameraHoleView, statusMarkView, creaseView]
            .forEach(phoneView.addSubview)
        phoneView.layer.insertSublayer(bodyLayer, at: 0)
        screenView.layer.addSublayer(screenLayer)
        addSubview(foldedView)
        [firstHalfView, secondHalfView].forEach(foldedView.addSubview)
        notchView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        applyColors()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: PrivacyShieldArtView, _: UITraitCollection) in
                self.applyColors()
            }
        }
    }

    /// Decodes the sample photos off main; the tiles show gray until they arrive.
    private func loadSamplePhotos() {
        let names = Self.samplePhotoNames
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let images = names.map { UIImage(named: $0)?.preparingForDisplay() ?? UIImage(named: $0) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.samplePhotos = images
                self.tileViews.indices.forEach(self.renderTile(at:))
                self.refreshFoldedSnapshot()
            }
        }
    }

    private static func makeDetailView() -> UIView {
        let view = UIView()
        // Camera cutouts are black glass in both appearances.
        view.backgroundColor = .black
        view.layer.cornerCurve = .continuous
        return view
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        UIView.performWithoutAnimation {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let variant = currentVariant()
            deviceVariant = variant
            let folded = isPartlyFolded(variant)
            if phoneBuiltFor?.variant != variant || phoneBuiltFor?.size != bounds.size
                || phoneBuiltFor?.isFolded != folded {
                phoneBuiltFor = (variant, bounds.size, folded)
                layoutArt(variant: variant, folded: folded)
                updateFoldedPhone(folded: folded, variant: variant)
            }
            CATransaction.commit()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { dismissPhoto(animated: false) }
        setNeedsLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // The size class picks the Duo inner display's phone.
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            setNeedsLayout()
        }
        // iOS 17+ uses registerForTraitChanges for colors.
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyColors()
        }
    }

    /// The device the app runs on, from what the window shows: never the screen's size.
    private func currentVariant() -> DeviceVariant {
        guard let window = window else { return deviceVariant }
        if DuoLayout.isDuoDisplay(window) {
            guard window.traitCollection.horizontalSizeClass == .regular else { return .duoCover }
            return window.bounds.width > window.bounds.height ? .duoInnerSideways : .duoInnerUpright
        }
        let insets = window.safeAreaInsets
        if insets.bottom == 0 { return .homeButton }
        return insets.top < 54 ? .notch : .dynamicIsland
    }

    // MARK: - Line and lock

    /// What the line takes on each side of the phone: the gap and the line itself.
    private static var lineRoom: CGFloat { Layout.lineGap + Layout.lineWidth }

    /// The lock's half-height, which hangs below the line's bottom edge.
    private var lockHalfHeight: CGFloat { (Self.lockSymbol?.size.height ?? Layout.lockPointSize) / 2 }

    /// Sizes the phone to fit inside the line's room, then lays out the flat art around it.
    private func layoutArt(variant: DeviceVariant, folded: Bool) {
        if folded, variant == .duoInnerUpright {
            layoutArtForTablePose(variant: variant)
            return
        }
        let room = Self.lineRoom
        let available = CGRect(x: room, y: room,
                               width: bounds.width - 2 * room,
                               height: bounds.height - 2 * room - lockHalfHeight)
        guard available.width > 0, available.height > 0 else { return }
        let aspect = Self.phoneAspect(for: variant)
        var size = CGSize(width: available.height * aspect, height: available.height)
        if size.width > available.width {
            size = CGSize(width: available.width, height: available.width / aspect)
        }
        let phoneFrame = CGRect(x: available.midX - size.width / 2, y: available.midY - size.height / 2,
                                width: size.width, height: size.height)

        // Outset evenly, so the flat art's center is the phone's (the hinge, while folded).
        let outset = room + lockHalfHeight
        flatArtView.transform = .identity
        flatArtView.frame = phoneFrame.insetBy(dx: -outset, dy: -outset)
        layoutPhone(frame: CGRect(origin: CGPoint(x: outset, y: outset), size: size), variant: variant)
        layoutLineAndLock()
    }

    /// The table pose draws the art as a laptop: the raised half leans back and the base lies
    /// toward the viewer, so the drawing is shorter than the flat art and its base wider. The
    /// phone is sized so the folded drawing (not the flat art) fills the bounds, and placed so
    /// that drawing is centered in them: its bottom line reaches the bounds' bottom edge.
    private func layoutArtForTablePose(variant: DeviceVariant) {
        let outset = Self.lineRoom + lockHalfHeight
        let aspect = Self.phoneAspect(for: variant)
        let radians = { (degrees: CGFloat) in degrees * .pi / 180 }
        let raised = radians(Fold.raisedHalfAngle)
        let base = radians(Fold.baseAngle)

        /// The folded drawing's reach above and below the hinge, and its widest half-width (the base's edge).
        func extent(phoneHeight h: CGFloat) -> (top: CGFloat, bottom: CGFloat, halfWidth: CGFloat) {
            let phoneWidth = h * aspect
            let halfHeight = (h + 2 * outset) / 2
            let depth = max(phoneWidth, h) * Fold.perspectiveDepth
            let towardViewer = max(0.05, 1 - halfHeight * sin(base) / depth)
            let top = Fold.scale * halfHeight * cos(raised) / (1 + halfHeight * sin(raised) / depth)
            let bottom = Fold.scale * halfHeight * cos(base) / towardViewer
            let halfWidth = Fold.scale * (phoneWidth / 2 + outset) / towardViewer
            return (top, bottom, halfWidth)
        }
        func fits(_ h: CGFloat) -> Bool {
            let e = extent(phoneHeight: h)
            return e.top + e.bottom <= bounds.height && 2 * e.halfWidth <= bounds.width
        }

        // The largest phone whose folded drawing fits.
        var low: CGFloat = 0
        var high = bounds.height * 3
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if fits(mid) { low = mid } else { high = mid }
        }
        guard low > 1 else { return }
        let size = CGSize(width: low * aspect, height: low)
        let e = extent(phoneHeight: low)
        let hinge = CGPoint(x: bounds.midX, y: bounds.midY + (e.top - e.bottom) / 2)
        let flatSize = CGSize(width: size.width + 2 * outset, height: size.height + 2 * outset)

        flatArtView.transform = .identity
        flatArtView.frame = CGRect(x: hinge.x - flatSize.width / 2, y: hinge.y - flatSize.height / 2,
                                   width: flatSize.width, height: flatSize.height)
        layoutPhone(frame: CGRect(origin: CGPoint(x: outset, y: outset), size: size), variant: variant)
        layoutLineAndLock()
    }

    private func layoutLineAndLock() {
        let phone = phoneView.frame
        let distance = Layout.lineGap + Layout.lineWidth / 2
        lineLayer.frame = flatArtView.bounds
        lineLayer.path = Self.openOutlinePath(phone.insetBy(dx: -distance, dy: -distance),
                                              phoneCorners.inset(by: -distance, minimum: 0),
                                              breakWidth: Layout.lineBreak).cgPath

        let lockSize = Self.lockSymbol?.size ?? CGSize(width: Layout.lockPointSize, height: Layout.lockPointSize)
        lockView.bounds = CGRect(origin: .zero, size: lockSize)
        lockView.center = CGPoint(x: phone.midX, y: phone.maxY + distance)
    }

    /// The outline of a rounded rect, open in a `breakWidth` gap at its bottom center: from just
    /// right of the gap, around through the bottom-right, top and left, back to just left of it.
    private static func openOutlinePath(_ r: CGRect, _ c: Corners, breakWidth: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: r.midX + breakWidth / 2, y: r.maxY))
        path.addLine(to: CGPoint(x: r.maxX - c.bottomRight, y: r.maxY))
        path.addArc(withCenter: CGPoint(x: r.maxX - c.bottomRight, y: r.maxY - c.bottomRight), radius: c.bottomRight,
                    startAngle: .pi / 2, endAngle: 0, clockwise: false)
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + c.topRight))
        path.addArc(withCenter: CGPoint(x: r.maxX - c.topRight, y: r.minY + c.topRight), radius: c.topRight,
                    startAngle: 0, endAngle: -.pi / 2, clockwise: false)
        path.addLine(to: CGPoint(x: r.minX + c.topLeft, y: r.minY))
        path.addArc(withCenter: CGPoint(x: r.minX + c.topLeft, y: r.minY + c.topLeft), radius: c.topLeft,
                    startAngle: -.pi / 2, endAngle: -.pi, clockwise: false)
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - c.bottomLeft))
        path.addArc(withCenter: CGPoint(x: r.minX + c.bottomLeft, y: r.maxY - c.bottomLeft), radius: c.bottomLeft,
                    startAngle: .pi, endAngle: .pi / 2, clockwise: false)
        path.addLine(to: CGPoint(x: r.midX - breakWidth / 2, y: r.maxY))
        return path
    }

    // MARK: - Phone

    /// Each phone's width over its height, at real proportions.
    private static func phoneAspect(for variant: DeviceVariant) -> CGFloat {
        switch variant {
        case .homeButton: return 1 / 2.06
        case .notch: return 1 / 2.16
        case .dynamicIsland: return 1 / 2.17
        case .duoCover: return 1 / 1.455
        case .duoInnerUpright: return 1 / 1.42
        case .duoInnerSideways: return 1.42
        }
    }

    /// Corner radii, physical (the Duo's hinge is on its left whatever the language).
    private struct Corners {
        var topLeft: CGFloat, topRight: CGFloat, bottomRight: CGFloat, bottomLeft: CGFloat

        init(all r: CGFloat) { topLeft = r; topRight = r; bottomRight = r; bottomLeft = r }
        init(left: CGFloat, right: CGFloat) { topLeft = left; bottomLeft = left; topRight = right; bottomRight = right }

        func inset(by d: CGFloat, minimum: CGFloat) -> Corners {
            var c = self
            c.topLeft = max(minimum, topLeft - d); c.topRight = max(minimum, topRight - d)
            c.bottomRight = max(minimum, bottomRight - d); c.bottomLeft = max(minimum, bottomLeft - d)
            return c
        }
    }

    private static func roundedPath(_ r: CGRect, _ c: Corners) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: r.minX + c.topLeft, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - c.topRight, y: r.minY))
        path.addArc(withCenter: CGPoint(x: r.maxX - c.topRight, y: r.minY + c.topRight), radius: c.topRight,
                    startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c.bottomRight))
        path.addArc(withCenter: CGPoint(x: r.maxX - c.bottomRight, y: r.maxY - c.bottomRight), radius: c.bottomRight,
                    startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: r.minX + c.bottomLeft, y: r.maxY))
        path.addArc(withCenter: CGPoint(x: r.minX + c.bottomLeft, y: r.maxY - c.bottomLeft), radius: c.bottomLeft,
                    startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + c.topLeft))
        path.addArc(withCenter: CGPoint(x: r.minX + c.topLeft, y: r.minY + c.topLeft), radius: c.topLeft,
                    startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        path.close()
        return path
    }

    private func layoutPhone(frame: CGRect, variant: DeviceVariant) {
        let size = frame.size
        phoneView.frame = frame

        let shortSide = min(size.width, size.height)
        let isDuo = variant == .duoCover || variant == .duoInnerUpright || variant == .duoInnerSideways
        let frameWidth = Layout.phoneFrameWidth
        let corners: Corners
        switch variant {
        case .duoCover:
            corners = Corners(left: Layout.duoCoverHingeCornerRatio * size.width,
                              right: Layout.duoCoverOuterCornerRatio * size.width)
        case .duoInnerUpright, .duoInnerSideways:
            corners = Corners(all: Layout.duoInnerCornerRatio * shortSide)
        default:
            corners = Corners(all: Layout.phoneCornerRatio * shortSide)
        }
        phoneCorners = corners
        bodyLayer.frame = phoneView.bounds
        bodyLayer.path = Self.roundedPath(phoneView.bounds.insetBy(dx: frameWidth / 2, dy: frameWidth / 2),
                                          corners.inset(by: frameWidth / 2, minimum: 0)).cgPath

        // The screen sits inside the metal band and the bezel; a home-button phone has a
        // forehead and a chin and a square-cornered screen.
        let bezel = max(1.5, shortSide * Layout.phoneBezelRatio)
        let screen: CGRect
        let screenCorners: Corners
        if variant == .homeButton {
            let side = frameWidth + size.width * Layout.homeButtonSideBezelRatio
            let chin = size.height * Layout.homeButtonChinRatio
            screen = CGRect(x: side, y: chin, width: size.width - 2 * side, height: size.height - 2 * chin)
            screenCorners = Corners(all: 1.5)
        } else {
            screen = phoneView.bounds.insetBy(dx: frameWidth + bezel, dy: frameWidth + bezel)
            screenCorners = corners.inset(by: frameWidth + bezel, minimum: 1)
        }
        screenView.frame = screen
        screenLayer.frame = screenView.bounds
        screenLayer.path = Self.roundedPath(screenView.bounds, screenCorners).cgPath

        speakerView.isHidden = variant != .homeButton
        homeButtonView.isHidden = variant != .homeButton
        notchView.isHidden = variant != .notch
        islandView.isHidden = variant != .dynamicIsland
        cameraHoleView.isHidden = variant != .duoCover
        statusMarkView.isHidden = !isDuo
        creaseView.isHidden = variant != .duoInnerUpright && variant != .duoInnerSideways

        // Tiles are placed inside the screen; these insets are from its edges (physical sides).
        var tilesTop: CGFloat = 4
        let tilesBottomInset: CGFloat = 4
        let leftInset: CGFloat = 4
        var rightInset: CGFloat = 4
        switch variant {
        case .homeButton:
            let speaker = CGSize(width: size.width * 0.2, height: max(2, size.height * 0.012))
            speakerView.frame = CGRect(x: screen.midX - speaker.width / 2,
                                       y: screen.minY / 2 - speaker.height / 2,
                                       width: speaker.width, height: speaker.height)
            speakerView.layer.cornerRadius = speaker.height / 2
            let chin = size.height - screen.maxY
            let diameter = min(size.width * 0.16, chin * 0.66)
            homeButtonView.frame = CGRect(x: screen.midX - diameter / 2,
                                          y: screen.maxY + (chin - diameter) / 2,
                                          width: diameter, height: diameter)
            homeButtonView.layer.cornerRadius = diameter / 2
        case .notch:
            // iPhone 13: 162×33pt on a 390×844pt screen, hanging from the top edge.
            let notch = CGSize(width: screen.width * 0.415, height: max(4, screen.height * 0.039))
            notchView.frame = CGRect(x: screen.midX - notch.width / 2, y: screen.minY - 1,
                                     width: notch.width, height: notch.height + 1)
            notchView.layer.cornerRadius = notch.height * 0.55
            tilesTop = notch.height + 3
        case .dynamicIsland:
            // iPhone 17: 125×37pt, 11pt from the top of a 402×874pt screen.
            let island = CGSize(width: screen.width * 0.31, height: max(3.5, screen.height * 0.042))
            let islandTop = max(1, screen.height * 0.0126)
            islandView.frame = CGRect(x: screen.midX - island.width / 2, y: screen.minY + islandTop,
                                      width: island.width, height: island.height)
            islandView.layer.cornerRadius = island.height / 2
            tilesTop = islandTop + island.height + 3
        case .duoCover, .duoInnerUpright, .duoInnerSideways:
            // The 84pt status strip: down the physical right edge on the cover and held sideways
            // (on the cover the round camera at its top with the time under it), along the top
            // while the inner display is upright, with the time at its right end.
            if variant == .duoInnerUpright {
                let strip = screen.height * Layout.duoInnerUprightStripRatio
                let mark = CGSize(width: max(4, strip * 0.5), height: max(1.5, strip * 0.12))
                statusMarkView.frame = CGRect(x: screen.maxX - screen.width * 0.06 - mark.width,
                                              y: screen.minY + strip / 2 - mark.height / 2,
                                              width: mark.width, height: mark.height)
                statusMarkView.layer.cornerRadius = mark.height / 2
                tilesTop = strip
            } else {
                let stripRatio = variant == .duoCover ? Layout.duoCoverStripRatio : Layout.duoInnerSidewaysStripRatio
                let strip = screen.width * stripRatio
                let stripMidX = screen.maxX - strip / 2
                var markTop = screen.minY + screen.width * 0.06
                if variant == .duoCover {
                    // About 38pt across, its center 0.09 of the width from the screen's top.
                    let diameter = screen.width * 0.08
                    cameraHoleView.frame = CGRect(x: stripMidX - diameter / 2,
                                                  y: screen.minY + screen.width * 0.09 - diameter / 2,
                                                  width: diameter, height: diameter)
                    cameraHoleView.layer.cornerRadius = diameter / 2
                    markTop = cameraHoleView.frame.maxY + diameter * 0.45
                }
                let mark = CGSize(width: strip * 0.5, height: max(1.5, strip * 0.12))
                statusMarkView.frame = CGRect(x: stripMidX - mark.width / 2, y: markTop,
                                              width: mark.width, height: mark.height)
                statusMarkView.layer.cornerRadius = mark.height / 2
                rightInset = strip
            }
            if variant == .duoInnerSideways {
                creaseView.frame = CGRect(x: phoneView.bounds.midX - 0.5, y: screen.minY, width: 1, height: screen.height)
            } else if variant == .duoInnerUpright {
                creaseView.frame = CGRect(x: screen.minX, y: phoneView.bounds.midY - 0.5, width: screen.width, height: 1)
            }
        }
        layoutTiles(in: screen, corners: screenCorners, top: tilesTop, bottomInset: tilesBottomInset,
                    leftInset: leftInset, rightInset: rightInset, variant: variant)
    }

    /// Lays the tiles out in uneven columns. A tile corner in one of the screen's corners takes
    /// the screen's radius minus its distance to the screen's edge, so it stays concentric;
    /// the other corners keep the small standard radius.
    private func layoutTiles(in inner: CGRect, corners screen: Corners, top: CGFloat, bottomInset: CGFloat,
                             leftInset: CGFloat, rightInset: CGFloat, variant: DeviceVariant) {
        let columns: Int
        switch variant {
        case .duoInnerUpright: columns = 3
        case .duoInnerSideways: columns = 4
        default: columns = 2
        }
        guard let weights = Self.columnWeights[columns] else { return }
        let gap: CGFloat = min(inner.width, inner.height) >= 90 ? 3 : 2.5
        let columnWidth = (inner.width - leftInset - rightInset - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let columnTop = inner.minY + top
        let columnHeight = inner.maxY - bottomInset - columnTop
        guard columnWidth > 0, columnHeight > 0 else { return }
        let radius = min(Layout.tileRadius, columnWidth * 0.12)

        for (column, columnWeights) in weights.enumerated() {
            let available = columnHeight - CGFloat(columnWeights.count - 1) * gap
            let total = columnWeights.reduce(0, +)
            let x = inner.minX + leftInset + CGFloat(column) * (columnWidth + gap)
            var y = columnTop
            let isFirstColumn = column == 0
            let isLastColumn = column == columns - 1
            for (row, weight) in columnWeights.enumerated() {
                // Row-major photo order, so the same neighbors sit side by side in every variant.
                let index = row * columns + column
                guard index < tileViews.count else { continue }
                let isFirstRow = row == 0
                let isLastRow = row == columnWeights.count - 1
                func concentric(_ screenRadius: CGFloat, _ dx: CGFloat, _ dy: CGFloat, _ inCorner: Bool) -> CGFloat {
                    inCorner ? max(radius, screenRadius - max(dx, dy)) : radius
                }
                var c = Corners(all: radius)
                c.topLeft = concentric(screen.topLeft, leftInset, top, isFirstColumn && isFirstRow)
                c.topRight = concentric(screen.topRight, rightInset, top, isLastColumn && isFirstRow)
                c.bottomLeft = concentric(screen.bottomLeft, leftInset, bottomInset, isFirstColumn && isLastRow)
                c.bottomRight = concentric(screen.bottomRight, rightInset, bottomInset, isLastColumn && isLastRow)

                let height = available * weight / total
                let tile = tileViews[index]
                tile.frame = CGRect(x: x, y: y, width: columnWidth, height: height)
                tileCorners[index] = c
                renderTile(at: index)
                y += height + gap
            }
        }
    }

    /// Draws a tile's photo aspect-filled and cut to the tile's corners (gray until the photo arrives).
    private func renderTile(at index: Int) {
        let tile = tileViews[index]
        let size = tile.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let format = UIGraphicsImageRendererFormat()
        format.scale = traitCollection.displayScale
        format.opaque = false
        let path = Self.roundedPath(CGRect(origin: .zero, size: size), tileCorners[index])
        let photo = samplePhotos[index]
        let placeholder = UIColor.systemGray5.resolvedColor(with: traitCollection)
        tile.image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            path.addClip()
            guard let photo, photo.size.width > 0, photo.size.height > 0 else {
                placeholder.setFill()
                path.fill()
                return
            }
            let scale = max(size.width / photo.size.width, size.height / photo.size.height)
            let drawn = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
            photo.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
    }

    // MARK: - Enlarged photo

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard photoOverlay == nil, let index = tileIndex(at: gesture), let photo = samplePhotos[index],
              let start = tileFrameInWindow(index) else { return }
        showPhoto(photo, tileIndex: index, from: start)
    }

    /// Where the folded halves sit in the flat art (each half is a crop of it).
    private func halfOrigins() -> [(UIImageView, CGPoint)] {
        let size = flatArtView.bounds.size
        let isBook = phoneBuiltFor?.variant == .duoInnerSideways
        let second = isBook ? CGPoint(x: size.width / 2, y: 0) : CGPoint(x: 0, y: size.height / 2)
        // The half drawn on top first, as hit testing would.
        return [(secondHalfView, second), (firstHalfView, .zero)]
    }

    /// The tile under the tap. While folded the tap lands on a tilted half; UIKit's conversion
    /// undoes the perspective, so the point maps back onto the flat art.
    private func tileIndex(at gesture: UITapGestureRecognizer) -> Int? {
        let phonePoint: CGPoint
        if foldedView.isHidden {
            phonePoint = gesture.location(in: phoneView)
        } else {
            let hits = halfOrigins().compactMap { half, origin -> CGPoint? in
                let point = gesture.location(in: half)
                guard half.bounds.contains(point) else { return nil }
                return CGPoint(x: point.x + origin.x, y: point.y + origin.y)
            }
            guard let flatPoint = hits.first else { return nil }
            phonePoint = flatArtView.convert(flatPoint, to: phoneView)
        }
        return tileViews.firstIndex { $0.frame.insetBy(dx: -1.5, dy: -1.5).contains(phonePoint) }
    }

    /// The tile's frame on screen: the tile itself, or while folded where the tilted half shows it.
    private func tileFrameInWindow(_ index: Int) -> CGRect? {
        guard let window else { return nil }
        let tile = tileViews[index]
        guard !foldedView.isHidden else { return tile.convert(tile.bounds, to: window) }
        let flatRect = tile.convert(tile.bounds, to: flatArtView)
        let center = CGPoint(x: flatRect.midX, y: flatRect.midY)
        // The half that holds the tile's center draws it.
        guard let (half, origin) = halfOrigins().first(where: { half, origin in
            half.bounds.contains(CGPoint(x: center.x - origin.x, y: center.y - origin.y))
        }) else { return nil }
        return half.convert(flatRect.offsetBy(dx: -origin.x, dy: -origin.y), to: window)
    }

    /// Hides or shows the tile under the enlarged photo; while folded the halves are redrawn
    /// so the photo leaves its spot there too.
    private func setTileLifted(_ index: Int, _ lifted: Bool) {
        tileViews[index].alpha = lifted ? 0 : 1
        refreshFoldedSnapshot()
    }

    /// Grows the photo out of its tile into a large rounded square over a blur; a tap anywhere
    /// shrinks it back into the tile.
    private func showPhoto(_ photo: UIImage, tileIndex index: Int, from start: CGRect) {
        guard let window else { return }
        HapticFeedbackManager.shared.impact(intensity: .light)

        let overlay = UIView(frame: window.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let blurView = UIVisualEffectView(effect: nil)
        blurView.frame = overlay.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addSubview(blurView)

        let imageView = UIImageView(image: photo)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerCurve = .continuous
        imageView.layer.cornerRadius = Layout.tileRadius
        imageView.frame = start
        overlay.addSubview(imageView)
        overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleOverlayTap)))
        window.addSubview(overlay)
        photoOverlay = overlay
        enlargedTileIndex = index
        setTileLifted(index, true)

        let safe = window.bounds.inset(by: window.safeAreaInsets)
        let side = min(safe.width - 2 * GeneralConstants.EdgePadding.content,
                       safe.height - 2 * GeneralConstants.EdgePadding.content, 420)
        let aspect = photo.size.height > 0 ? photo.size.width / photo.size.height : 1
        let target = CGSize(width: aspect >= 1 ? side : side * aspect, height: aspect >= 1 ? side / aspect : side)
        let end = CGRect(x: safe.midX - target.width / 2, y: safe.midY - target.height / 2,
                         width: target.width, height: target.height)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8) {
            blurView.effect = UIBlurEffect(style: .systemThinMaterial)
            imageView.frame = end
            imageView.layer.cornerRadius = GeneralConstants.CornerRadius.card * 1.5
        }
    }

    @objc private func handleOverlayTap() {
        dismissPhoto(animated: true)
    }

    private func dismissPhoto(animated: Bool) {
        guard let overlay = photoOverlay else { return }
        photoOverlay = nil
        let index = enlargedTileIndex
        enlargedTileIndex = nil
        let blurView = overlay.subviews.first as? UIVisualEffectView
        let imageView = overlay.subviews.last as? UIImageView
        let finish = { [weak self] in
            overlay.removeFromSuperview()
            if let index { self?.setTileLifted(index, false) }
        }
        // The tile may have moved (a fold or unfold) while the photo was open.
        guard animated, let index, overlay.window != nil, let end = tileFrameInWindow(index) else {
            finish()
            return
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
            blurView?.effect = nil
            imageView?.frame = end
            imageView?.layer.cornerRadius = Layout.tileRadius
        }, completion: { _ in finish() })
    }

    // MARK: - Folded phone

    private enum Fold {
        /// How far each half turns around the hinge, in degrees.
        static let bookAngle: CGFloat = 28
        static let raisedHalfAngle: CGFloat = 12
        static let baseAngle: CGFloat = 52
        /// Perspective depth as a multiple of the phone's long side, and the scale that keeps
        /// the nearer edges inside the art's bounds.
        static let perspectiveDepth: CGFloat = 2.6
        static let scale: CGFloat = 0.94
    }

    /// The inner display while the device is partly folded (the book or the table pose).
    private func isPartlyFolded(_ variant: DeviceVariant) -> Bool {
        guard variant == .duoInnerSideways || variant == .duoInnerUpright, let window = window else { return false }
        return FoldRegion.activeFold(in: window) != nil
    }

    private func updateFoldedPhone(folded: Bool, variant: DeviceVariant) {
        guard folded else {
            foldedView.isHidden = true
            flatArtView.isHidden = false
            return
        }
        // The flat art (line, phone and lock) folds as one; its center is the phone's hinge.
        let size = flatArtView.bounds.size
        let phoneSize = phoneView.bounds.size
        foldedView.transform = .identity
        foldedView.frame = flatArtView.frame
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / (max(phoneSize.width, phoneSize.height) * Fold.perspectiveDepth)
        foldedView.layer.sublayerTransform = CATransform3DScale(perspective, Fold.scale, Fold.scale, 1)

        let hinge = CGPoint(x: size.width / 2, y: size.height / 2)
        func place(_ half: UIImageView, bounds: CGSize, anchor: CGPoint, transform: CATransform3D) {
            half.layer.transform = CATransform3DIdentity
            half.layer.anchorPoint = anchor
            half.bounds = CGRect(origin: .zero, size: bounds)
            half.layer.position = hinge
            half.layer.transform = transform
        }
        let radians = { (degrees: CGFloat) in degrees * .pi / 180 }
        if variant == .duoInnerSideways {
            // A book: the outer edges come toward the viewer, the hinge stays back.
            let half = CGSize(width: size.width / 2, height: size.height)
            place(firstHalfView, bounds: half, anchor: CGPoint(x: 1, y: 0.5),
                  transform: CATransform3DMakeRotation(radians(Fold.bookAngle), 0, 1, 0))
            place(secondHalfView, bounds: half, anchor: CGPoint(x: 0, y: 0.5),
                  transform: CATransform3DMakeRotation(-radians(Fold.bookAngle), 0, 1, 0))
        } else {
            // A laptop: the raised half leans back a little, the base lies toward the viewer.
            let half = CGSize(width: size.width, height: size.height / 2)
            place(firstHalfView, bounds: half, anchor: CGPoint(x: 0.5, y: 1),
                  transform: CATransform3DMakeRotation(radians(Fold.raisedHalfAngle), 1, 0, 0))
            place(secondHalfView, bounds: half, anchor: CGPoint(x: 0.5, y: 0),
                  transform: CATransform3DMakeRotation(radians(Fold.baseAngle), 1, 0, 0))
        }
        refreshFoldedSnapshot()
        foldedView.isHidden = false
        flatArtView.isHidden = true
    }

    /// Draws the flat art (line, phone and lock) and hands each half its part. Runs again when the photos arrive
    /// and when the appearance changes.
    private func refreshFoldedSnapshot() {
        guard phoneBuiltFor?.isFolded == true, flatArtView.bounds.width > 0 else { return }
        let format = UIGraphicsImageRendererFormat()
        format.scale = traitCollection.displayScale
        format.opaque = false
        // A hidden layer renders nothing, and the flat art is hidden while folded.
        let wasHidden = flatArtView.isHidden
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flatArtView.isHidden = false
        let image = UIGraphicsImageRenderer(bounds: flatArtView.bounds, format: format).image { context in
            flatArtView.layer.render(in: context.cgContext)
        }
        flatArtView.isHidden = wasHidden
        CATransaction.commit()
        guard let cgImage = image.cgImage else { return }
        let scale = image.scale
        let size = flatArtView.bounds.size
        let isBook = phoneBuiltFor?.variant == .duoInnerSideways
        let first = isBook ? CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)
                           : CGRect(x: 0, y: 0, width: size.width, height: size.height / 2)
        let second = isBook ? CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height)
                            : CGRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2)
        func crop(_ rect: CGRect) -> UIImage? {
            let pixels = CGRect(x: rect.minX * scale, y: rect.minY * scale,
                                width: rect.width * scale, height: rect.height * scale).integral
            return cgImage.cropping(to: pixels).map { UIImage(cgImage: $0, scale: scale, orientation: .up) }
        }
        firstHalfView.image = crop(first)
        secondHalfView.image = crop(second)
    }

    // MARK: - Colors

    private func applyColors() {
        // The lock's image carries its color: the folded snapshot's render(in:) doesn't tint.
        let green = UIColor.systemGreen.resolvedColor(with: traitCollection)
        lineLayer.strokeColor = green.cgColor
        lockView.image = Self.lockSymbol?.withTintColor(green, renderingMode: .alwaysOriginal)
        // The metal band and the home button's ring.
        let metal = UIColor.systemGray2.resolvedColor(with: traitCollection).cgColor
        bodyLayer.strokeColor = metal
        homeButtonView.layer.borderColor = metal
        screenLayer.fillColor = Self.screenColor.resolvedColor(with: traitCollection).cgColor
        // The gray placeholder before the photos arrive.
        if samplePhotos.contains(where: { $0 == nil }) {
            tileViews.indices.forEach(renderTile(at:))
        }
        refreshFoldedSnapshot()
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Shield art") {
        struct ArtPreview: UIViewRepresentable {
            func makeUIView(context: Context) -> PrivacyShieldArtView {
                PrivacyShieldArtView()
            }
            func updateUIView(_ uiView: PrivacyShieldArtView, context: Context) {}
        }
        return ArtPreview()
            .frame(width: 354, height: 330)
    }
#endif
