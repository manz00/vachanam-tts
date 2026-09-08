//
//  FontManager.swift
//  Vachanam
//
//  Typography manager with OpenDyslexic, variable scaling, line height, and kerning.
//

import SwiftUI
import CoreText
import Combine

public enum ReaderFontFamily: String, CaseIterable, Identifiable, Codable {
    case system = "System (San Francisco)"
    case rounded = "System Rounded"
    case serif = "Serif (New York)"
    case openDyslexic = "OpenDyslexic"
    case mono = "Monospaced"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .system: return "Modern Sans"
        case .rounded: return "Friendly Rounded"
        case .serif: return "Classic Serif"
        case .openDyslexic: return "OpenDyslexic (Dyslexia Friendly)"
        case .mono: return "Monospaced"
        }
    }
}

public class FontManager: ObservableObject {
    public static let shared = FontManager()
    
    @Published public var selectedFont: ReaderFontFamily = .system {
        didSet {
            UserDefaults.standard.set(selectedFont.rawValue, forKey: "selectedReaderFont")
        }
    }
    
    @Published public var fontSize: CGFloat = 19.0 {
        didSet {
            UserDefaults.standard.set(Double(fontSize), forKey: "readerFontSize")
        }
    }
    
    @Published public var lineSpacingMultiplier: CGFloat = 1.6 {
        didSet {
            UserDefaults.standard.set(Double(lineSpacingMultiplier), forKey: "readerLineSpacing")
        }
    }
    
    @Published public var characterSpacing: CGFloat = 0.5 {
        didSet {
            UserDefaults.standard.set(Double(characterSpacing), forKey: "readerCharacterSpacing")
        }
    }
    
    @Published public var isBoldTextEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isBoldTextEnabled, forKey: "readerBoldText")
        }
    }
    
    public init() {
        if let savedFont = UserDefaults.standard.string(forKey: "selectedReaderFont"),
           let font = ReaderFontFamily(rawValue: savedFont) {
            self.selectedFont = font
        }
        let savedSize = UserDefaults.standard.double(forKey: "readerFontSize")
        if savedSize > 0 { self.fontSize = CGFloat(savedSize) }
        
        let savedSpacing = UserDefaults.standard.double(forKey: "readerLineSpacing")
        if savedSpacing > 0 { self.lineSpacingMultiplier = CGFloat(savedSpacing) }
        
        let savedChar = UserDefaults.standard.double(forKey: "readerCharacterSpacing")
        if savedChar > 0 { self.characterSpacing = CGFloat(savedChar) }
        
        self.isBoldTextEnabled = UserDefaults.standard.bool(forKey: "readerBoldText")
        
        registerCustomFontsIfNeeded()
    }
    
    public func resolveFont(size: CGFloat? = nil, weight: Font.Weight? = nil) -> Font {
        let targetSize = size ?? fontSize
        let targetWeight = weight ?? (isBoldTextEnabled ? .bold : .regular)
        
        switch selectedFont {
        case .system:
            return Font.system(size: targetSize, weight: targetWeight, design: .default)
        case .rounded:
            return Font.system(size: targetSize, weight: targetWeight, design: .rounded)
        case .serif:
            return Font.system(size: targetSize, weight: targetWeight, design: .serif)
        case .mono:
            return Font.system(size: targetSize, weight: targetWeight, design: .monospaced)
        case .openDyslexic:
            if UIFont.familyNames.contains(where: { $0.localizedCaseInsensitiveContains("opendyslexic") }) {
                return Font.custom("OpenDyslexic-Regular", size: targetSize)
            }
            // Dyslexia-accommodating fallback: rounded with heavy baseline weight
            return Font.system(size: targetSize, weight: .medium, design: .rounded)
        }
    }
    
    private func registerCustomFontsIfNeeded() {
        // Attempt to register any bundled OpenDyslexic TTF font files
        let fontNames = ["OpenDyslexic-Regular", "OpenDyslexic-Bold"]
        for fontName in fontNames {
            if let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") {
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
            }
        }
    }
}
