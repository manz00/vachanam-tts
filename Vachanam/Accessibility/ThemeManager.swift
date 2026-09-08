//
//  ThemeManager.swift
//  Vachanam
//
//  Accessibility-first color palettes, reading themes, and contrast control.
//

import SwiftUI
import Combine

public enum ReaderBackgroundTheme: String, CaseIterable, Identifiable, Codable {
    case cream = "Cream"
    case sepia = "Sepia"
    case darkSlate = "Dark Slate"
    case oledBlack = "OLED Black"
    case pureWhite = "Pure White"
    
    public var id: String { rawValue }
    
    public var backgroundColor: Color {
        switch self {
        case .cream:
            return Color(red: 0.984, green: 0.941, blue: 0.851)
        case .sepia:
            return Color(red: 0.957, green: 0.925, blue: 0.847)
        case .darkSlate:
            return Color(red: 0.082, green: 0.114, blue: 0.165)
        case .oledBlack:
            return Color.black
        case .pureWhite:
            return Color.white
        }
    }
    
    public var textColor: Color {
        switch self {
        case .cream:
            return Color(red: 0.165, green: 0.141, blue: 0.122)
        case .sepia:
            return Color(red: 0.227, green: 0.180, blue: 0.114)
        case .darkSlate:
            return Color(red: 0.902, green: 0.929, blue: 0.953)
        case .oledBlack:
            return Color(red: 0.973, green: 0.980, blue: 0.988)
        case .pureWhite:
            return Color(red: 0.059, green: 0.090, blue: 0.165)
        }
    }
    
    public var secondaryTextColor: Color {
        switch self {
        case .cream, .sepia:
            return textColor.opacity(0.7)
        case .darkSlate, .oledBlack:
            return textColor.opacity(0.65)
        case .pureWhite:
            return Color(red: 0.392, green: 0.455, blue: 0.545)
        }
    }
    
    public var isDark: Bool {
        switch self {
        case .darkSlate, .oledBlack:
            return true
        default:
            return false
        }
    }
}

public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @Published public var currentReaderTheme: ReaderBackgroundTheme = .darkSlate {
        didSet {
            UserDefaults.standard.set(currentReaderTheme.rawValue, forKey: "currentReaderTheme")
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
           let theme = ReaderBackgroundTheme(rawValue: savedTheme) {
            self.currentReaderTheme = theme
        }
        self.isHighContrastEnabled = UserDefaults.standard.bool(forKey: "isHighContrastEnabled")
    }
    
    public var effectiveTextColor: Color {
        if isHighContrastEnabled {
            return currentReaderTheme.isDark ? Color.white : Color.black
        }
        return currentReaderTheme.textColor
    }
}

public extension Color {
    static let amberAccent = ThemeManager.amberAccent
    static let tealAccent = ThemeManager.tealAccent
    static let highlightYellow = ThemeManager.highlightYellow
    static let highlightBlue = ThemeManager.highlightBlue
}

