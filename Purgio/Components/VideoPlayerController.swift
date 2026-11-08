//
//  VideoPlayerController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.02.2026.
//

import AVFoundation
import Photos
import UIKit

private enum Strings {
    static let mute = NSLocalizedString("videoPlayer.mute", comment: "Mute video button accessibility label")
    static let unmute = NSLocalizedString("videoPlayer.unmute", comment: "Unmute video button accessibility label")
}

final class VideoPlayerController {

    /// `.overlay`: an 80pt play button and one blurred bar (today's portrait look).
    /// `.split`: `controlsContainer` turns into a transparent host for two glass capsules
    /// (play + scrubber + time | mute + duration) that can split around the iPhone Duo fold.
    /// Alpha and visibility set on `controlsContainer` apply to both capsules.
    enum ControlsLayout {
        case overlay
        case split
    }

    private enum SplitLayout {
        static let capsuleHeight: CGFloat = 52
        static let buttonSize: CGFloat = 40
        static let buttonInset: CGFloat = 6
        static let defaultGap: CGFloat = 12
        static let previewSize = CGSize(width: 128, height: 72)
    }

    struct Configuration {
        var videoGravity: AVLayerVideoGravity
        var layerCornerRadius: CGFloat
        var controlsAutoHide: Bool

        init(
            videoGravity: AVLayerVideoGravity = .resizeAspect,
            layerCornerRadius: CGFloat = 0,
            controlsAutoHide: Bool = false
        ) {
            self.videoGravity = videoGravity
            self.layerCornerRadius = layerCornerRadius
            self.controlsAutoHide = controlsAutoHide
        }
    }

    enum PlaybackState {
        case idle
        case loading
        case ready
        case failed(Error?)
        case ended
    }
    
