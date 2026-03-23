//
//  HapticFeedbackManager.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 8.01.2026.
//

import UIKit

final class HapticFeedbackManager {
    
    static let shared = HapticFeedbackManager()
    
    private lazy var impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()
    private lazy var selectionGenerator = UISelectionFeedbackGenerator()
    
    private init() {}
    
    func prepareAll() {
        impactGenerator.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    func impact(intensity: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        if intensity != .medium {
            let generator = UIImpactFeedbackGenerator(style: intensity)
            generator.prepare()
            generator.impactOccurred()
        } else {
            impactGenerator.impactOccurred()
        }
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }
    
    func success() {
        notificationGenerator.notificationOccurred(.success)
    }
    
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }
    
    func error() {
        notificationGenerator.notificationOccurred(.error)
    }
    
    func selection() {
        selectionGenerator.selectionChanged()
    }
}
