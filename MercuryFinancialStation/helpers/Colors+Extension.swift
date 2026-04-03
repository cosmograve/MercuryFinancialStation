import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        let value = UInt64(cleaned, radix: 16) ?? 0
        let a, r, g, b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = ((value >> 8) & 0xF) * 17
            g = ((value >> 4) & 0xF) * 17
            b = (value & 0xF) * 17
        case 6:
            a = 255
            r = (value >> 16) & 0xFF
            g = (value >> 8) & 0xFF
            b = value & 0xFF
        case 8:
            a = (value >> 24) & 0xFF
            r = (value >> 16) & 0xFF
            g = (value >> 8) & 0xFF
            b = value & 0xFF
        default:
            a = 255
            r = 255
            g = 0
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

extension Color {
    static let appBackground = Color(hex: "#0A1929")
    static let tabSelected = Color(hex: "#FFD60A")
    static let tabUnselected = Color(hex: "#99A1AF")
    static let dailyLimitAccent = Color(hex: "#00D3F3")
    static let surfacePrimary = Color(hex: "#132B46")
    static let surfaceSecondary = Color(hex: "#173554")
    static let cardFill = Color.white.opacity(0.05)
    static let cardStroke = Color.white.opacity(0.10)
    static let initOverlayBackground = Color(hex: "#0F2642")
    static let chipPlus = Color(hex: "#00D3F3")
    static let chipMinus = Color(hex: "#FB2C36")
}
