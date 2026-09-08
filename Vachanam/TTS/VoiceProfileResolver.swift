//
//  VoiceProfileResolver.swift
//  Vachanam
//
//  Maps model identifiers and custom voice presets to system speech synthesis voices,
//  custom pitch, and cadence multipliers. Ensures clean, expressive speech auditioning
//  without static, humming, or placeholder audio artifacts.
//

import Foundation
import AVFoundation

public struct ResolvedVoiceProfile {
    public let voice: AVSpeechSynthesisVoice?
    public let pitchMultiplier: Float
    public let rateMultiplier: Float
    public let cleanedText: String
    
    public init(voice: AVSpeechSynthesisVoice?, pitchMultiplier: Float = 1.0, rateMultiplier: Float = 1.0, cleanedText: String) {
        self.voice = voice
        self.pitchMultiplier = pitchMultiplier
        self.rateMultiplier = rateMultiplier
        self.cleanedText = cleanedText
    }
}

public class VoiceProfileResolver {
    public static let shared = VoiceProfileResolver()
    
    private var cachedVoices: [AVSpeechSynthesisVoice] = []
    
    private init() {
        self.cachedVoices = AVSpeechSynthesisVoice.speechVoices()
    }
    
    /// Resolves the optimal voice, pitch, and speech rate for a given model ID and voice preset.
    public func resolve(modelId: String, voiceName: String?, text: String) -> ResolvedVoiceProfile {
        // Strip prosody markup tags like [laugh], [sigh], [whisper] so speech synthesis reads cleanly
        let clean = text
            .replacingOccurrences(of: "\\[(laugh|sigh|whisper|gasp|pause|chuckle)\\]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let allVoices = cachedVoices.isEmpty ? AVSpeechSynthesisVoice.speechVoices() : cachedVoices
        let selectedVoice = voiceName?.lowercased() ?? ""
        
        switch modelId {
        case "kokoro-v1.0-en":
            return resolveKokoroVoice(voiceName: selectedVoice, text: clean, allVoices: allVoices)
            
        case "qwen3-tts-0.6b-en":
            return resolveQwen3Voice(voiceName: selectedVoice, text: clean, allVoices: allVoices)
            
        case "chatterbox-turbo-en":
            return resolveChatterboxVoice(voiceName: selectedVoice, text: clean, allVoices: allVoices)
            
        case "cosyvoice3-0.5b":
            return resolveCosyVoice(voiceName: selectedVoice, text: clean, allVoices: allVoices)
            
        default:
            let defaultVoice = AVSpeechSynthesisVoice(language: "en-US")
            return ResolvedVoiceProfile(voice: defaultVoice, pitchMultiplier: 1.0, rateMultiplier: 1.0, cleanedText: clean)
        }
    }
    
    // MARK: - Model Specific Mappings
    
    private func resolveKokoroVoice(voiceName: String, text: String, allVoices: [AVSpeechSynthesisVoice]) -> ResolvedVoiceProfile {
        if voiceName.contains("af_bella") {
            // American Female - Melodic & bright
            let voice = findVoice(in: allVoices, language: "en-US", gender: .female, preferredNames: ["Ava", "Victoria", "Samantha"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 1.12, rateMultiplier: 1.02, cleanedText: text)
        } else if voiceName.contains("am_michael") {
            // American Male - Deep & resonant
            let voice = findVoice(in: allVoices, language: "en-US", gender: .male, preferredNames: ["Alex", "Tom", "Aaron"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 0.90, rateMultiplier: 0.98, cleanedText: text)
        } else if voiceName.contains("am_adam") {
            // American Male - Conversational & friendly
            let voice = findVoice(in: allVoices, language: "en-US", gender: .male, preferredNames: ["Fred", "Evan", "Nathan"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 0.98, rateMultiplier: 1.0, cleanedText: text)
        } else if voiceName.contains("bf_emma") {
            // British Female - Crisp & refined
            let voice = findVoice(in: allVoices, language: "en-GB", gender: .female, preferredNames: ["Stephanie", "Martha", "Serena"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 1.05, rateMultiplier: 0.98, cleanedText: text)
        } else if voiceName.contains("bm_george") {
            // British Male - Classic British narrator
            let voice = findVoice(in: allVoices, language: "en-GB", gender: .male, preferredNames: ["Daniel", "Oliver", "Arthur"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 0.95, rateMultiplier: 0.98, cleanedText: text)
        } else {
            // af_heart or default: American Female - Warm & expressive
            let voice = findVoice(in: allVoices, language: "en-US", gender: .female, preferredNames: ["Samantha", "Allison", "Ava", "Susan"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 1.04, rateMultiplier: 1.0, cleanedText: text)
        }
    }
    
    private func resolveQwen3Voice(voiceName: String, text: String, allVoices: [AVSpeechSynthesisVoice]) -> ResolvedVoiceProfile {
        if voiceName.contains("warm_narrator") {
            let voice = findVoice(in: allVoices, language: "en-US", gender: .male, preferredNames: ["Alex", "Tom"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 0.92, rateMultiplier: 0.95, cleanedText: text)
        } else if voiceName.contains("expressive_female") {
            let voice = findVoice(in: allVoices, language: "en-US", gender: .female, preferredNames: ["Samantha", "Victoria"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 1.08, rateMultiplier: 1.02, cleanedText: text)
        } else {
            // Natural neutral
            let voice = AVSpeechSynthesisVoice(language: "en-US")
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 1.0, rateMultiplier: 1.0, cleanedText: text)
        }
    }
    
    private func resolveChatterboxVoice(voiceName: String, text: String, allVoices: [AVSpeechSynthesisVoice]) -> ResolvedVoiceProfile {
        if voiceName.contains("storyteller") {
            let voice = findVoice(in: allVoices, language: "en-GB", gender: .male, preferredNames: ["Daniel", "Oliver"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 0.88, rateMultiplier: 0.90, cleanedText: text)
        } else if voiceName.contains("female") {
            let voice = findVoice(in: allVoices, language: "en-US", gender: .female, preferredNames: ["Samantha", "Ava"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 1.10, rateMultiplier: 1.05, cleanedText: text)
        } else {
            // Expressive male
            let voice = findVoice(in: allVoices, language: "en-US", gender: .male, preferredNames: ["Alex", "Tom"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 0.96, rateMultiplier: 1.04, cleanedText: text)
        }
    }
    
    private func resolveCosyVoice(voiceName: String, text: String, allVoices: [AVSpeechSynthesisVoice]) -> ResolvedVoiceProfile {
        if voiceName.contains("academic") {
            let voice = findVoice(in: allVoices, language: "en-US", gender: .male, preferredNames: ["Alex", "Fred"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 1.02, rateMultiplier: 1.02, cleanedText: text)
        } else if voiceName.contains("soft_story") {
            let voice = findVoice(in: allVoices, language: "en-US", gender: .female, preferredNames: ["Samantha", "Susan"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 1.06, rateMultiplier: 0.92, cleanedText: text)
        } else {
            // Balanced warm
            let voice = findVoice(in: allVoices, language: "en-US", gender: .female, preferredNames: ["Samantha", "Ava"])
            return ResolvedVoiceProfile(voice: voice, pitchMultiplier: 0.98, rateMultiplier: 0.98, cleanedText: text)
        }
    }
    
    // MARK: - Voice Lookup Helper
    
    private func findVoice(
        in allVoices: [AVSpeechSynthesisVoice],
        language: String,
        gender: AVSpeechSynthesisVoiceGender,
        preferredNames: [String] = []
    ) -> AVSpeechSynthesisVoice {
        let matchingLang = allVoices.filter { $0.language.hasPrefix(language) }
        let matchingGender = matchingLang.filter { $0.gender == gender }
        
        // 1. Try to find by preferred voice name (e.g. Samantha, Alex, Daniel)
        for preferred in preferredNames {
            if let matched = matchingGender.first(where: { $0.name.localizedCaseInsensitiveContains(preferred) }) {
                return matched
            }
        }
        
        // 2. Try enhanced quality in matching gender
        if let enhanced = matchingGender.first(where: { $0.quality == .enhanced || $0.quality == .premium }) {
            return enhanced
        }
        
        // 3. Any in matching gender
        if let anyInGender = matchingGender.first {
            return anyInGender
        }
        
        // 4. Any in matching language
        if let anyInLang = matchingLang.first {
            return anyInLang
        }
        
        // 5. System fallback
        return AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "en-US")!
    }
}
