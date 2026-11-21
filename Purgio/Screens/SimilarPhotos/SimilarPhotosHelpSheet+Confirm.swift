//
//  SimilarPhotosHelpSheet+Confirm.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

/// The sample's Confirm: the hints give way to the three targets, each photo flies to its
/// own (kept ones onto the pile, the rest into the box and the bin, lids opening in time),
/// the targets count, the card is stamped and the sheet closes. Times are seconds from the tap.
extension SimilarPhotosHelpSheet {

    private enum Timing {
        static let targetsIn: TimeInterval = 0.2
        static let hintsFade: TimeInterval = 0.25
        /// Photos of one kind leave this far apart
        static let stagger: TimeInterval = 0.21

        static let keepTakeoff: TimeInterval = 0.42
        static let keepFlight: TimeInterval = 0.98

        static let boxLidOpen: TimeInterval = 0.49
        static let storeTakeoff: TimeInterval = 0.70
        static let storeFlight: TimeInterval = 0.90
        static let boxLidCloseAfterLanding: TimeInterval = 0.15
        static let boxCountAfterLanding: TimeInterval = 0.40

        static let binLidOpen: TimeInterval = 0.63
        static let deleteTakeoff: TimeInterval = 0.84
        static let deleteFlight: TimeInterval = 1.12
        /// The lid snaps shut as the last photo fades behind the body
        static let binLidCloseAfterLanding: TimeInterval = -0.07
        static let binCountAfterLanding: TimeInterval = 0.28

        static let earliestStamp: TimeInterval = 2.66
        static let stampAfterLastCount: TimeInterval = 0.21
        static let successAfterStamp: TimeInterval = 0.6
        static let dismissAfterStamp: TimeInterval = 0.7

        // Reduce Motion and VoiceOver: no flights
        static let reducedCounts: TimeInterval = 0.5
        static let reducedStamp: TimeInterval = 0.8
    }

    private enum Flight {
        static let keepLift: CGFloat = 22
        static let keepMidScale: CGFloat = 0.85
        static let keepLandedScale: CGFloat = 0.6
        static let keepMidDegrees: CGFloat = -2.5
        static let keepLandedDegrees: CGFloat = -5
        /// Each further kept photo lands a little off the one under it
        static let keepStackOffset: CGFloat = 3
        static let keepStackDegrees: CGFloat = 5

        static let dropLift: CGFloat = 30
        static let dropLiftStep: CGFloat = 6
        static let dropMidScale: CGFloat = 0.85
        static let dropOpeningScale: CGFloat = 0.24
        static let dropEndScale: CGFloat = 0.22
    }

    // MARK: - Timeline

    func runConfirmAnimation() {
        guard !isConfirming else { return }
        isConfirming = true
        view.layoutIfNeeded()

        let reduced = UIAccessibility.isReduceMotionEnabled || UIAccessibility.isVoiceOverRunning
        sampleCard.pressConfirmButton()
        schedule(after: Timing.targetsIn) { [weak self] in self?.showTargets(springs: !reduced) }

        let stampTime = reduced ? runReducedConfirm() : runFlights()
        schedule(after: stampTime) { [weak self] in self?.sampleCard.setStamped(animated: !reduced) }
        schedule(after: stampTime + Timing.successAfterStamp) { HapticFeedbackManager.shared.success() }
        schedule(after: stampTime + Timing.dismissAfterStamp) { [weak self] in
            self?.pendingWorkItems.removeAll()
            self?.dismiss(animated: true)
        }
    }

    /// Schedules every flight for the marks the sample has now. Returns when the stamp appears.
    private func runFlights() -> TimeInterval {
        let states = sampleCard.states
        let keeps = states.indices.filter { states[$0] == .keep }
        let stores = states.indices.filter { states[$0] == .store }
        let deletes = states.indices.filter { states[$0] == .delete }
        var lastCount: TimeInterval = 0

        // Kept photos go first and stay on the pile
        for (order, index) in keeps.enumerated() {
            let takeoff = Timing.keepTakeoff + Timing.stagger * Double(order)
            schedule(after: takeoff) { [weak self] in self?.flyKeep(index, order: order) }
            let landing = takeoff + Timing.keepFlight
            schedule(after: landing) { [weak self] in self?.land(on: .photos, count: order + 1) }
            lastCount = max(lastCount, landing)
        }

        // The box and the bin open only when something is coming
        if !stores.isEmpty {
            lastCount = max(lastCount, scheduleDrops(
                stores, into: .stored, lidOpen: Timing.boxLidOpen, takeoff: Timing.storeTakeoff,
                flight: Timing.storeFlight, lidClose: Timing.boxLidCloseAfterLanding,
                count: Timing.boxCountAfterLanding))
        }
        if !deletes.isEmpty {
            lastCount = max(lastCount, scheduleDrops(
                deletes, into: .bin, lidOpen: Timing.binLidOpen, takeoff: Timing.deleteTakeoff,
                flight: Timing.deleteFlight, lidClose: Timing.binLidCloseAfterLanding,
                count: Timing.binCountAfterLanding))
        }
        return max(Timing.earliestStamp, lastCount + Timing.stampAfterLastCount)
    }

