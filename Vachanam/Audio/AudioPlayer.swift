//
//  AudioPlayer.swift
//  Vachanam
//
//  AVAudioEngine low-latency streaming player with playback time observer.
//

import Foundation
import AVFoundation
import Combine

public class AudioPlayer: ObservableObject {
    public static let shared = AudioPlayer()
    
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var timePitch = AVAudioUnitTimePitch()
    
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0.0
    @Published public var currentDuration: TimeInterval = 0.0
    
    private var playbackTimer: AnyCancellable?
    private var startTime: TimeInterval = 0.0
    private var onCompleteHandler: (() -> Void)?
    
    public init() {
        setupEngine()
    }
    
    private func setupEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(timePitch)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: 24000.0, channels: 1)!
        audioEngine.connect(playerNode, to: timePitch, format: format)
        audioEngine.connect(timePitch, to: audioEngine.mainMixerNode, format: format)
        
        try? audioEngine.start()
    }
    
    public func play(result: TTSAudioResult, speed: Float = 1.0, onComplete: (() -> Void)? = nil) {
        stop()
        
        guard let buffer = result.pcmBuffer else {
            onComplete?()
            return
        }
        
        self.currentDuration = result.duration
        self.currentTime = 0.0
        self.onCompleteHandler = onComplete
        self.timePitch.rate = speed
        
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        
        playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
                self?.playbackTimer?.cancel()
                self?.onCompleteHandler?()
            }
        }
        
        playerNode.play()
        isPlaying = true
        startTime = CACurrentMediaTime()
        
        playbackTimer = Timer.publish(every: 0.04, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }
                let elapsed = (CACurrentMediaTime() - self.startTime) * Double(speed)
                self.currentTime = min(elapsed, self.currentDuration)
            }
    }
    
    public func pause() {
        playerNode.pause()
        isPlaying = false
        playbackTimer?.cancel()
    }
    
    public func resume() {
        playerNode.play()
        isPlaying = true
        startTime = CACurrentMediaTime() - currentTime
    }
    
    public func stop() {
        playerNode.stop()
        isPlaying = false
        currentTime = 0.0
        playbackTimer?.cancel()
    }
}
