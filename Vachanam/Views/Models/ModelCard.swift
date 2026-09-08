//
//  ModelCard.swift
//  Vachanam
//
//  Card displaying model specifications, RAM constraints, and download/delete controls.
//

import SwiftUI

public struct ModelCard: View {
    public let model: TTSModelMetadata
    @ObservedObject var modelManager = ModelManager.shared
    
    public init(model: TTSModelMetadata) {
        self.model = model
    }
    
    public var body: some View {
        let isCompatible = DeviceCapability.shared.canRun(model: model)
        let downloadState = modelManager.downloadStates[model.id] ?? .notDownloaded
        let isActive = modelManager.activeModelId == model.id
        
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        Text(model.version)
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(4)
                        
                        Text(model.format.rawValue.uppercased())
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.tealAccent.opacity(0.25))
                            .foregroundColor(Color.tealAccent)
                            .cornerRadius(4)
                    }
                    
                    Text(model.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                Spacer()
                
                if isActive {
                    Text("ACTIVE")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.amberAccent)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                }
            }
            
            // Stats Badges (Size, RAM)
            HStack(spacing: 12) {
                Label(model.formattedSize, systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("RAM: \(model.formattedRAM)", systemImage: "memorychip")
                    .font(.caption)
                    .foregroundColor(isCompatible ? .secondary : .red)
                
                if model.supportsWordTimestamps {
                    Label("Precise Timestamps", systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(Color.tealAccent)
                }
            }
            
            // Incompatibility warning
            if !isCompatible {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Requires \(model.minDeviceRAM)GB+ RAM (Device: ~\(DeviceCapability.shared.physicalRAMGigabytes)GB)")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
                .padding(8)
                .background(Color.red.opacity(0.12))
                .cornerRadius(6)
            }
            
            // Download Progress / Action Buttons
            HStack {
                switch downloadState {
                case .notDownloaded:
                    Button {
                        modelManager.downloadModel(model)
                    } label: {
                        Label("Download (\(model.formattedSize))", systemImage: "arrow.down.circle")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.amberAccent)
                    .disabled(!isCompatible)
                    
                case .downloading(let progress):
                    ModelDownloadProgress(progress: progress)
                    
                case .downloaded:
                    HStack(spacing: 12) {
                        if !isActive {
                            Button("Activate") {
                                modelManager.activeModelId = model.id
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.tealAccent)
                        }
                        
                        Button {
                            modelManager.deleteModel(model.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.85))
                        }
                        .help("Delete model weights")
                    }
                    
                case .failed(let error):
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.10, green: 0.13, blue: 0.19))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.amberAccent : Color.white.opacity(0.08), lineWidth: isActive ? 2.0 : 1.0)
        )
    }
}
