import SwiftUI

extension Color {
    init(hex: String) {
        let rgb = RGB(hex: hex) ?? RGB(r: 255, g: 225, b: 0)
        self.init(rgb)
    }

    init(_ rgb: RGB) {
        self.init(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255, opacity: 1)
    }
}

/// Shared face palette. OLED-first: true black, few bright pixels.
enum Palette {
    static let black = Color.black
    static let ink = Color(hex: "#F4F1E6")          // primary text, warm white
    static let dim = Color(hex: "#8C8778")          // secondary text
    static let faint = Color(hex: "#3A3830")        // rules, inactive tracks
    static let electric = Color(hex: "#FFE100")
    static let red = Color(hex: "#E8433A")
    static let lowRed = Color(hex: "#FF5A4A")
    static let evening = Color(hex: "#C79A4A")      // sleeping face clock
    static let eveningDim = Color(hex: "#6E5530")
}
