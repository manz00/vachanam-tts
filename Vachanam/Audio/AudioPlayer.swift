//
//  AudioPlayer.swift
//  Vachanam
//
//  Robust audio playback supporting both Neural Audio (AVAudioPlayer) and System Speech Synthesis.
//  Completely avoids simulator HALC CoreAudio proxy overloads and device conflicts.
//

import Foundation
import AVFoundation
import Combine

public class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    public static let shared = AudioPlayer()
    
    private var avPlayer: AVAudioPlayer?
    private var speechSynthesizer: AVSpeechSynthesizer?
    
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0.0
    @Published public var currentDuration: TimeInterval = 0.0
    
    private var playbackTimer: AnyCancellable?
    private var onCompleteHandler: (() -> Void)?
    private var onWordRangeHandler: ((NSRange) -> Void)?
    
    public override init() {
        super.init()
    }
    
    // MARK: - Speech Synthesis Mode (Instant, high-quality, natural speech)
    
    public func speakText(_ text: String, speed: Float = 1.0, onWordRange: ((NSRange) -> Void)? = nil, onComplete: (() -> Void)? = nil) {
        stop()
        
        AudioSession.shared.configureSession()
        
        if speechSynthesizer == nil {
            speechSynthesizer = AVSpeechSynthesizer()
            speechSynthesizer?.delegate = self
        }
        
        self.onCompleteHandler = onComplete
        self.onWordRangeHandler = onWordRange
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        // Base rate mapping (0.5x to 2.0x -> AVSpeechUtterance rate)
        let baseRate = AVSpeechUtteranceDefaultSpeechRate
        utterance.rate = min(max(baseRate * (speed / 1.0), AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        utterance.pitchMultiplier = 1.0
        
        isPlaying = true
        speechSynthesizer?.speak(utterance)
    }
    
    // MARK: - Neural Audio / WAV Buffer Playback
    
    public func play(result: TTSAudioResult, speed: Float = 1.0, onComplete: (() -> Void)? = nil) {
        stop()
        
        AudioSession.shared.configureSession()
        
        self.currentDuration = result.duration
        self.currentTime = 0.0
        self.onCompleteHandler = onComplete
        
        // Prepare WAV formatted data from raw audio
        let wavData = prepareWavData(from: result)
        
        do {
            avPlayer = try AVAudioPlayer(data: wavData)
            avPlayer?.delegate = self
            avPlayer?.enableRate = true
            avPlayer?.rate = speed
            avPlayer?.prepareToPlay()
            
            if avPlayer?.play() == true {
                isPlaying = true
                startPlaybackTimer(speed: speed)
            } else {
                onComplete?()
            }
        } catch {
            print("AVAudioPlayer error: \(error.localizedDescription)")
            onComplete?()
        }
    }
    
    public func pause() {
        if let synth = speechSynthesizer, synth.isSpeaking {
            synth.pauseSpeaking(at: .immediate)
        }
        avPlayer?.pause()
        isPlaying = false
        playbackTimer?.cancel()
    }
    
    public func resume() {
        if let synth = speechSynthesizer, synth.isPaused {
            synth.continueSpeaking()
            isPlaying = true
            return
        }
        
        if let player = avPlayer, !player.isPlaying {
            player.play()
            isPlaying = true
            startPlaybackTimer(speed: player.rate)
        }
    }
    
    public func stop() {
        if let synth = speechSynthesizer, synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        avPlayer?.stop()
        avPlayer = nil
        isPlaying = false
        currentTime = 0.0
        playbackTimer?.cancel()
    }
    
    // MARK: - Timers & Delegates
    
    private func startPlaybackTimer(speed: Float) {
        playbackTimer?.cancel()
        playbackTimer = Timer.publish(every: 0.04, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let player = self.avPlayer, self.isPlaying else { return }
                self.currentTime = player.currentTime
            }
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playbackTimer?.cancel()
            self.onCompleteHandler?()
        }
    }
    
    // AVSpeechSynthesizerDelegate
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.onWordRangeHandler?(characterRange)
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.onCompleteHandler?()
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    // MARK: - WAV Header Helper
    
    private func prepareWavData(from result: TTSAudioResult) -> Data {
        let sampleRate = Int32(result.sampleRate)
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        
        // Convert Float buffer to 16-bit PCM if buffer available
        var pcm16Data = Data()
        if let buffer = result.pcmBuffer, let channelData = buffer.floatChannelData?[0] {
            let frameCount = Int(buffer.frameLength)
            var samples = [Int16](repeating: 0, count: frameCount)
            for i in 0..<frameCount {
                let s = max(-1.0, min(1.0, channelData[i]))
                samples[i] = Int16(s * 32767.0)
            }
            samples.withUnsafeBytes { pcm16Data.append(contentsOf: $0) }
        } else {
            pcm16Data = result.audioData
        }
        
        let subchunk2Size = Int32(pcm16Data.count)
        let byteRate = sampleRate * Int32(numChannels) * Int32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let chunkSize = 36 + subchunk2Size
        
        var wav = Data()
        wav.append("RIFF".data(using: .ascii)!)
        withUnsafeBytes(of: chunkSize.littleEndian) { wav.append(contentsOf: $0) }
        wav.append("WAVE".data(using: .ascii)!)
        wav.append("fmt ".data(using: .ascii)!)
        withUnsafeBytes(of: Int32(16).littleEndian) { wav.append(contentsOf: $0) }
        withUnsafeBytes(of: Int16(1).littleEndian) { wav.append(contentsOf: $0) }
        withUnsafeBytes(of: numChannels.littleEndian) { wav.append(contentsOf: $0) }
        withUnsafeBytes(of: sampleRate.littleEndian) { wav.append(contentsOf: $0) }
        withUnsafeBytes(of: byteRate.littleEndian) { wav.append(contentsOf: $0) }
        withUnsafeBytes(of: blockAlign.littleEndian) { wav.append(contentsOf: $0) }
        withUnsafeBytes(of: bitsPerSample.littleEndian) { wav.append(contentsOf: $0) }
        wav.append("data".data(using: .ascii)!)
        withUnsafeBytes(of: subchunk2Size.littleEndian) { wav.append(contentsOf: $0) }
        wav.append(pcm16Data)
        return wav
    }
}
