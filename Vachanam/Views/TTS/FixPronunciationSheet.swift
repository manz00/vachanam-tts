//
//  FixPronunciationSheet.swift
//  Vachanam
//
//  Interactive modal to inspect and correct pronunciations, test phonetics,
//  and persist overrides at the book or user level.
//

import SwiftUI

public struct FixPronunciationSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public let initialWord: String
    public let documentID: UUID?
    
    @State private var wordToMatch: String
    @State private var replacementText: String
    @State private var selectedScope: PronunciationScope = .user
    @State private var isTesting: Bool = false
    @State private var testErrorMessage: String? = nil
    
    public init(initialWord: String = "", documentID: UUID? = nil) {
        self.initialWord = initialWord
        self.documentID = documentID
        _wordToMatch = State(initialValue: initialWord)
        _replacementText = State(initialValue: "")
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Word to Pronounce").foregroundColor(.secondary)) {
                    TextField("Original Word (e.g. Euler)", text: $wordToMatch)
                        .font(.system(.body, design: .rounded))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                
                Section(
                    header: Text("Spoken Form / Phonetic Spelling").foregroundColor(.secondary),
                    footer: Text("Spell out the word phonetically or how you want the narrator to speak it (e.g. 'Oiler' for Euler, 'gooey' for GUI).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                ) {
                    TextField("Spoken Replacement (e.g. Oiler)", text: $replacementText)
                        .font(.system(.body, design: .rounded))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                
                Section(header: Text("Rule Scope").foregroundColor(.secondary)) {
                    Picker("Apply Scope", selection: $selectedScope) {
                        Text("All Books (User Rule)").tag(PronunciationScope.user)
                        if documentID != nil {
                            Text("This Book Only").tag(PronunciationScope.book)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if let error = testErrorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button {
                        testPronunciation()
                    } label: {
                        HStack {
                            Image(systemName: isTesting ? "waveform" : "speaker.wave.2.fill")
                                .foregroundColor(Color.tealAccent)
                            Text(isTesting ? "Speaking..." : "Preview Pronunciation")
                                .fontWeight(.medium)
                        }
                    }
                    .disabled(wordToMatch.trimmingCharacters(in: .whitespaces).isEmpty || isTesting)
                }
            }
            .navigationTitle("Fix Pronunciation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Apply") {
                        saveRule()
                    }
                    .fontWeight(.bold)
                    .disabled(wordToMatch.trimmingCharacters(in: .whitespaces).isEmpty ||
                              replacementText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadExistingRule()
            }
        }
    }
    
    private func loadExistingRule() {
        let trimmed = wordToMatch.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let activeRules = PronunciationManager.shared.rules(for: documentID)
        if let existing = activeRules.first(where: { $0.match.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            replacementText = existing.spokenText
            selectedScope = existing.scope
        }
    }
    
    private func testPronunciation() {
        let textToSpeak = replacementText.trimmingCharacters(in: .whitespaces).isEmpty ?
            wordToMatch.trimmingCharacters(in: .whitespaces) :
            replacementText.trimmingCharacters(in: .whitespaces)
        guard !textToSpeak.isEmpty else { return }
        
        isTesting = true
        testErrorMessage = nil
        
        Task { @MainActor in
            let adapter = TTSController.shared.currentAdapter
            let voice = TTSController.shared.selectedVoice
            let speed = TTSController.shared.speechSpeed
            
            do {
                let result = try await adapter.synthesize(text: textToSpeak, voice: voice, speed: speed)
                AudioPlayer.shared.play(result: result, speed: speed)
                isTesting = false
            } catch {
                testErrorMessage = "Preview failed: \(error.localizedDescription)"
                isTesting = false
            }
        }
    }
    
    private func saveRule() {
        let trimmedWord = wordToMatch.trimmingCharacters(in: .whitespaces)
        let trimmedReplacement = replacementText.trimmingCharacters(in: .whitespaces)
        guard !trimmedWord.isEmpty, !trimmedReplacement.isEmpty else { return }
        
        let rule = PronunciationRule(
            match: trimmedWord,
            spokenText: trimmedReplacement,
            scope: selectedScope,
            documentID: (selectedScope == .book) ? documentID : nil,
            note: "Listener correction"
        )
        PronunciationManager.shared.addRule(rule)
        
        // If PlaybackCoordinator is currently active, reload current chunk if affected
        if let doc = PlaybackCoordinator.shared.activeSemanticDocument {
            if let currentWordID = PlaybackCoordinator.shared.currentWordID,
               let word = doc.word(id: currentWordID),
               word.text.caseInsensitiveCompare(trimmedWord) == .orderedSame {
                PlaybackCoordinator.shared.play(fromWordID: currentWordID)
            }
        }
        
        dismiss()
    }
}
