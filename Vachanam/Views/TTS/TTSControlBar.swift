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
    
    @State private var isVoicePickerPresented: Bool = false
    @State private var isSleepTimerPresented: Bool = false
    
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
            
            // Voice Picker
            Button {
                isVoicePickerPresented = true
            } label: {
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundColor(Color.tealAccent)
            }
            
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
        .sheet(isPresented: $isVoicePickerPresented) {
            VoicePickerView()
        }
        .sheet(isPresented: $isSleepTimerPresented) {
            SleepTimerView()
        }
    }
}
