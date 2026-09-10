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
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .allowBluetoothHFP, .allowBluetoothA2DP])
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
        let nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: author,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    public var onInterruptionBegan: (() -> Void)?
    public var onInterruptionEnded: ((_ shouldResume: Bool) -> Void)?
    public var onRouteChangeShouldPause: (() -> Void)?
    
    private var isObserversSetup: Bool = false
    
    public func setupInterruptionObservers(
        onInterruptionBegan: (() -> Void)? = nil,
        onInterruptionEnded: ((_ shouldResume: Bool) -> Void)? = nil,
        onRouteChangeShouldPause: (() -> Void)? = nil
    ) {
        if let onBegan = onInterruptionBegan { self.onInterruptionBegan = onBegan }
        if let onEnded = onInterruptionEnded { self.onInterruptionEnded = onEnded }
        if let onRoute = onRouteChangeShouldPause { self.onRouteChangeShouldPause = onRoute }
        
        #if os(iOS) || targetEnvironment(macCatalyst)
        guard !isObserversSetup else { return }
        isObserversSetup = true
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }
            
            switch type {
            case .began:
                self?.onInterruptionBegan?()
            case .ended:
                let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                let shouldResume = options.contains(.shouldResume)
                self?.onInterruptionEnded?(shouldResume)
            @unknown default:
                break
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
            }
            
            switch reason {
            case .oldDeviceUnavailable:
                // User pulled out headphones or disconnected bluetooth audio
                self?.onRouteChangeShouldPause?()
            default:
                break
            }
        }
        #endif
    }
}
