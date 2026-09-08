//
//  AccessibilitySettingsView.swift
//  Vachanam
//
//  Accessibility settings: OpenDyslexic, variable typography, high contrast, and reading ruler.
//

import SwiftUI

public struct AccessibilitySettingsView: View {
    @ObservedObject var fontManager = FontManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Typography & Font")) {
                Picker("Font Family", selection: $fontManager.selectedFont) {
                    ForEach(ReaderFontFamily.allCases) { family in
                        Text(family.displayName).tag(family)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(fontManager.fontSize)) pt")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $fontManager.fontSize, in: 14...38, step: 1)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Line Spacing")
                        Spacer()
                        Text(String(format: "%.1fx", fontManager.lineSpacingMultiplier))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $fontManager.lineSpacingMultiplier, in: 1.2...2.4, step: 0.1)
                }
                
                Toggle("Bold Text", isOn: $fontManager.isBoldTextEnabled)
            }
            
            Section(header: Text("Vision & Contrast")) {
                Toggle("High Contrast (WCAG AAA)", isOn: $themeManager.isHighContrastEnabled)
                
                Picker("Page Background", selection: $themeManager.currentReaderTheme) {
                    ForEach(ReaderBackgroundTheme.allCases) { theme in
                        HStack {
                            Circle().fill(theme.backgroundColor).frame(width: 14, height: 14)
                            Text(theme.rawValue)
                        }
                        .tag(theme)
                    }
                }
            }
            
            Section(header: Text("Dyslexia Reading Ruler")) {
                Toggle("Enable Reading Ruler", isOn: $accessibilityManager.isReadingRulerEnabled)
                
                if accessibilityManager.isReadingRulerEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Ruler Height")
                            Spacer()
                            Text("\(Int(accessibilityManager.readingRulerHeight)) pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $accessibilityManager.readingRulerHeight, in: 40...120, step: 5)
                    }
                }
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}
