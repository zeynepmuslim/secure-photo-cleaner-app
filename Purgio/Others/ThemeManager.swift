//
//  ThemeManager.swift
//  Purgio
//
//  Created by ZeynepMüslim on 19.01.2026.
//

import UIKit

final class ThemeManager {
    static let shared = ThemeManager()
    
    private init() {}
    
    struct Colors {
        
        // MARK: - Status
        
        static var statusRed: UIColor {
//            return UIColor(named: "StatusRed") ?? .systemRed
            return .systemRed
        }
        
        static var statusGreen: UIColor {
//            return UIColor(named: "StatusGreen") ?? .systemGreen
            return .systemGreen
        }
        
        static var statusYellow: UIColor {
//            return UIColor(named: "StatusYellow") ?? .systemYellow
            return .systemYellow
        }
    }
    
    struct Fonts {
        
        /// Size: 32, Weight: Bold
        static var display: UIFont {
            return titleFont(size: 32, weight: .bold)
        }

        /// Size: 24, Weight: Bold
        static var boldTitle: UIFont {
            return titleFont(size: 24, weight: .bold)
        }
        
        /// Size: 16, Weight: Semibold
        static var semiboldBody: UIFont {
            return titleFont(size: 16, weight: .semibold)
        }
        
        /// Size: 13, Weight: Regular
        static var regularCaption: UIFont {
            return .systemFont(ofSize: 13, weight: .regular)
        }
        
        /// Size: 13, Weight: Semibold
        static var semiboldCaption: UIFont {
            return .systemFont(ofSize: 13, weight: .semibold)
        }
        
        /// Size: 17, Weight: Thin
        static var thinBody: UIFont {
            return .systemFont(ofSize: 17, weight: .thin)
        }

        // MARK: - Typography
        
        /// New York font for titles (serif design)
        static func titleFont(size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
            if let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif) {
                return UIFont(descriptor: descriptor, size: size)
            }
            // Fallback to system font if serif design is not available
            return .systemFont(ofSize: size, weight: weight)
        }
    }

    
    static func configureNavigationBarAppearance() {
        let largeTitleFont = Fonts.titleFont(size: 34, weight: .bold)
        let titleFont = Fonts.titleFont(size: 17, weight: .semibold)
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: UIColor.label
        ]
        appearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: UIColor.label
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}
