//
//  ModelManagerView.swift
//  Vachanam
//
//  Manage on-device neural TTS models: download weights, inspect RAM footprint, and delete.
//

import SwiftUI

public struct ModelManagerView: View {
    @ObservedObject var modelManager = ModelManager.shared
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Device Capability Header
                    HStack {
                        Image(systemName: "cpu")
                            .font(.title)
                            .foregroundColor(Color.amberAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Silicon Neural Engine")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Available Unified Memory: ~\(DeviceCapability.shared.physicalRAMGigabytes) GB RAM")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.10, green: 0.14, blue: 0.20))
                    .cornerRadius(12)
                    
                    Text("Available On-Device Models")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.top, 6)
                    
                    // Model Cards
                    ForEach(ModelRegistry.shared.availableModels) { model in
                        ModelCard(model: model)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.05, green: 0.08, blue: 0.13))
            .navigationTitle("TTS Models")
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
