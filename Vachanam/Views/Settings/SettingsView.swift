//
//  SettingsView.swift
//  Vachanam
//
//  Central settings view organizing Accessibility, Reading, Appearance, and Models.
//

import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AccessibilitySettingsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Accessibility")
                                    .font(.headline)
                                Text("OpenDyslexic, font sizes, contrast, reading ruler")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "figure.roll")
                                .foregroundColor(Color.amberAccent)
                        }
                    }
                    
                    NavigationLink {
                        ReadingSettingsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Reading & Highlights")
                                    .font(.headline)
                                Text("Word/sentence highlights, auto-scroll follow")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "highlighter")
                                .foregroundColor(Color.tealAccent)
                        }
                    }
                    
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Appearance & Colors")
                                    .font(.headline)
                                Text("Sepia, cream, dark, OLED, custom palettes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "paintbrush")
                                .foregroundColor(Color.amberAccent)
                        }
                    }
                    
                    NavigationLink {
                        ModelManagerView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("TTS Neural Models")
                                    .font(.headline)
                                Text("Kokoro, Qwen3-TTS, Chatterbox, CosyVoice 3")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "brain")
                                .foregroundColor(Color.tealAccent)
                        }
                    }
                }
                
                Section(header: Text("About Vachanam")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Production)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Target Platforms")
                        Spacer()
                        Text("iPad & Mac (Catalyst)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("TTS Engine")
                        Spacer()
                        Text("Pluggable On-Device Neural TTS")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
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