    let playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let controlsContainer: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 12
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        view.alpha = 0
        view.isUserInteractionEnabled = true
        return view
    }()

    private(set) var playerLayer: AVPlayerLayer?

    var isPlaying: Bool { _isPlaying }

    var onStateChanged: ((PlaybackState) -> Void)?
    var onPlayTappedWithoutPlayer: (() -> Void)?
    var onICloudPlayAttempt: (() -> Void)?

    var iCloudLoadFailed = false

    private let playButtonBlurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 40
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }()

    private let progressSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        return slider
    }()

    private let currentTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.text = "0:00"
        return label
    }()

    private let durationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.text = "0:00"
        return label
    }()

    private(set) var controlsLayout: ControlsLayout = .overlay
    private var overlayInternalConstraints: [NSLayoutConstraint] = []
    private var splitInternalConstraints: [NSLayoutConstraint] = []
    private var splitEqualConstraints: [NSLayoutConstraint] = []
    private var splitLeadingEndConstraint: NSLayoutConstraint?
    private var splitTrailingStartConstraint: NSLayoutConstraint?
    private var splitPlayButtonSizeConstraints: [NSLayoutConstraint] = []
    private var scrubPreviewCenterXConstraint: NSLayoutConstraint?
    private var imageGenerator: AVAssetImageGenerator?
    private var previewRequestID = 0
    private var isMuted = false

    private lazy var leadingCapsule: UIVisualEffectView = Self.makeCapsule()
    private lazy var trailingCapsule: UIVisualEffectView = Self.makeCapsule()

    private let muteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        button.layer.cornerRadius = SplitLayout.buttonSize / 2
        button.layer.cornerCurve = .continuous
        return button
    }()

    private let scrubPreview: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }()

    private let scrubPreviewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black
        imageView.layer.cornerRadius = 12
        imageView.layer.cornerCurve = .continuous
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.white.cgColor
        return imageView
    }()

    private let scrubPreviewTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.5
        label.layer.shadowRadius = 2
        label.layer.shadowOffset = .zero
        return label
    }()

    private let configuration: Configuration
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var endOfPlaybackObserver: NSObjectProtocol?
    private var _isPlaying = false
    private var isSeeking = false
    private var pendingSeekValue: Float?
    private var autoHideWorkItem: DispatchWorkItem?

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        setupSliderActions()
        setupUI()
        setupConstraints()
    }

    private func setupUI() {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.layer.cornerRadius = 40
        playPauseButton.layer.cornerCurve = .continuous

        playPauseButton.insertSubview(playButtonBlurView, at: 0)
        
        controlsContainer.contentView.addSubview(progressSlider)
        controlsContainer.contentView.addSubview(currentTimeLabel)
        controlsContainer.contentView.addSubview(durationLabel)
        
        playPauseButton.imageView?.layer.zPosition = 1

        playPauseButton.addTarget(self, action: #selector(handlePlayPauseTap), for: .touchUpInside)
        muteButton.addTarget(self, action: #selector(handleMuteTap), for: .touchUpInside)
        updateMuteIcon()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            playButtonBlurView.topAnchor.constraint(equalTo: playPauseButton.topAnchor),
            playButtonBlurView.bottomAnchor.constraint(equalTo: playPauseButton.bottomAnchor),
            playButtonBlurView.leadingAnchor.constraint(equalTo: playPauseButton.leadingAnchor),
            playButtonBlurView.trailingAnchor.constraint(equalTo: playPauseButton.trailingAnchor)
        ])
        activateOverlayInternalConstraints()
    }

    private func activateOverlayInternalConstraints() {
        overlayInternalConstraints = [
            progressSlider.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 8),
            progressSlider.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),
            progressSlider.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),

            currentTimeLabel.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 12),
            currentTimeLabel.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),

            durationLabel.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -12),
            durationLabel.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor)
        ]
        NSLayoutConstraint.activate(overlayInternalConstraints)
    }

    private static func makeCapsule() -> UIVisualEffectView {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.tintColor = UIColor.black.withAlphaComponent(0.35)
            effect = glass
        } else {
            effect = UIBlurEffect(style: .systemThinMaterialDark)
        }
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = SplitLayout.capsuleHeight / 2
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        return view
    }

    // MARK: - Controls Layout

    /// Switches between the overlay bar and the split capsules. On `.overlay` the play button
    /// is taken out of the capsule; the owner adds it back where it shows the 80pt button.
    func setControlsLayout(_ layout: ControlsLayout) {
        guard layout != controlsLayout else { return }
        controlsLayout = layout
        let host = controlsContainer.contentView

        switch layout {
        case .split:
            NSLayoutConstraint.deactivate(overlayInternalConstraints)
            controlsContainer.effect = nil
            controlsContainer.layer.cornerRadius = 0
            controlsContainer.layer.masksToBounds = false
            controlsContainer.clipsToBounds = false

            host.addSubview(leadingCapsule)
            host.addSubview(trailingCapsule)
            host.addSubview(scrubPreview)
            scrubPreview.addSubview(scrubPreviewImageView)
            scrubPreview.addSubview(scrubPreviewTimeLabel)

            playPauseButton.removeFromSuperview()
            leadingCapsule.contentView.addSubview(playPauseButton)
            leadingCapsule.contentView.addSubview(progressSlider)
            leadingCapsule.contentView.addSubview(currentTimeLabel)
            trailingCapsule.contentView.addSubview(muteButton)
            trailingCapsule.contentView.addSubview(durationLabel)

            let leadingEnd = leadingCapsule.trailingAnchor.constraint(equalTo: host.leadingAnchor)
            let trailingStart = trailingCapsule.leadingAnchor.constraint(equalTo: host.leadingAnchor)
            splitLeadingEndConstraint = leadingEnd
            splitTrailingStartConstraint = trailingStart
            splitEqualConstraints = [
                leadingCapsule.widthAnchor.constraint(equalTo: trailingCapsule.widthAnchor),
                trailingCapsule.leadingAnchor.constraint(
                    equalTo: leadingCapsule.trailingAnchor, constant: SplitLayout.defaultGap)
            ]
            splitPlayButtonSizeConstraints = [
                playPauseButton.widthAnchor.constraint(equalToConstant: SplitLayout.buttonSize),
                playPauseButton.heightAnchor.constraint(equalToConstant: SplitLayout.buttonSize)
            ]
            let previewCenterX = scrubPreview.centerXAnchor.constraint(equalTo: host.leadingAnchor)
            scrubPreviewCenterXConstraint = previewCenterX

            let leadingContent = leadingCapsule.contentView
            let trailingContent = trailingCapsule.contentView
            splitInternalConstraints = splitPlayButtonSizeConstraints + splitEqualConstraints + [
                leadingCapsule.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                leadingCapsule.topAnchor.constraint(equalTo: host.topAnchor),
                leadingCapsule.bottomAnchor.constraint(equalTo: host.bottomAnchor),
                trailingCapsule.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                trailingCapsule.topAnchor.constraint(equalTo: host.topAnchor),
                trailingCapsule.bottomAnchor.constraint(equalTo: host.bottomAnchor),

                playPauseButton.leadingAnchor.constraint(
                    equalTo: leadingContent.leadingAnchor, constant: SplitLayout.buttonInset),
                playPauseButton.centerYAnchor.constraint(equalTo: leadingContent.centerYAnchor),
                progressSlider.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 12),
                progressSlider.trailingAnchor.constraint(equalTo: currentTimeLabel.leadingAnchor, constant: -12),
                progressSlider.centerYAnchor.constraint(equalTo: leadingContent.centerYAnchor),
                currentTimeLabel.trailingAnchor.constraint(equalTo: leadingContent.trailingAnchor, constant: -16),
                currentTimeLabel.centerYAnchor.constraint(equalTo: leadingContent.centerYAnchor),

                muteButton.leadingAnchor.constraint(
                    equalTo: trailingContent.leadingAnchor, constant: SplitLayout.buttonInset),
                muteButton.centerYAnchor.constraint(equalTo: trailingContent.centerYAnchor),
                muteButton.widthAnchor.constraint(equalToConstant: SplitLayout.buttonSize),
                muteButton.heightAnchor.constraint(equalToConstant: SplitLayout.buttonSize),
                durationLabel.leadingAnchor.constraint(
                    greaterThanOrEqualTo: muteButton.trailingAnchor, constant: 8),
                durationLabel.trailingAnchor.constraint(equalTo: trailingContent.trailingAnchor, constant: -16),
                durationLabel.centerYAnchor.constraint(equalTo: trailingContent.centerYAnchor),

                previewCenterX,
                scrubPreview.bottomAnchor.constraint(equalTo: leadingCapsule.topAnchor, constant: -8),
                scrubPreviewImageView.topAnchor.constraint(equalTo: scrubPreview.topAnchor),
                scrubPreviewImageView.leadingAnchor.constraint(equalTo: scrubPreview.leadingAnchor),
                scrubPreviewImageView.trailingAnchor.constraint(equalTo: scrubPreview.trailingAnchor),
                scrubPreviewImageView.widthAnchor.constraint(equalToConstant: SplitLayout.previewSize.width),
                scrubPreviewImageView.heightAnchor.constraint(equalToConstant: SplitLayout.previewSize.height),
                scrubPreviewTimeLabel.topAnchor.constraint(equalTo: scrubPreviewImageView.bottomAnchor, constant: 4),
                scrubPreviewTimeLabel.centerXAnchor.constraint(equalTo: scrubPreview.centerXAnchor),
                scrubPreviewTimeLabel.bottomAnchor.constraint(equalTo: scrubPreview.bottomAnchor)
            ]
            NSLayoutConstraint.activate(splitInternalConstraints)

            playButtonBlurView.isHidden = true
            playPauseButton.backgroundColor = .white
            playPauseButton.tintColor = .black
            playPauseButton.layer.cornerRadius = SplitLayout.buttonSize / 2

        case .overlay:
            hideScrubPreview()
            NSLayoutConstraint.deactivate(splitInternalConstraints + [
                splitLeadingEndConstraint, splitTrailingStartConstraint
            ].compactMap { $0 })
            splitInternalConstraints = []

            playPauseButton.removeFromSuperview()
            muteButton.removeFromSuperview()
            leadingCapsule.removeFromSuperview()
            trailingCapsule.removeFromSuperview()
            scrubPreview.removeFromSuperview()

            controlsContainer.effect = UIBlurEffect(style: .systemThinMaterialDark)
            controlsContainer.layer.cornerRadius = 12
            controlsContainer.layer.masksToBounds = true
            host.addSubview(progressSlider)
            host.addSubview(currentTimeLabel)
            host.addSubview(durationLabel)
            activateOverlayInternalConstraints()

            playButtonBlurView.isHidden = false
            playPauseButton.backgroundColor = .clear
            playPauseButton.tintColor = .white
            playPauseButton.layer.cornerRadius = 40
        }
        updatePlayPauseIcon()
    }

    /// Split mode: where the leading capsule ends and the trailing one starts, measured from
    /// the controls' leading edge. Nil gives two equal halves.
    func setSplit(leadingEnd: CGFloat?, trailingStart: CGFloat?) {
        guard controlsLayout == .split,
              let leadingEndConstraint = splitLeadingEndConstraint,
              let trailingStartConstraint = splitTrailingStartConstraint else { return }

        if let leadingEnd = leadingEnd, let trailingStart = trailingStart {
            if splitEqualConstraints.first?.isActive == true { NSLayoutConstraint.deactivate(splitEqualConstraints) }
            if leadingEndConstraint.constant != leadingEnd { leadingEndConstraint.constant = leadingEnd }
            if trailingStartConstraint.constant != trailingStart { trailingStartConstraint.constant = trailingStart }
            if !leadingEndConstraint.isActive { NSLayoutConstraint.activate([leadingEndConstraint, trailingStartConstraint]) }
        } else {
            if leadingEndConstraint.isActive { NSLayoutConstraint.deactivate([leadingEndConstraint, trailingStartConstraint]) }
            if splitEqualConstraints.first?.isActive == false { NSLayoutConstraint.activate(splitEqualConstraints) }
        }
    }

    private func setupSliderActions() {
        progressSlider.addTarget(self, action: #selector(handleSliderChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(handleSliderTouchBegan), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(handleSliderTouchEnded), for: [.touchUpInside, .touchUpOutside])
    }


    func loadVideo(from asset: PHAsset, using imageManager: PHCachingImageManager, allowNetworkAccess: Bool) {
        cleanup()
        onStateChanged?(.loading)

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = allowNetworkAccess
        options.deliveryMode = .highQualityFormat

        imageManager.requestPlayerItem(forVideo: asset, options: options) { [weak self] playerItem, info in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let playerItem = playerItem {
                    self.setupPlayer(with: playerItem)
                } else {
                    let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool ?? false
                    let error = info?[PHImageErrorKey] as? Error
                    if isInCloud {
                        self.iCloudLoadFailed = true
                    }
                    self.onStateChanged?(.failed(error))
                }
            }
        }
    }

    func loadPlayerItem(_ playerItem: AVPlayerItem) {
        cleanup()
        onStateChanged?(.loading)
        setupPlayer(with: playerItem)
    }

    func play() {
        guard player != nil else { return }
        player?.play()
        _isPlaying = true
        updatePlayPauseIcon()
        scheduleAutoHide()
    }

    func pause() {
        player?.pause()
        _isPlaying = false
        updatePlayPauseIcon()
        cancelAutoHide()
    }

    func togglePlayPause() {
        if _isPlaying {
            pause()
        } else {
            play()
        }
    }

    func cleanup() {
        cancelAutoHide()

        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        statusObservation?.invalidate()
        statusObservation = nil

        if let observer = endOfPlaybackObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfPlaybackObserver = nil
        }

        imageGenerator?.cancelAllCGImageGeneration()
        imageGenerator = nil
        hideScrubPreview()

        player?.pause()
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        _isPlaying = false
        iCloudLoadFailed = false
        isSeeking = false
        pendingSeekValue = nil

        progressSlider.value = 0
        currentTimeLabel.text = "0:00"
        durationLabel.text = "0:00"

        updatePlayPauseIcon()
    }

    func setControlsVisible(_ visible: Bool, animated: Bool) {
        let alpha: CGFloat = visible ? 1.0 : 0
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.controlsContainer.alpha = alpha
            }
        } else {
            controlsContainer.alpha = alpha
        }
    }

    private func setupPlayer(with playerItem: AVPlayerItem) {
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = isMuted
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = configuration.videoGravity
        if configuration.layerCornerRadius > 0 {
            layer.cornerRadius = configuration.layerCornerRadius
            layer.cornerCurve = .continuous
            layer.masksToBounds = true
        }

        self.player = player
        self.playerLayer = layer

        // Observe status for readyToPlay
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self.setupTimeObserver()
                    self.statusObservation = nil
                    self.onStateChanged?(.ready)
                case .failed:
                    self.onStateChanged?(.failed(item.error))
                default:
                    break
                }
            }
        }

        endOfPlaybackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self._isPlaying = false
            self.player?.seek(to: .zero)
            self.updatePlayPauseIcon()
            self.onStateChanged?(.ended)
        }

        _isPlaying = false
        updatePlayPauseIcon()
    }

    private func setupTimeObserver() {
        guard let player = player, let duration = player.currentItem?.duration else { return }

        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite else { return }

        progressSlider.maximumValue = Float(durationSeconds)
        durationLabel.text = DateFormatterManager.shared.formatVideoDuration(durationSeconds)

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentSeconds = CMTimeGetSeconds(time)
            if currentSeconds.isFinite {
                self.progressSlider.value = Float(currentSeconds)
                self.currentTimeLabel.text = DateFormatterManager.shared.formatVideoDuration(currentSeconds)
            }
        }
    }

    private func updatePlayPauseIcon() {
        let iconName = _isPlaying ? "pause.fill" : "play.fill"
        let pointSize: CGFloat = controlsLayout == .split ? 18 : 28
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        playPauseButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
    }

    private func updateMuteIcon() {
        let iconName = isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        muteButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
        muteButton.accessibilityLabel = isMuted ? Strings.unmute : Strings.mute
    }

    @objc private func handleMuteTap() {
        isMuted.toggle()
        player?.isMuted = isMuted
        updateMuteIcon()
        HapticFeedbackManager.shared.impact(intensity: .light)
        if _isPlaying { scheduleAutoHide() }
        controlsContainer.alpha = 1.0
    }

    // MARK: - Scrub Preview

    private func showScrubPreview() {
        guard controlsLayout == .split, player != nil else { return }
        scrubPreview.isHidden = false
        updateScrubPreview()
    }

    private func hideScrubPreview() {
        scrubPreview.isHidden = true
        scrubPreviewImageView.image = nil
        imageGenerator?.cancelAllCGImageGeneration()
    }

    private func updateScrubPreview() {
        guard controlsLayout == .split, !scrubPreview.isHidden, let item = player?.currentItem else { return }
        let host = controlsContainer.contentView
        let value = progressSlider.value
        scrubPreviewTimeLabel.text = DateFormatterManager.shared.formatVideoDuration(Double(value))

        // Follow the thumb, kept inside the controls' width
        let thumb = progressSlider.thumbRect(
            forBounds: progressSlider.bounds,
            trackRect: progressSlider.trackRect(forBounds: progressSlider.bounds),
            value: value)
        let thumbInHost = progressSlider.convert(thumb, to: host)
        let isLeftToRight = host.effectiveUserInterfaceLayoutDirection == .leftToRight
        let fromLeading = isLeftToRight ? thumbInHost.midX : host.bounds.width - thumbInHost.midX
        let halfWidth = SplitLayout.previewSize.width / 2
        let clamped = min(max(fromLeading, halfWidth), max(halfWidth, host.bounds.width - halfWidth))
        scrubPreviewCenterXConstraint?.constant = clamped

        let generator: AVAssetImageGenerator
        if let existing = imageGenerator {
            generator = existing
        } else {
            generator = AVAssetImageGenerator(asset: item.asset)
            generator.appliesPreferredTrackTransform = true
            let scale = host.traitCollection.displayScale
            generator.maximumSize = CGSize(
                width: SplitLayout.previewSize.width * 2 * scale, height: SplitLayout.previewSize.height * 2 * scale)
            let tolerance = CMTime(seconds: 0.3, preferredTimescale: 600)
            generator.requestedTimeToleranceBefore = tolerance
            generator.requestedTimeToleranceAfter = tolerance
            imageGenerator = generator
        }

        generator.cancelAllCGImageGeneration()
        previewRequestID += 1
        let requestID = previewRequestID
        let time = NSValue(time: CMTime(seconds: Double(value), preferredTimescale: 600))
        generator.generateCGImagesAsynchronously(forTimes: [time]) { [weak self] _, cgImage, _, result, _ in
            guard result == .succeeded, let cgImage = cgImage else { return }
            let image = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                guard let self = self, requestID == self.previewRequestID, !self.scrubPreview.isHidden else { return }
                self.scrubPreviewImageView.image = image
            }
        }
    }

    private func scheduleAutoHide() {
        guard configuration.controlsAutoHide else { return }
        cancelAutoHide()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self._isPlaying else { return }
            UIView.animate(withDuration: 0.3) {
                self.controlsContainer.alpha = 0.5
            }
        }
        autoHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private func cancelAutoHide() {
        autoHideWorkItem?.cancel()
        autoHideWorkItem = nil
    }

    @objc private func handlePlayPauseTap() {
        if iCloudLoadFailed {
            onICloudPlayAttempt?()
            return
        }

        guard player != nil else {
            onPlayTappedWithoutPlayer?()
            return
        }

        if _isPlaying {
            pause()
            UIView.animate(withDuration: 0.3) {
                self.controlsContainer.alpha = 1.0
            }
        } else {
            play()
            UIView.animate(withDuration: 0.3) {
                self.controlsContainer.alpha = 1.0
            }
        }
    }

    @objc private func handleSliderTouchBegan() {
        player?.pause()
        cancelAutoHide()
        controlsContainer.alpha = 1.0
        showScrubPreview()
    }

    @objc private func handleSliderChanged() {
        guard let player = player else { return }
        let value = progressSlider.value
        currentTimeLabel.text = DateFormatterManager.shared.formatVideoDuration(Double(value))
        updateScrubPreview()

        if isSeeking {
            pendingSeekValue = value
            return
        }

        isSeeking = true
        let newTime = CMTime(seconds: Double(value), preferredTimescale: 600)
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let pending = self.pendingSeekValue {
                    self.pendingSeekValue = nil
                    self.isSeeking = false
                    self.progressSlider.value = pending
                    self.handleSliderChanged()
                } else {
                    self.isSeeking = false
                }
            }
        }
    }

    @objc private func handleSliderTouchEnded() {
        hideScrubPreview()
        if _isPlaying {
            player?.play()
            scheduleAutoHide()
        }
    }
}

// MARK: - Previews

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct VideoPlayerControllerPreview: UIViewRepresentable {

        func makeUIView(context: Context) -> UIView {
            let controller = VideoPlayerController()

            controller.playPauseButton.alpha = 1.0
            controller.controlsContainer.alpha = 1.0

            let container = UIView()
            container.backgroundColor = .darkGray
            container.layer.cornerRadius = 16
            container.clipsToBounds = true

            container.addSubview(controller.playPauseButton)
            container.addSubview(controller.controlsContainer)

            NSLayoutConstraint.activate([
                controller.playPauseButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                controller.playPauseButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                controller.playPauseButton.widthAnchor.constraint(equalToConstant: 80),
                controller.playPauseButton.heightAnchor.constraint(equalToConstant: 80),

                controller.controlsContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                controller.controlsContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                controller.controlsContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
                controller.controlsContainer.heightAnchor.constraint(equalToConstant: 50)
            ])

            return container
        }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Compact Style") {
        VideoPlayerControllerPreview()
            .frame(width: 320, height: 400)
            .padding()
    }
#endif
