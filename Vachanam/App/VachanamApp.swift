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
    }
}
