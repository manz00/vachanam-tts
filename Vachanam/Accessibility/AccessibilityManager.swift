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

public enum AutoScrollFollowMode: String, CaseIterable, Identifiable, Codable {
    case promptWhenScrolled = "Prompt When Scrolled"
    case alwaysFollow = "Always Follow"
    case off = "Off"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .promptWhenScrolled:
            return "Follow speech naturally. Scrolling away lets you read freely without snap-back, displaying a prompt to jump back to speech."
        case .alwaysFollow:
            return "Always keep the viewport centered on the currently spoken sentence, snapping back automatically."
        case .off:
            return "Manual scrolling only; the viewport never scrolls automatically."
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
    
    @Published public var autoScrollFollowMode: AutoScrollFollowMode = .promptWhenScrolled {
        didSet {
            UserDefaults.standard.set(autoScrollFollowMode.rawValue, forKey: "autoScrollFollowMode")
            isAutoScrollEnabled = (autoScrollFollowMode != .off)
        }
    }
    
    @Published public var readingSpeedWPM: Int = 180 {
        didSet {
            UserDefaults.standard.set(readingSpeedWPM, forKey: "readingSpeedWPM")
        }
    }
    
    // MARK: - Reading Intelligence Preferences
    
    @Published public var skipHeadersAndFooters: Bool = true {
        didSet {
            UserDefaults.standard.set(skipHeadersAndFooters, forKey: "skipHeadersAndFooters")
        }
    }
    
    @Published public var skipPageNumbers: Bool = true {
        didSet {
            UserDefaults.standard.set(skipPageNumbers, forKey: "skipPageNumbers")
        }
    }
    
    @Published public var skipFootnotes: Bool = true {
        didSet {
            UserDefaults.standard.set(skipFootnotes, forKey: "skipFootnotes")
        }
    }
    
    @Published public var skipCaptions: Bool = false {
        didSet {
            UserDefaults.standard.set(skipCaptions, forKey: "skipCaptions")
        }
    }
    
    @Published public var skipSidenotes: Bool = true {
        didSet {
            UserDefaults.standard.set(skipSidenotes, forKey: "skipSidenotes")
        }
    }
    
    @Published public var skipSymbolTables: Bool = true {
        didSet {
            UserDefaults.standard.set(skipSymbolTables, forKey: "skipSymbolTables")
        }
    }
    
    @Published public var pdfDisplayLayout: PDFDisplayLayoutMode = .singlePage {
        didSet {
            UserDefaults.standard.set(pdfDisplayLayout.rawValue, forKey: "pdfDisplayLayout")
        }
    }
    
    @Published public var mathSpeechStyle: MathSpeechStyle = .conversational {
        didSet {
            UserDefaults.standard.set(mathSpeechStyle.rawValue, forKey: "mathSpeechStyle")
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
        
        if let followStr = UserDefaults.standard.string(forKey: "autoScrollFollowMode"),
           let mode = AutoScrollFollowMode(rawValue: followStr) {
            self.autoScrollFollowMode = mode
            self.isAutoScrollEnabled = (mode != .off)
        } else if UserDefaults.standard.object(forKey: "isAutoScrollEnabled") != nil {
            let enabled = UserDefaults.standard.bool(forKey: "isAutoScrollEnabled")
            self.isAutoScrollEnabled = enabled
            self.autoScrollFollowMode = enabled ? .promptWhenScrolled : .off
        }
        let savedWpm = UserDefaults.standard.integer(forKey: "readingSpeedWPM")
        if savedWpm > 0 { self.readingSpeedWPM = savedWpm }
        
        if UserDefaults.standard.object(forKey: "skipHeadersAndFooters") != nil {
            self.skipHeadersAndFooters = UserDefaults.standard.bool(forKey: "skipHeadersAndFooters")
        }
        if UserDefaults.standard.object(forKey: "skipPageNumbers") != nil {
            self.skipPageNumbers = UserDefaults.standard.bool(forKey: "skipPageNumbers")
        }
        if UserDefaults.standard.object(forKey: "skipFootnotes") != nil {
            self.skipFootnotes = UserDefaults.standard.bool(forKey: "skipFootnotes")
        }
        if UserDefaults.standard.object(forKey: "skipCaptions") != nil {
            self.skipCaptions = UserDefaults.standard.bool(forKey: "skipCaptions")
        }
        if UserDefaults.standard.object(forKey: "skipSidenotes") != nil {
            self.skipSidenotes = UserDefaults.standard.bool(forKey: "skipSidenotes")
        }
        if UserDefaults.standard.object(forKey: "skipSymbolTables") != nil {
            self.skipSymbolTables = UserDefaults.standard.bool(forKey: "skipSymbolTables")
        }
        if let layoutStr = UserDefaults.standard.string(forKey: "pdfDisplayLayout"),
           let layout = PDFDisplayLayoutMode(rawValue: layoutStr) {
            self.pdfDisplayLayout = layout
        }
        if let mathStr = UserDefaults.standard.string(forKey: "mathSpeechStyle"),
           let style = MathSpeechStyle(rawValue: mathStr) {
            self.mathSpeechStyle = style
        }
    }
}
