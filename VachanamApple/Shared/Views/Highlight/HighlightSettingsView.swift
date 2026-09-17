//
//  HighlightSettingsView.swift
//  Vachanam
//
//  Settings sheet for configuring highlight styles, colors, and reading ruler dimensions.
//

import SwiftUI

public struct HighlightSettingsView: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Highlighting Mode")) {
                    Picker("Style", selection: $accessibilityManager.highlightMode) {
                        ForEach(HighlightMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("Theme Color", selection: $accessibilityManager.colorChoice) {
                        ForEach(HighlightColorChoice.allCases) { choice in
                            HStack {
                                Circle().fill(choice.wordColor).frame(width: 14, height: 14)
                                Text(choice.rawValue)
                            }
                            .tag(choice)
                        }
                    }
                }
                
                Section(header: Text("Reading Ruler (Dyslexia Guide)")) {
                    Toggle("Enable Reading Ruler", isOn: $accessibilityManager.isReadingRulerEnabled)
                    
                    if accessibilityManager.isReadingRulerEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Ruler Height")
                                Spacer()
                                Text("\(Int(accessibilityManager.readingRulerHeight)) pt")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $accessibilityManager.readingRulerHeight, in: 36...140, step: 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Tint Opacity")
                                Spacer()
                                Text("\(Int(accessibilityManager.readingRulerOpacity * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $accessibilityManager.readingRulerOpacity, in: 0.1...0.6, step: 0.05)
                        }
                    }
                }
                
                Section(
                    header: Text("Auto-Scroll"),
                    footer: Text(accessibilityManager.autoScrollFollowMode.description)
                ) {
                    Toggle("Follow Voice Smoothly", isOn: $accessibilityManager.isAutoScrollEnabled)
                    if accessibilityManager.isAutoScrollEnabled {
                        Picker("Behavior", selection: $accessibilityManager.autoScrollFollowMode) {
                            ForEach(AutoScrollFollowMode.allCases.filter { $0 != .off }) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reading Assistance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
