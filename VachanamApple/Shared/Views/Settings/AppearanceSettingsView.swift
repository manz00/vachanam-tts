//
//  AppearanceSettingsView.swift
//  Vachanam
//
//  Appearance settings: dark theme, color schemes, and reader background presets.
//

import SwiftUI

public struct AppearanceSettingsView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Theme Presets")) {
                ForEach(ReaderBackgroundTheme.allCases) { theme in
                    Button {
                        themeManager.currentReaderTheme = theme
                    } label: {
                        HStack {
                            Circle()
                                .fill(theme.backgroundColor)
                                .frame(width: 24, height: 24)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            
                            VStack(alignment: .leading) {
                                Text(theme.rawValue)
                                    .foregroundColor(.white)
                                Text(theme.isDark ? "Dark reading mode" : "Light reading mode")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                            
                            Spacer()
                            
                            if themeManager.currentReaderTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.amberAccent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
