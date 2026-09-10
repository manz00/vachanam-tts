//
//  ReadingSettingsView.swift
//  Vachanam
//
//  Settings for reading highlights, audio follow auto-scrolling, and speech speed.
//

import SwiftUI

public struct ReadingSettingsView: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    @ObservedObject var ttsController = TTSController.shared
    @ObservedObject var developerModeManager = DeveloperModeManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Karaoke Highlighting")) {
                Picker("Highlight Style", selection: $accessibilityManager.highlightMode) {
                    ForEach(HighlightMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                Picker("Accent Color", selection: $accessibilityManager.colorChoice) {
                    ForEach(HighlightColorChoice.allCases) { choice in
                        HStack {
                            Circle().fill(choice.wordColor).frame(width: 14, height: 14)
                            Text(choice.rawValue)
                        }
                        .tag(choice)
                    }
                }
            }
            
            Section(header: Text("Reading Intelligence (Audio Skipping)")) {
                Toggle("Skip Running Headers & Footers", isOn: $accessibilityManager.skipHeadersAndFooters)
                Toggle("Skip Standalone Page Numbers", isOn: $accessibilityManager.skipPageNumbers)
                Toggle("Skip Footnotes", isOn: $accessibilityManager.skipFootnotes)
                Toggle("Skip Figure & Table Captions", isOn: $accessibilityManager.skipCaptions)
                Toggle("Skip Sidenotes & Margin Notes", isOn: $accessibilityManager.skipSidenotes)
                Toggle("Skip Notation & Symbol Tables", isOn: $accessibilityManager.skipSymbolTables)
            }
            
            Section(
                header: Text("Math & Scientific Speech"),
                footer: Text(accessibilityManager.mathSpeechStyle.description)
            ) {
                Picker("Speech Style", selection: $accessibilityManager.mathSpeechStyle) {
                    ForEach(MathSpeechStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            }
            
            Section(header: Text("PDF Layout & Scrolling")) {
                Picker("Layout Mode", selection: $accessibilityManager.pdfDisplayLayout) {
                    ForEach(PDFDisplayLayoutMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                    }
                }
            }
            
            Section(
                header: Text("Auto-Scroll Behavior"),
                footer: Text(accessibilityManager.autoScrollFollowMode.description)
            ) {
                Picker("Follow Spoken Voice", selection: $accessibilityManager.autoScrollFollowMode) {
                    ForEach(AutoScrollFollowMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }
            
            Section(header: Text("Speech Speed")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Reading Speed")
                        Spacer()
                        Text(String(format: "%.2fx", ttsController.speechSpeed))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(ttsController.speechSpeed) },
                        set: { ttsController.speechSpeed = Float($0) }
                    ), in: 0.5...2.0, step: 0.05)
                }
            }
            
            Section(
                header: Text("Developer & Diagnostics"),
                footer: Text("Developer mode enables page layout diagnostics, bounding box inspections, paragraph JSON downloads, and the interactive voice synthesis testing sandbox.")
            ) {
                Toggle("Developer Mode", isOn: $developerModeManager.isDeveloperModeEnabled)
                
                if developerModeManager.isDeveloperModeEnabled {
                    Button {
                        NotificationCenter.default.post(name: .openDeveloperInspector, object: nil)
                    } label: {
                        Label("Open Developer Inspector", systemImage: "wrench.and.screwdriver")
                            .foregroundColor(Color.cyan)
                    }
                }
            }
        }
        .navigationTitle("Reading Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
