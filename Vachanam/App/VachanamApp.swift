//
//  VachanamApp.swift
//  Vachanam
//
//  Application entry point initializing background audio and lock screen commands.
//

import SwiftUI

@main
public struct VachanamApp: App {
    @StateObject private var appState = AppState.shared
    
    public init() {
        setenv("MLX_METAL_GPU_ARCH", "appleg14g", 0)
        PDFLoggingSanitizer.shared.install()
        AudioSession.shared.configureSession()
        AudioSession.shared.setupRemoteCommands(
            onPlay: {
                TTSController.shared.play()
            },
            onPause: {
                TTSController.shared.pause()
            },
            onSkipNext: {
                TTSController.shared.nextSentence()
            },
            onSkipPrevious: {
                TTSController.shared.previousSentence()
            }
        )
        
        var wasPlayingBeforeInterruption = false
        AudioSession.shared.setupInterruptionObservers(
            onInterruptionBegan: {
                if TTSController.shared.isPlaying {
                    wasPlayingBeforeInterruption = true
                    TTSController.shared.pause()
                } else {
                    wasPlayingBeforeInterruption = false
                }
            },
            onInterruptionEnded: { shouldResume in
                if shouldResume && wasPlayingBeforeInterruption {
                    wasPlayingBeforeInterruption = false
                    TTSController.shared.play()
                }
            },
            onRouteChangeShouldPause: {
                if TTSController.shared.isPlaying {
                    TTSController.shared.pause()
                }
            }
        )
    }
    
    public var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if let doc = ReaderDocument(url: url) {
                        appState.openDocument(doc)
                    }
                }
        }
        .commands {
            CommandMenu("Navigate") {
                Button("Next Page") {
                    NotificationCenter.default.post(name: .readerGoToNextPage, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                
                Button("Previous Page") {
                    NotificationCenter.default.post(name: .readerGoToPreviousPage, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Divider()
                
                Button("First Page") {
                    NotificationCenter.default.post(name: .readerGoToFirstPage, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                
                Button("Last Page") {
                    NotificationCenter.default.post(name: .readerGoToLastPage, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                
                Divider()
                
                Button("Scroll Down") {
                    NotificationCenter.default.post(name: .readerScrollDown, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: [])
                
                Button("Scroll Up") {
                    NotificationCenter.default.post(name: .readerScrollUp, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: [])
            }
            
            CommandGroup(after: .toolbar) {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .readerZoomIn, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .readerZoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Fit Page to Screen") {
                    NotificationCenter.default.post(name: .readerResetZoom, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Divider()
                
                Button("Single Page") {
                    AccessibilityManager.shared.pdfDisplayLayout = .singlePage
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Continuous Scroll") {
                    AccessibilityManager.shared.pdfDisplayLayout = .singlePageContinuous
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("Two-Page Spread") {
                    AccessibilityManager.shared.pdfDisplayLayout = .twoUp
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Button("Continuous Spread") {
                    AccessibilityManager.shared.pdfDisplayLayout = .twoUpContinuous
                }
                .keyboardShortcut("4", modifiers: .command)
                
                Divider()
                
                Button("Developer Inspector...") {
                    NotificationCenter.default.post(name: .openDeveloperInspector, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
            }
            
            CommandMenu("Speech") {
                Button(TTSController.shared.isPlaying ? "Pause Speech" : "Play Speech") {
                    if TTSController.shared.isPlaying {
                        TTSController.shared.pause()
                    } else {
                        TTSController.shared.play()
                    }
                }
                .keyboardShortcut(.space, modifiers: .option)
                
                Button("Next Sentence") {
                    TTSController.shared.nextSentence()
                }
                .keyboardShortcut(.rightArrow, modifiers: .option)
                
                Button("Previous Sentence") {
                    TTSController.shared.previousSentence()
                }
                .keyboardShortcut(.leftArrow, modifiers: .option)
            }
        }
    }
}
