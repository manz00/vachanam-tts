//
//  SoundscapePickerSheet.swift
//  Vachanam
//
//  Ambient focus soundscape selection sheet with live volume control,
//  study mode toggle, and acoustic preview.
//

import SwiftUI

public struct SoundscapePickerSheet: View {
    @ObservedObject var soundscapePlayer = AmbientSoundscapePlayer.shared
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Active Soundscape Status
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(soundscapePlayer.currentPreset != nil ? Color.amberAccent.opacity(0.18) : Color.white.opacity(0.08))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: soundscapePlayer.currentPreset?.systemImage ?? "headphones")
                                .font(.system(size: 20))
                                .foregroundColor(soundscapePlayer.currentPreset != nil ? Color.amberAccent : .white.opacity(0.4))
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(soundscapePlayer.currentPreset?.title ?? "No Soundscape Active")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(soundscapePlayer.isPlaying ? (soundscapePlayer.isStudyModeEnabled ? "Study Mode Active" : "Playing with Speech") : "Select a soundscape to focus")
                                .font(.caption)
                                .foregroundColor(soundscapePlayer.isPlaying ? Color.tealAccent : .white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        if soundscapePlayer.currentPreset != nil {
                            Button {
                                if soundscapePlayer.isPlaying {
                                    soundscapePlayer.pauseAmbient()
                                } else {
                                    soundscapePlayer.startAmbient(fadeIn: true)
                                }
                            } label: {
                                Image(systemName: soundscapePlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color.amberAccent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Volume Controls
                if soundscapePlayer.currentPreset != nil {
                    Section(header: Text("Ambient Volume")) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "speaker.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Slider(value: Binding(
                                    get: { soundscapePlayer.volume },
                                    set: { soundscapePlayer.setVolume($0) }
                                ), in: 0...1)
                                .tint(Color.amberAccent)
                                
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("\(Int(soundscapePlayer.volume * 100))%")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    .frame(width: 42, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Soundscapes List
                Section(header: Text("Focus Soundscapes")) {
                    // Off Option
                    Button {
                        soundscapePlayer.selectPreset(nil)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.slash")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Off (Narration Only)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)
                                Text("Speech plays without background audio")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            if soundscapePlayer.currentPreset == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.amberAccent)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Presets
                    ForEach(SoundscapePreset.allCases) { preset in
                        Button {
                            soundscapePlayer.selectPreset(preset)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: preset.systemImage)
                                    .font(.system(size: 17))
                                    .foregroundColor(soundscapePlayer.currentPreset == preset ? Color.amberAccent : Color.tealAccent)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                    
                                    Text(preset.subtitle)
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                
                                Spacer()
                                
                                if soundscapePlayer.currentPreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.amberAccent)
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Study Mode Section
                Section(header: Text("Study Mode")) {
                    Toggle(isOn: Binding(
                        get: { soundscapePlayer.isStudyModeEnabled },
                        set: { soundscapePlayer.setStudyMode($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Independent Playback")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                            Text("Keep ambient playing when reading is paused or finished")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    .tint(Color.tealAccent)
                }
            }
            .navigationTitle("Ambient Soundscapes")
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
