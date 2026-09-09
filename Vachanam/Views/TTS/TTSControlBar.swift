//
//  TTSControlBar.swift
//  Vachanam
//
//  Bottom playback bar with Play/Pause, speed slider, voice switcher, and sleep timer.
//

import SwiftUI

public struct TTSControlBar: View {
    public let documentTitle: String
    @ObservedObject var ttsController = TTSController.shared
    @ObservedObject var sleepTimer = SleepTimer.shared
    @ObservedObject var soundscapePlayer = AmbientSoundscapePlayer.shared
    @ObservedObject var coordinator = PlaybackCoordinator.shared
    
    @State private var isVoicePickerPresented: Bool = false
    @State private var isSleepTimerPresented: Bool = false
    @State private var isFixPronunciationPresented: Bool = false
    @State private var isSoundscapePickerPresented: Bool = false
    
    public init(documentTitle: String) {
        self.documentTitle = documentTitle
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Previous Sentence
            Button {
                ttsController.previousSentence()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.85))
            }
            
            // Play / Pause
            Button {
                if ttsController.isPlaying {
                    ttsController.pause()
                } else {
                    ttsController.play()
                }
            } label: {
                Image(systemName: ttsController.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 42))
                    .foregroundColor(Color.amberAccent)
            }
            
            // Next Sentence
            Button {
                ttsController.nextSentence()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.85))
            }
            
            // Playback Scope Menu (Document vs Current Page)
            Menu {
                Button {
                    PlaybackCoordinator.shared.scope = .document
                } label: {
                    Label("Read Full Document", systemImage: "doc.text")
                }
                
                Button {
                    PlaybackCoordinator.shared.scope = .page(PlaybackCoordinator.shared.visiblePageIndex)
                } label: {
                    Label("Read Page \(PlaybackCoordinator.shared.visiblePageIndex + 1) Only", systemImage: "doc.plaintext")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: PlaybackCoordinator.shared.scope.isPageOnly ? "doc.plaintext" : "doc.text")
                        .font(.system(size: 12))
                    Text(PlaybackCoordinator.shared.scope.isPageOnly ? "Page" : "Doc")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(6)
            }
            
            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.25))
            
            // Speed Menu
            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                    Button("\(String(format: "%.2fx", speed))") {
                        ttsController.speechSpeed = Float(speed)
                    }
                }
            } label: {
                Text(String(format: "%.2fx", ttsController.speechSpeed))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
            }
            
            // Voice & Model Status Pill
            Button {
                isVoicePickerPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundColor(Color.tealAccent)
                    
                    Text(ttsController.activeAdapterMetadata.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if ttsController.isModelLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .tint(Color.amberAccent)
                    } else {
                        Circle()
                            .fill(ttsController.isModelLoaded ? Color.green : Color.white.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                    
                    if coordinator.playbackMode == .preGenerated {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color.amberAccent)
                            Text("Pre-gen")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color.amberAccent)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.amberAccent.opacity(0.20))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.10))
                .cornerRadius(14)
            }
            
            // Fix Pronunciation
            Button {
                isFixPronunciationPresented = true
            } label: {
                Image(systemName: "character.bubble")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.80))
            }
            .accessibilityLabel("Fix Pronunciation")
            
            // Ambient Focus Soundscapes
            Button {
                isSoundscapePickerPresented = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "headphones")
                        .font(.system(size: 15))
                        .foregroundColor(soundscapePlayer.currentPreset != nil ? Color.amberAccent : .white.opacity(0.80))
                    
                    if soundscapePlayer.currentPreset != nil {
                        Circle()
                            .fill(soundscapePlayer.isPlaying ? Color.tealAccent : Color.amberAccent)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .accessibilityLabel("Ambient Soundscapes")
            
            // Sleep Timer
            Button {
                isSleepTimerPresented = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 15))
                    if sleepTimer.activeOption != .off {
                        Text(sleepTimer.formattedRemainingTime)
                            .font(.caption.bold())
                    }
                }
                .foregroundColor(sleepTimer.activeOption != .off ? Color.amberAccent : .white.opacity(0.75))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(red: 0.10, green: 0.14, blue: 0.20).opacity(0.95))
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
        )
        .sheet(isPresented: $isSoundscapePickerPresented) {
            SoundscapePickerSheet()
        }
        .sheet(isPresented: $isVoicePickerPresented) {
            VoicePickerView()
        }
        .sheet(isPresented: $isSleepTimerPresented) {
            SleepTimerView()
        }
        .sheet(isPresented: $isFixPronunciationPresented) {
            let activeWordText: String = {
                if let wID = PlaybackCoordinator.shared.currentWordID,
                   let word = PlaybackCoordinator.shared.activeSemanticDocument?.word(id: wID) {
                    return word.text
                }
                return ""
            }()
            FixPronunciationSheet(
                initialWord: activeWordText,
                documentID: PlaybackCoordinator.shared.activeSemanticDocument?.documentID
            )
        }
    }
}
