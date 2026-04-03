import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Font {
    static func consolasBold(_ size: CGFloat) -> Font {
        #if canImport(UIKit)
        if let uiFont = UIFont(name: "Consolas-Bold", size: size) {
            return Font(uiFont)
        }
        #endif
        return .system(size: size, weight: .bold, design: .monospaced)
    }
}
