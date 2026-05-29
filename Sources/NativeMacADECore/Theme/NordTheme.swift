import Foundation

public struct NordColorToken: Equatable, Sendable {
    public let hex: String
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double

    public init(hex: String, opacity: Double = 1) {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)

        self.hex = "#\(normalized.uppercased())"
        self.red = Double((value >> 16) & 0xFF) / 255
        self.green = Double((value >> 8) & 0xFF) / 255
        self.blue = Double(value & 0xFF) / 255
        self.opacity = opacity
    }
}

public enum NordTheme {
    public static let polarNight0 = NordColorToken(hex: "#2E3440")
    public static let polarNight1 = NordColorToken(hex: "#3B4252")
    public static let polarNight2 = NordColorToken(hex: "#434C5E")
    public static let polarNight3 = NordColorToken(hex: "#4C566A")
    public static let snowStorm0 = NordColorToken(hex: "#D8DEE9")
    public static let snowStorm1 = NordColorToken(hex: "#E5E9F0")
    public static let snowStorm2 = NordColorToken(hex: "#ECEFF4")
    public static let frost0 = NordColorToken(hex: "#8FBCBB")
    public static let frost1 = NordColorToken(hex: "#88C0D0")
    public static let frost2 = NordColorToken(hex: "#81A1C1")
    public static let frost3 = NordColorToken(hex: "#5E81AC")
    public static let auroraRed = NordColorToken(hex: "#BF616A")
    public static let auroraOrange = NordColorToken(hex: "#D08770")
    public static let auroraYellow = NordColorToken(hex: "#EBCB8B")
    public static let auroraGreen = NordColorToken(hex: "#A3BE8C")
    public static let auroraPurple = NordColorToken(hex: "#B48EAD")

    public static let shellBackground = polarNight0
    public static let sidebarBackground = polarNight1
    public static let contentBackground = polarNight0
    public static let elevatedBackground = polarNight2
    public static let activeBackground = frost3
    public static let activeBorder = frost1
    public static let primaryText = snowStorm2
    public static let secondaryText = snowStorm0
    public static let mutedText = NordColorToken(hex: "#D8DEE9", opacity: 0.72)
    public static let destructive = auroraRed
}
