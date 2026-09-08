//
//  VoicePickerView.swift
//  Vachanam
//
//  Voice selection and active model picker sheet.
//

import SwiftUI

public struct VoicePickerView: View {
    @ObservedObject var modelManager = ModelManager.shared
    @ObservedObject var ttsController = TTSController.shared
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Active TTS Model")) {
                    ForEach(ModelRegistry.shared.availableModels) { model in
                        let isSelected = modelManager.activeModelId == model.id
                        Button {
                            modelManager.activeModelId = model.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(model.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(model.version)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.amberAccent)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if let currentModel = ModelRegistry.shared.model(withId: modelManager.activeModelId), !currentModel.voices.isEmpty {
                    Section(header: Text("Voice Profiles")) {
                        ForEach(currentModel.voices, id: \.self) { voice in
                            let isVoiceSelected = (ttsController.selectedVoice == voice) || (ttsController.selectedVoice == nil && voice == currentModel.voices.first)
                            Button {
                                ttsController.selectedVoice = voice
                            } label: {
                                HStack {
                                    Image(systemName: "person.wave.2")
                                        .foregroundColor(Color.tealAccent)
                                    Text(voice.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if isVoiceSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.tealAccent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
