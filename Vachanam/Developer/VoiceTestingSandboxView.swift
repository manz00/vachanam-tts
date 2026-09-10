//
//  VoiceTestingSandboxView.swift
//  Vachanam
//
//  Interactive voice testing sandbox allowing live execution and step-by-step
//  inspection of the TTS pipeline (Normalization -> Verbalization -> Phonemization -> CoreML Synthesis).
//

import SwiftUI
import AVFoundation
import KokoroTTS

public struct VoiceTestingSandboxView: View {
    @Binding public var text: String
    public var documentTitle: String
    
    @State private var selectedVoice: String = "af_heart"
    @State private var speechSpeed: Float = 1.0
    @State private var isSynthesizing: Bool = false
    @State private var isPlaying: Bool = false
    
    @State private var normalizedText: String = ""
    @State private var verbalizedText: String = ""
    @State private var phonemes: String = ""
    @State private var phonemeTokenCount: Int = 0
    @State private var isOversizedBucket: Bool = false
    @State private var audioDuration: Double? = nil
    @State private var rtf: Double? = nil
    @State private var errorMessage: String? = nil
    
    @State private var synthesizedAudioResult: TTSAudioResult? = nil
    @State private var shareURL: URL? = nil
    @State private var copied: Bool = false
    
    private let availableVoices = [
        "af_heart", "af_alloy", "af_aoede", "af_bella", "am_adam", "am_michael",
        "bf_alice", "bf_emma", "bm_george", "bm_lewis", "apple-system-en"
    ]
    
