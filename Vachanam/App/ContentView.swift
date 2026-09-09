//
//  ContentView.swift
//  Vachanam
//
//  Root navigation coordinator with keyboard shortcuts and adaptive layout.
//

import SwiftUI

public struct ContentView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var ttsController = TTSController.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if let document = appState.currentDocument {
                ReaderContainerView(document: document)
                    .transition(.opacity)
            } else {
                #if targetEnvironment(macCatalyst)
                TabView(selection: $appState.selectedTab) {
                    DocumentLibraryView { doc in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appState.openDocument(doc)
                        }
                    }
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .tag("library")
                    
                    NavigationStack {
                        AudiobookGeneratorView()
                    }
                    .tabItem {
                        Label("Audiobook Studio", systemImage: "sparkles.tv")
                    }
                    .tag("generator")
                }
                .accentColor(Color.amberAccent)
                #else
                DocumentLibraryView { doc in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        appState.openDocument(doc)
                    }
                }
                .transition(.opacity)
                #endif
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.currentDocument == nil)
        .preferredColorScheme(.dark)
        // Mac & iPad Keyboard Shortcuts
        .onKeyPress(.space) {
            if ttsController.isPlaying {
                ttsController.pause()
            } else {
                ttsController.play()
            }
            return .handled
        }
    }
}