    /// Photos dropping into the box or the bin: the lid opens, they fall in one after another,
    /// the lid shuts, the body squashes and counts. Returns when the count changes.
    private func scheduleDrops(
        _ indices: [Int], into target: SimilarHelpTargetsView.Target, lidOpen: TimeInterval,
        takeoff: TimeInterval, flight: TimeInterval, lidClose: TimeInterval, count: TimeInterval
    ) -> TimeInterval {
        schedule(after: lidOpen) { [weak self] in self?.targetsView.setLidOpen(true, for: target) }

        var lastLanding: TimeInterval = 0
        for (order, index) in indices.enumerated() {
            let start = takeoff + Timing.stagger * Double(order)
            schedule(after: start) { [weak self] in
                self?.flyDrop(index, into: target, order: order, duration: flight)
            }
            lastLanding = start + flight
            schedule(after: lastLanding) { HapticFeedbackManager.shared.impact(intensity: .light) }
        }

        schedule(after: lastLanding + lidClose) { [weak self] in self?.targetsView.setLidOpen(false, for: target) }
        let countTime = lastLanding + count
        schedule(after: countTime) { [weak self] in
            self?.targetsView.squash(target)
            self?.targetsView.setCount(indices.count, for: target)
        }
        return countTime
    }

    /// Reduce Motion and VoiceOver: the photos cross-dissolve out of the card and the counts
    /// change; the lids stay shut. Returns when the stamp appears.
    private func runReducedConfirm() -> TimeInterval {
        let counts = sampleCard.counts
        schedule(after: Timing.targetsIn) { [weak self] in
            guard let self else { return }
            UIView.animate(withDuration: Timing.hintsFade) {
                self.sampleCard.thumbnailViews.forEach { $0.alpha = 0 }
            }
        }
        schedule(after: Timing.reducedCounts) { [weak self] in
            guard let self else { return }
            if counts.kept > 0 { self.targetsView.setCount(counts.kept, for: .photos) }
            if counts.deleted > 0 { self.targetsView.setCount(counts.deleted, for: .bin) }
            if counts.stored > 0 { self.targetsView.setCount(counts.stored, for: .stored) }
        }
        return Timing.reducedStamp
    }

    // MARK: - Steps

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        let item = DispatchWorkItem(block: work)
        pendingWorkItems.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// The hints fade out and the targets take their place: scaled in from 0.8, or only faded.
    private func showTargets(springs: Bool) {
        targetsView.isHidden = false
        UIView.animate(withDuration: Timing.hintsFade) {
            self.hintsStack.alpha = 0
        } completion: { _ in
            self.hintsStack.accessibilityElementsHidden = true
        }

        guard springs else {
            UIView.animate(withDuration: Timing.hintsFade) { self.targetsView.alpha = 1 }
            return
        }
        targetsView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
            self.targetsView.alpha = 1
            self.targetsView.transform = .identity
        }
    }

    private func land(on target: SimilarHelpTargetsView.Target, count: Int) {
        targetsView.squash(target)
        targetsView.setCount(count, for: target)
        HapticFeedbackManager.shared.impact(intensity: .light)
    }

    /// A copy of a sample photo in a flight layer, exactly over the original, which hides.
    private func makeFlyingCopy(of index: Int, in layer: UIView) -> SimilarPhotoThumbnailView? {
        guard sampleCard.thumbnailViews.indices.contains(index) else { return nil }
        let original = sampleCard.thumbnailViews[index]
        let copy = SimilarPhotoThumbnailView(frame: original.convert(original.bounds, to: layer))
        copy.grayscaleCacheKey = original.grayscaleCacheKey
        copy.image = original.image
        copy.applyState(original.state)
        layer.addSubview(copy)
        original.alpha = 0
        return copy
    }

    /// A kept photo lifts, then lands tilted on top of the pile and stays there.
    private func flyKeep(_ index: Int, order: Int) {
        guard let photo = makeFlyingCopy(of: index, in: highFlightLayer) else { return }
        let start = photo.center
        let offset = Flight.keepStackOffset * CGFloat(order)
        var end = targetsView.landingPoint(for: .photos, in: highFlightLayer)
        end.x += offset
        end.y -= offset
        let landedDegrees = Flight.keepLandedDegrees + Flight.keepStackDegrees * CGFloat(order)

        UIView.animateKeyframes(withDuration: Timing.keepFlight, delay: 0, options: .calculationModeCubic) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.4) {
                photo.center = CGPoint(x: start.x + (end.x - start.x) * 0.1, y: start.y - Flight.keepLift)
                photo.transform = CGAffineTransform(rotationAngle: Flight.keepMidDegrees * .pi / 180)
                    .scaledBy(x: Flight.keepMidScale, y: Flight.keepMidScale)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.6) {
                photo.center = end
                photo.transform = CGAffineTransform(rotationAngle: landedDegrees * .pi / 180)
                    .scaledBy(x: Flight.keepLandedScale, y: Flight.keepLandedScale)
            }
        }
    }

    /// A stored or deleted photo arcs up to its target's opening, shrinking, then drops behind
    /// the body and fades.
    private func flyDrop(_ index: Int, into target: SimilarHelpTargetsView.Target, order: Int, duration: TimeInterval) {
        guard let photo = makeFlyingCopy(of: index, in: lowFlightLayer) else { return }
        let start = photo.center
        let opening = targetsView.landingPoint(for: target, in: lowFlightLayer)
        let lift = Flight.dropLift + Flight.dropLiftStep * CGFloat(order)

        UIView.animateKeyframes(withDuration: duration, delay: 0, options: .calculationModeCubic) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                photo.center = CGPoint(x: start.x + (opening.x - start.x) * 0.4, y: start.y - lift)
                photo.transform = CGAffineTransform(scaleX: Flight.dropMidScale, y: Flight.dropMidScale)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.45) {
                photo.center = opening
                photo.transform = CGAffineTransform(scaleX: Flight.dropOpeningScale, y: Flight.dropOpeningScale)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                photo.center = CGPoint(x: opening.x, y: opening.y + self.targetsView.dropDistance)
                photo.transform = CGAffineTransform(scaleX: Flight.dropEndScale, y: Flight.dropEndScale)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.88, relativeDuration: 0.12) {
                photo.alpha = 0
            }
        } completion: { _ in
            photo.removeFromSuperview()
        }
    }
}