    public init(text: Binding<String>, documentTitle: String = "Diagnostic Text") {
        self._text = text
        self.documentTitle = documentTitle
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header & Instructions
                VStack(alignment: .leading, spacing: 6) {
                    Text("Voice Testing Sandbox")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Test any sentence, paragraph, or mathematical formula through the multi-stage neural TTS pipeline.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Text Input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Input Text")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Button("Clear") {
                            text = ""
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Color.amberAccent)
                    }
                    
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(red: 0.10, green: 0.13, blue: 0.18))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                
                // Voice Controls
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Voice")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Picker("Voice", selection: $selectedVoice) {
                            ForEach(availableVoices, id: \.self) { voice in
                                Text(voice).tag(voice)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.amberAccent)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Speed")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2fx", speechSpeed))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Slider(value: $speechSpeed, in: 0.5...2.0, step: 0.05)
                            .frame(width: 140)
                            .tint(Color.amberAccent)
                    }
                }
                .padding()
                .background(Color(red: 0.08, green: 0.11, blue: 0.16))
                .cornerRadius(10)
                
                // Execute Button
                Button {
                    runPipeline()
                } label: {
                    HStack {
                        if isSynthesizing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            Text("Synthesizing...")
                        } else {
                            Image(systemName: "waveform")
                            Text("Run Voice Pipeline")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : Color.amberAccent)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSynthesizing)
                
                // Pipeline Results
                if !normalizedText.isEmpty || errorMessage != nil {
                    pipelineResultsSection
                }
            }
            .padding()
        }
        .background(Color(red: 0.05, green: 0.08, blue: 0.13))
    }
    
    private var pipelineResultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pipeline Execution Stages")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            // Stage 1: Normalization
            stageCard(
                stageNumber: 1,
                title: "Text Normalization (TextNormalizer)",
                content: normalizedText,
                badge: "Math & Symbols Formatted",
                badgeColor: .blue
            )
            
            // Stage 2: Number Verbalization
            stageCard(
                stageNumber: 2,
                title: "Number Verbalization (KokoroMisakiPhonemizer)",
                content: verbalizedText,
                badge: "Spelled Out",
                badgeColor: .purple
            )
            
            // Stage 3: Phonemization
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("3. Misaki Phonemizer")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if phonemeTokenCount > 0 {
                        Text("\(phonemeTokenCount) tokens")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isOversizedBucket ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                            .foregroundColor(isOversizedBucket ? .orange : .green)
                            .cornerRadius(6)
                    }
                }
                
                if !phonemes.isEmpty {
                    Text(phonemes)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color.amberAccent)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.06, green: 0.08, blue: 0.12))
                        .cornerRadius(6)
                } else {
                    Text("No phonemes generated")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(red: 0.08, green: 0.11, blue: 0.16))
            .cornerRadius(8)
            
            // Stage 4: Synthesis & Audio Playback
            if let duration = audioDuration {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("4. Neural CoreML Synthesis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        if let rtf = rtf {
                            Text(String(format: "RTF: %.2fx", rtf))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            togglePlayback()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                                Text(isPlaying ? "Stop" : "Play Audio")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.amberAccent)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                        }
                        
                        Text(String(format: "Duration: %.2fs", duration))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                .padding(12)
                .background(Color(red: 0.08, green: 0.11, blue: 0.16))
                .cornerRadius(8)
            }
            
            // Error Display if any
            if let error = errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Synthesis Error")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.12))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Export / Share Report Action
            HStack {
                Button {
                    copyReport()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Report Copied!" : "Copy Report JSON")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.amberAccent)
                }
                
                Spacer()
                
                if let url = shareURL {
                    ShareLink(item: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Download Report")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    }
                }
            }
            .padding(.top, 6)
        }
    }
    
    private func stageCard(stageNumber: Int, title: String, content: String, badge: String, badgeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(stageNumber). \(title)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.2))
                    .foregroundColor(badgeColor)
                    .cornerRadius(4)
            }
            Text(content.isEmpty ? "—" : content)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.06, green: 0.08, blue: 0.12))
                .cornerRadius(6)
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.11, blue: 0.16))
        .cornerRadius(8)
    }
    
    private func runPipeline() {
        let rawInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawInput.isEmpty else { return }
        
        isSynthesizing = true
        errorMessage = nil
        synthesizedAudioResult = nil
        audioDuration = nil
        rtf = nil
        isPlaying = false
        AudioPlayer.shared.stop()
        
        // Stage 1: Text Normalization
        let norm = TextNormalizer.shared.normalizeForSpeech(rawInput)
        self.normalizedText = norm
        
        // Stage 2: Number Verbalization
        let verb = KokoroMisakiPhonemizer.verbalizeNumbers(in: norm)
        self.verbalizedText = verb
        
        // Stage 3: Phonemization
        let phonemizer = KokoroMisakiPhonemizer()
        do {
            let res = try phonemizer.phonemize(verb)
            self.phonemes = res.phonemes
            self.phonemeTokenCount = res.phonemes.utf16.count
            self.isOversizedBucket = (res.phonemes.utf16.count + 2) > 128
        } catch {
            self.phonemes = ""
            self.phonemeTokenCount = 0
            self.errorMessage = "Phonemizer failed: \(error.localizedDescription)"
            isSynthesizing = false
            generateReport()
            return
        }
        
        // Stage 4: Neural Synthesis
        Task {
            let startTime = CACurrentMediaTime()
            do {
                let adapter = TTSController.shared.currentAdapter
                if !adapter.isLoaded {
                    await TTSController.shared.loadActiveModel()
                }
                
                let result = try await adapter.synthesize(
                    text: verb,
                    voice: selectedVoice,
                    speed: speechSpeed
                )
                let elapsed = CACurrentMediaTime() - startTime
                
                await MainActor.run {
                    self.synthesizedAudioResult = result
                    self.audioDuration = result.duration
                    if result.duration > 0 {
                        self.rtf = elapsed / result.duration
                    }
                    self.isSynthesizing = false
                    generateReport()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Synthesis failed: \(error.localizedDescription)"
                    self.isSynthesizing = false
                    generateReport()
                }
            }
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            AudioPlayer.shared.stop()
            isPlaying = false
        } else if let result = synthesizedAudioResult {
            isPlaying = true
            AudioPlayer.shared.play(result: result, speed: 1.0) {
                Task { @MainActor in
                    self.isPlaying = false
                }
            }
        }
    }
    
    private func generateReport() {
        let report = VoiceTestReport(
            inputText: text,
            voice: selectedVoice,
            speed: speechSpeed,
            normalizedText: normalizedText,
            verbalizedText: verbalizedText,
            phonemes: phonemes.isEmpty ? nil : phonemes,
            phonemeTokenCount: phonemeTokenCount,
            oversizedBucketTriggered: isOversizedBucket,
            audioDurationSeconds: audioDuration,
            realTimeFactor: rtf,
            success: errorMessage == nil,
            errorDescription: errorMessage,
            testedAt: ISO8601DateFormatter().string(from: Date())
        )
        let jsonStr = PageStructureExporter.exportJSONString(from: report)
        self.shareURL = PageStructureExporter.writeTemporaryJSONFile(
            filename: "voice_test_report_\(Int(Date().timeIntervalSince1970)).json",
            jsonString: jsonStr
        )
    }
    
    private func copyReport() {
        if let url = shareURL, let content = try? String(contentsOf: url, encoding: .utf8) {
            #if os(iOS) || targetEnvironment(macCatalyst)
            UIPasteboard.general.string = content
            #endif
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                copied = false
            }
        }
    }
}
