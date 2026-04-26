import Foundation
import SwiftUI

// MARK: - String Localization Helper

extension String {
    /// Shorthand for localized string lookup
    static func localized(_ key: String) -> String {
        String(localized: .init(key))
    }
}

// MARK: - Text Localization Helper

extension Text {
    /// Create Text from localized string key
    init(localizedKey key: String) {
        self.init(String(localized: .init(key)))
    }
}
