//
//  BookmarkButton.swift
//  Vachanam
//
//  Interactive bookmark button with animation.
//

import SwiftUI

public struct BookmarkButton: View {
    public let isBookmarked: Bool
    public let action: () -> Void
    
    public init(isBookmarked: Bool, action: @escaping () -> Void) {
        self.isBookmarked = isBookmarked
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isBookmarked ? Color.amberAccent : .white.opacity(0.8))
                .scaleEffect(isBookmarked ? 1.1 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isBookmarked)
        }
        .help(isBookmarked ? "Remove Bookmark" : "Bookmark Page")
    }
}
