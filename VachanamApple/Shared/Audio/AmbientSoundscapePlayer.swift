//
//  AmbientSoundscapePlayer.swift
//  Vachanam
//
//  Ambient focus audio player:
//  - Brown Noise, Pink Noise, 40Hz Binaural Beats, Soft Rain, Library Ambience
//  - Seamless infinite looping
//  - Independent volume control with persistence
//  - Smooth fade-in and fade-out
//  - Optional Study Mode (independent playback when reading is paused)
//

import Foundation
import AVFoundation
import Combine

public enum SoundscapePreset: String, CaseIterable, Identifiable, Codable {
    case brownNoise = "brown_noise"
    case pinkNoise = "pink_noise"
    case binauralFocus = "binaural_focus_40hz"
    case softRain = "soft_rain"
    case libraryAmbience = "library_ambience"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .brownNoise: return "Brown Noise"
        case .pinkNoise: return "Pink Noise"
        case .binauralFocus: return "Binaural Focus"
        case .softRain: return "Soft Rain"
        case .libraryAmbience: return "Library & Café"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .brownNoise: return "Deep, soothing low-frequency rumble"
        case .pinkNoise: return "Balanced waterfall-like calming noise"
        case .binauralFocus: return "40 Hz gamma rhythm for deep focus"
        case .softRain: return "Gentle rainfall with droplet ambience"
        case .libraryAmbience: return "Warm, quiet acoustic atmosphere"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .brownNoise: return "waveform.path"
        case .pinkNoise: return "waveform"
        case .binauralFocus: return "brain.head.profile"
        case .softRain: return "cloud.rain.fill"
        case .libraryAmbience: return "books.vertical.fill"
        }
    }
    
    public var resourceName: String {
        rawValue
    }
}

public class AmbientSoundscapePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = AmbientSoundscapePlayer()
    
    @Published public var currentPreset: SoundscapePreset?
    @Published public var volume: Float = 0.3
    @Published public var isPlaying: Bool = false
    @Published public var isStudyModeEnabled: Bool = false
    
    private var avPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var isTTSActive: Bool = false
    
    private let presetKey = "vachanam.soundscape.preset"
    private let volumeKey = "vachanam.soundscape.volume"
    private let studyModeKey = "vachanam.soundscape.studyMode"
    
    public override init() {
        super.init()
        loadPersistedSettings()
    }
    
    private func loadPersistedSettings() {
        let defaults = UserDefaults.standard
        if let rawPreset = defaults.string(forKey: presetKey),
           let preset = SoundscapePreset(rawValue: rawPreset) {
            self.currentPreset = preset
        }
        
        if defaults.object(forKey: volumeKey) != nil {
            self.volume = defaults.float(forKey: volumeKey)
        } else {
            self.volume = 0.3
        }
        
        self.isStudyModeEnabled = defaults.bool(forKey: studyModeKey)
    }
    
    // MARK: - Preset Selection
    
    public func selectPreset(_ preset: SoundscapePreset?) {
        guard preset != currentPreset else { return }
        
        let wasPlaying = isPlaying
        stopAmbient(fadeOut: false)
        
        self.currentPreset = preset
        
        if let preset = preset {
            UserDefaults.standard.set(preset.rawValue, forKey: presetKey)
        } else {
            UserDefaults.standard.removeObject(forKey: presetKey)
        }
        
        if preset != nil && (wasPlaying || isStudyModeEnabled || isTTSActive) {
            startAmbient(fadeIn: true)
        }
    }
    
    public func setVolume(_ newVolume: Float) {
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped
        UserDefaults.standard.set(clamped, forKey: volumeKey)
        
        if isPlaying {
            avPlayer?.volume = clamped
        }
    }
    
    public func setStudyMode(_ enabled: Bool) {
        self.isStudyModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: studyModeKey)
        
        if enabled && currentPreset != nil && !isPlaying {
            startAmbient(fadeIn: true)
        } else if !enabled && !isTTSActive && isPlaying {
            stopAmbient(fadeOut: true)
        }
    }
    
    // MARK: - Playback Control
    
    public func startAmbient(fadeIn: Bool = true) {
        guard let preset = currentPreset else { return }
        
        AudioSession.shared.configureSession()
        
        guard let url = urlForPreset(preset) else {
            print("Soundscape audio resource not found: \(preset.resourceName).m4a")
            return
        }
        
        do {
            if avPlayer == nil || avPlayer?.url != url {
                avPlayer = try AVAudioPlayer(contentsOf: url)
                avPlayer?.delegate = self
                avPlayer?.numberOfLoops = -1 // Infinite looping
                avPlayer?.prepareToPlay()
            }
            
            fadeTimer?.invalidate()
            fadeTimer = nil
            
            if fadeIn {
                avPlayer?.volume = 0.0
                avPlayer?.play()
                avPlayer?.setVolume(self.volume, fadeDuration: 1.0)
            } else {
                avPlayer?.volume = self.volume
                avPlayer?.play()
            }
            
            DispatchQueue.main.async {
                self.isPlaying = true
            }
        } catch {
            print("Failed to start ambient player: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }
    }
    
    public func pauseAmbient() {
        guard isPlaying else { return }
        avPlayer?.pause()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    public func stopAmbient(fadeOut: Bool = true) {
        guard isPlaying, let player = avPlayer else {
            avPlayer = nil
            DispatchQueue.main.async {
                self.isPlaying = false
            }
            return
        }
        
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        if fadeOut {
            player.setVolume(0.0, fadeDuration: 0.5)
            fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: false) { [weak self] _ in
                player.stop()
                self?.avPlayer = nil
                DispatchQueue.main.async {
                    self?.isPlaying = false
                }
            }
        } else {
            player.stop()
            avPlayer = nil
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }
    }
    
    // MARK: - TTS Lifecycle Hooks
    
    public func handleTTSPlayStarted() {
        isTTSActive = true
        if currentPreset != nil && !isPlaying {
            startAmbient(fadeIn: true)
        }
    }
    
    public func handleTTSPaused() {
        isTTSActive = false
        if !isStudyModeEnabled && isPlaying {
            pauseAmbient()
        }
    }
    
    public func handleTTSResumed() {
        isTTSActive = true
        if currentPreset != nil && !isPlaying {
            startAmbient(fadeIn: true)
        }
    }
    
    public func handleTTSStopped() {
        isTTSActive = false
        if !isStudyModeEnabled && isPlaying {
            stopAmbient(fadeOut: true)
        }
    }
    
    // MARK: - Helper
    
    private func urlForPreset(_ preset: SoundscapePreset) -> URL? {
        let name = preset.resourceName
        let ext = "m4a"
        
        // 1. Check in Resources/Soundscapes
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Soundscapes") {
            return url
        }
        // 2. Check in main bundle root
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        // 3. Fallback for test bundles or direct path
        for bundle in [Bundle(for: AmbientSoundscapePlayer.self), Bundle.allBundles.first(where: { $0.bundleIdentifier?.contains("Vachanam") == true })].compactMap({ $0 }) {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Soundscapes") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
