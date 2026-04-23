//
//  VideoPlayerController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.02.2026.
//

import AVFoundation
import Photos
import UIKit

final class VideoPlayerController {

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

        playPauseButton.insertSubview(playButtonBlurView, at: 0)
        
        controlsContainer.contentView.addSubview(progressSlider)
        controlsContainer.contentView.addSubview(currentTimeLabel)
        controlsContainer.contentView.addSubview(durationLabel)
        
        playPauseButton.imageView?.layer.zPosition = 1

        playPauseButton.addTarget(self, action: #selector(handlePlayPauseTap), for: .touchUpInside)
    }

    private func setupConstraints() {


        NSLayoutConstraint.activate([
            playButtonBlurView.topAnchor.constraint(equalTo: playPauseButton.topAnchor),
            playButtonBlurView.bottomAnchor.constraint(equalTo: playPauseButton.bottomAnchor),
            playButtonBlurView.leadingAnchor.constraint(equalTo: playPauseButton.leadingAnchor),
            playButtonBlurView.trailingAnchor.constraint(equalTo: playPauseButton.trailingAnchor),
            
            progressSlider.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 8),
            progressSlider.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),
            progressSlider.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),

            currentTimeLabel.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 12),
            currentTimeLabel.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),

            durationLabel.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -12),
            durationLabel.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor)
        ])
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
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = configuration.videoGravity
        if configuration.layerCornerRadius > 0 {
            layer.cornerRadius = configuration.layerCornerRadius
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
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        playPauseButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
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
    }

    @objc private func handleSliderChanged() {
        guard let player = player else { return }
        let value = progressSlider.value
        currentTimeLabel.text = DateFormatterManager.shared.formatVideoDuration(Double(value))

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
        if _isPlaying {
            player?.play()
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
