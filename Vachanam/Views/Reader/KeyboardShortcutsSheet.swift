//
//  KeyboardShortcutsSheet.swift
//  Vachanam
//
//  Reference cheatsheet displaying all available keyboard shortcuts and gestures in Vachanam.
//

import SwiftUI

public struct KeyboardShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    private struct ShortcutItem: Identifiable {
        let id = UUID()
        let keys: [String]
        let description: String
    }
    
    private struct ShortcutSection: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let items: [ShortcutItem]
    }
    
    private let sections: [ShortcutSection] = [
        ShortcutSection(
            title: "Page Navigation",
            icon: "doc.text.magnifyingglass",
            items: [
                ShortcutItem(keys: ["→", "or", "↓"], description: "Next page"),
                ShortcutItem(keys: ["←", "or", "↑"], description: "Previous page"),
                ShortcutItem(keys: ["Space"], description: "Next page (or scroll down)"),
                ShortcutItem(keys: ["⇧", "Space"], description: "Previous page (or scroll up)"),
                ShortcutItem(keys: ["Page Down"], description: "Next page"),
                ShortcutItem(keys: ["Page Up"], description: "Previous page"),
                ShortcutItem(keys: ["⌘", "←", "or", "Home"], description: "First page"),
                ShortcutItem(keys: ["⌘", "→", "or", "End"], description: "Last page"),
                ShortcutItem(keys: ["⌘", "J"], description: "Jump to page number")
            ]
        ),
        ShortcutSection(
            title: "Continuous Scrolling & Gestures",
            icon: "arrow.up.arrow.down",
            items: [
                ShortcutItem(keys: ["Swipe Left"], description: "Next page (touch / trackpad)"),
                ShortcutItem(keys: ["Swipe Right"], description: "Previous page (touch / trackpad)"),
                ShortcutItem(keys: ["↓", "or", "↑"], description: "Smooth scroll in continuous view"),
                ShortcutItem(keys: ["Page Down", "or", "Space"], description: "Scroll down one screen"),
                ShortcutItem(keys: ["Page Up", "or", "⇧ Space"], description: "Scroll up one screen")
            ]
        ),
        ShortcutSection(
            title: "Zoom & Display Modes",
            icon: "magnifyingglass",
            items: [
                ShortcutItem(keys: ["⌘", "+"], description: "Zoom in"),
                ShortcutItem(keys: ["⌘", "-"], description: "Zoom out"),
                ShortcutItem(keys: ["⌘", "0"], description: "Fit page to screen"),
                ShortcutItem(keys: ["⌘", "1"], description: "Single Page mode"),
                ShortcutItem(keys: ["⌘", "2"], description: "Continuous Scroll mode"),
                ShortcutItem(keys: ["⌘", "3"], description: "Two-Page Spread"),
                ShortcutItem(keys: ["⌘", "4"], description: "Continuous Spread")
            ]
        ),
        ShortcutSection(
            title: "Speech & Audio Playback",
            icon: "speaker.wave.3.fill",
            items: [
                ShortcutItem(keys: ["⌥", "Space"], description: "Play / Pause TTS"),
                ShortcutItem(keys: ["⌥", "→", "or", "⌘", "]"], description: "Next spoken sentence"),
                ShortcutItem(keys: ["⌥", "←", "or", "⌘", "["], description: "Previous spoken sentence")
            ]
        ),
        ShortcutSection(
            title: "Reader Tools & Overlays",
            icon: "wrench.and.screwdriver",
            items: [
                ShortcutItem(keys: ["⌘", "B"], description: "Toggle bookmark on current page"),
                ShortcutItem(keys: ["⌘", "T"], description: "Table of contents"),
                ShortcutItem(keys: ["⌘", "G"], description: "Thumbnail grid overview"),
                ShortcutItem(keys: ["⌘", "D"], description: "Toggle Dyslexia reading ruler"),
                ShortcutItem(keys: ["⌘", "E"], description: "Export notes and bookmarks"),
                ShortcutItem(keys: ["⌘", ","], description: "Reader highlight settings"),
                ShortcutItem(keys: ["?"], description: "Show this shortcuts cheatsheet"),
                ShortcutItem(keys: ["Esc"], description: "Return to Library")
            ]
        )
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color.amberAccent)
                                Text(section.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(section.items) { item in
                                    HStack {
                                        Text(item.description)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.85))
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 4) {
                                            ForEach(item.keys, id: \.self) { key in
                                                if key == "or" {
                                                    Text("or")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.white.opacity(0.4))
                                                        .padding(.horizontal, 2)
                                                } else {
                                                    Text(key)
                                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(Color.white.opacity(0.12))
                                                        .cornerRadius(5)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 5)
                                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                        )
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    
                                    if item.id != section.items.last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.08))
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color(red: 0.10, green: 0.14, blue: 0.20))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.05, green: 0.08, blue: 0.13))
            .navigationTitle("Keyboard Shortcuts & Gestures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.amberAccent)
                }
            }
        }
    }
}
