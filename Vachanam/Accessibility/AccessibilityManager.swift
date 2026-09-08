//
//  AccessibilityManager.swift
//  Vachanam
//
//  Accessibility controls: reading ruler, highlight styles, and auto-scroll policies.
//

import SwiftUI
import Combine

public enum HighlightMode: String, CaseIterable, Identifiable, Codable {
    case both = "Word & Sentence"
    case wordOnly = "Word Only"
    case sentenceOnly = "Sentence Only"
    case none = "None"
    
    public var id: String { rawValue }
}

public enum HighlightColorChoice: String, CaseIterable, Identifiable, Codable {
    case amber = "Warm Amber"
    case teal = "Cool Teal"
    case yellow = "Classic Yellow"
    case blue = "Soft Blue"
    
    public var id: String { rawValue }
    
    public var wordColor: Color {
        switch self {
        case .amber: return Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.85)
        case .teal: return Color(red: 0.08, green: 0.72, blue: 0.65).opacity(0.85)
        case .yellow: return Color(red: 1.00, green: 0.88, blue: 0.20).opacity(0.85)
        case .blue: return Color(red: 0.25, green: 0.55, blue: 0.95).opacity(0.85)
        }
    }
    
    public var sentenceColor: Color {
        switch self {
        case .amber: return Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.20)
        case .teal: return Color(red: 0.08, green: 0.72, blue: 0.65).opacity(0.20)
        case .yellow: return Color(red: 1.00, green: 0.88, blue: 0.20).opacity(0.25)
        case .blue: return Color(red: 0.25, green: 0.55, blue: 0.95).opacity(0.20)
        }
    }
}

public class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()
    
    @Published public var highlightMode: HighlightMode = .both {
        didSet {
            UserDefaults.standard.set(highlightMode.rawValue, forKey: "highlightMode")
        }
    }
    
    @Published public var colorChoice: HighlightColorChoice = .amber {
        didSet {
            UserDefaults.standard.set(colorChoice.rawValue, forKey: "highlightColorChoice")
        }
    }
    
    @Published public var isReadingRulerEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isReadingRulerEnabled, forKey: "isReadingRulerEnabled")
        }
    }
    
    @Published public var readingRulerHeight: CGFloat = 64.0 {
        didSet {
            UserDefaults.standard.set(Double(readingRulerHeight), forKey: "readingRulerHeight")
        }
    }
    
    @Published public var readingRulerOpacity: Double = 0.25 {
        didSet {
            UserDefaults.standard.set(readingRulerOpacity, forKey: "readingRulerOpacity")
        }
    }
    
    @Published public var isAutoScrollEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isAutoScrollEnabled, forKey: "isAutoScrollEnabled")
        }
    }
    
    @Published public var readingSpeedWPM: Int = 180 {
        didSet {
            UserDefaults.standard.set(readingSpeedWPM, forKey: "readingSpeedWPM")
        }
    }
    
    public init() {
        if let modeStr = UserDefaults.standard.string(forKey: "highlightMode"),
           let mode = HighlightMode(rawValue: modeStr) {
            self.highlightMode = mode
        }
        if let colorStr = UserDefaults.standard.string(forKey: "highlightColorChoice"),
           let col = HighlightColorChoice(rawValue: colorStr) {
            self.colorChoice = col
        }
        self.isReadingRulerEnabled = UserDefaults.standard.bool(forKey: "isReadingRulerEnabled")
        
        let savedHeight = UserDefaults.standard.double(forKey: "readingRulerHeight")
        if savedHeight > 0 { self.readingRulerHeight = CGFloat(savedHeight) }
        
        let savedOpacity = UserDefaults.standard.double(forKey: "readingRulerOpacity")
        if savedOpacity > 0 { self.readingRulerOpacity = savedOpacity }
        
        if UserDefaults.standard.object(forKey: "isAutoScrollEnabled") != nil {
            self.isAutoScrollEnabled = UserDefaults.standard.bool(forKey: "isAutoScrollEnabled")
        }
        let savedWpm = UserDefaults.standard.integer(forKey: "readingSpeedWPM")
        if savedWpm > 0 { self.readingSpeedWPM = savedWpm }
    }
}
