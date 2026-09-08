//
//  AudioSession.swift
//  Vachanam
//
//  AVAudioSession configuration for background spoken audio and lock-screen media controls.
//

import Foundation
import AVFoundation
import MediaPlayer

public class AudioSession {
    public static let shared = AudioSession()
    
    private init() {}
    
    public func configureSession() {
        #if os(iOS) || targetEnvironment(macCatalyst)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
        #endif
    }
    
    public func setupRemoteCommands(onPlay: @escaping () -> Void, onPause: @escaping () -> Void, onSkipNext: @escaping () -> Void, onSkipPrevious: @escaping () -> Void) {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            onPlay()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            onSkipNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            onSkipPrevious()
            return .success
        }
    }
    
    public func updateNowPlaying(title: String, author: String = "Vachanam", elapsedTime: TimeInterval, duration: TimeInterval, isPlaying: Bool) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: author,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
