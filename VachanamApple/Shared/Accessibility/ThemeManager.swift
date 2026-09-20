//
//  ThemeManager.swift
//  Vachanam
//
//  Accessibility-first color palettes, reading themes, and contrast control.
//

import SwiftUI
import Combine

public enum ReaderBackgroundTheme: String, CaseIterable, Identifiable, Codable {
    case original = "Original"
    case quiet = "Quiet"
    case paper = "Paper"
    case charcoal = "Charcoal"
    case night = "Night"
    
    public var id: String { rawValue }
    
    // Backward compatibility aliases
    public static var cream: ReaderBackgroundTheme { .quiet }
    public static var sepia: ReaderBackgroundTheme { .paper }
    public static var darkSlate: ReaderBackgroundTheme { .charcoal }
    public static var oledBlack: ReaderBackgroundTheme { .night }
    public static var pureWhite: ReaderBackgroundTheme { .original }
    
    public var displayName: String {
        switch self {
        case .original: return "Original"
        case .quiet: return "Quiet"
        case .paper: return "Paper"
        case .charcoal: return "Charcoal"
        case .night: return "Night"
        }
    }
    
    public var backgroundColor: Color {
        switch self {
        case .original:
            return Color.white
        case .quiet:
            // Warm Cream #FBF0D9
            return Color(red: 0.984, green: 0.941, blue: 0.851)
        case .paper:
            // Light Sepia Paper #EFE6D5
            return Color(red: 0.937, green: 0.902, blue: 0.835)
        case .charcoal:
            // Dark Slate #2C2C2E
            return Color(red: 0.173, green: 0.173, blue: 0.180)
        case .night:
            // Pitch Black #000000
            return Color.black
        }
    }
    
    public var textColor: Color {
        switch self {
        case .original:
            // #1A1A1A
            return Color(red: 0.102, green: 0.102, blue: 0.102)
        case .quiet:
            // #3B2E2A
            return Color(red: 0.231, green: 0.180, blue: 0.165)
        case .paper:
            // #2C2621
            return Color(red: 0.173, green: 0.149, blue: 0.129)
        case .charcoal:
            // #E5E5EA
            return Color(red: 0.898, green: 0.898, blue: 0.918)
        case .night:
            // #D1D1D6
            return Color(red: 0.820, green: 0.820, blue: 0.839)
        }
    }
    
    public var secondaryTextColor: Color {
        switch self {
        case .quiet, .paper:
            return textColor.opacity(0.65)
        case .charcoal, .night:
            return textColor.opacity(0.60)
        case .original:
            return Color(red: 0.40, green: 0.40, blue: 0.40)
        }
    }
    
    public var isDark: Bool {
        switch self {
        case .charcoal, .night:
            return true
        default:
            return false
        }
    }
    
    public static func from(savedString: String) -> ReaderBackgroundTheme? {
        if let direct = ReaderBackgroundTheme(rawValue: savedString) {
            return direct
        }
        switch savedString.lowercased() {
        case "cream": return .quiet
        case "sepia": return .paper
        case "dark slate", "darkslate": return .charcoal
        case "oled black", "oledblack": return .night
        case "pure white", "purewhite": return .original
        default: return nil
        }
    }
}

public enum ReadingLayout: String, CaseIterable, Identifiable, Codable {
    case paginated = "Single Page"
    case twoPage = "Two Pages"
    case continuous = "Continuous Scroll"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .paginated: return "doc.text"
        case .twoPage: return "book.pages"
        case .continuous: return "scroll"
        }
    }
    
    public var isTwoPage: Bool {
        self == .twoPage
    }
    
    public var isPaginated: Bool {
        self == .paginated || self == .twoPage
    }
    
    public var pageStep: Int {
        self == .twoPage ? 2 : 1
    }
    
    public static func from(savedString: String) -> ReadingLayout? {
        if let direct = ReadingLayout(rawValue: savedString) {
            return direct
        }
        switch savedString.lowercased() {
        case "paginated", "single page", "singlepage": return .paginated
        case "two pages", "twopages", "two-page spread", "two up", "twoup": return .twoPage
        case "continuous scroll", "continuous", "scroll": return .continuous
        default: return nil
        }
    }
}

public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @Published public var currentReaderTheme: ReaderBackgroundTheme = .quiet {
        didSet {
            UserDefaults.standard.set(currentReaderTheme.rawValue, forKey: "currentReaderTheme")
        }
    }
    
    @Published public var readingLayout: ReadingLayout = .paginated {
        didSet {
            UserDefaults.standard.set(readingLayout.rawValue, forKey: "readingLayout")
        }
    }
    
    @Published public var isHighContrastEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isHighContrastEnabled, forKey: "isHighContrastEnabled")
        }
    }
    
    // Warm dark UI background colors
    public static let appBackground = Color(red: 0.043, green: 0.075, blue: 0.125) // Deep Navy #0B1320
    public static let surfaceColor = Color(red: 0.082, green: 0.114, blue: 0.165)  // Slate Charcoal #151D2A
    public static let surfaceElevated = Color(red: 0.122, green: 0.165, blue: 0.235)
    public static let amberAccent = Color(red: 0.961, green: 0.620, blue: 0.043)   // Warm Amber #F59E0B
    public static let tealAccent = Color(red: 0.078, green: 0.722, blue: 0.651)    // Vibrant Teal #14B8A6
    public static let highlightYellow = Color(red: 1.0, green: 0.88, blue: 0.25).opacity(0.35)
    public static let highlightBlue = Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.30)
    
    public init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "currentReaderTheme"),
           let theme = ReaderBackgroundTheme.from(savedString: savedTheme) {
            self.currentReaderTheme = theme
        }
        if let savedLayout = UserDefaults.standard.string(forKey: "readingLayout"),
           let layout = ReadingLayout.from(savedString: savedLayout) {
            self.readingLayout = layout
        }
        self.isHighContrastEnabled = UserDefaults.standard.bool(forKey: "isHighContrastEnabled")
    }
    
    public var effectiveTextColor: Color {
        if isHighContrastEnabled {
            return currentReaderTheme.isDark ? Color.white : Color.black
        }
        return currentReaderTheme.textColor
    }
    
    public func cycleTheme() {
        let all = ReaderBackgroundTheme.allCases
        if let idx = all.firstIndex(of: currentReaderTheme) {
            let next = all[(idx + 1) % all.count]
            currentReaderTheme = next
        } else {
            currentReaderTheme = .quiet
        }
    }
}

public extension Color {
    static let amberAccent = ThemeManager.amberAccent
    static let tealAccent = ThemeManager.tealAccent
    static let highlightYellow = ThemeManager.highlightYellow
    static let highlightBlue = ThemeManager.highlightBlue
}

