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
            
            Section(header: Text("Auto-Scroll Behavior")) {
                Toggle("Auto-scroll with Spoken Voice", isOn: $accessibilityManager.isAutoScrollEnabled)
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
        }
        .navigationTitle("Reading Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
