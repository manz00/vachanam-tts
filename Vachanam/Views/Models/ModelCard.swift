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
    @ObservedObject var ttsController = TTSController.shared
    
    public init(model: TTSModelMetadata) {
        self.model = model
    }
    
    public var body: some View {
        let isCompatible = DeviceCapability.shared.canRun(model: model)
        let downloadState = modelManager.downloadStates[model.id] ?? .notDownloaded
        let isActive = modelManager.activeModelId == model.id
        let isLoaded = modelManager.isModelLoaded(model.id) || (isActive && ttsController.isModelLoaded)
        let isLoading = isActive && ttsController.isModelLoading
        
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
                    if isLoaded {
                        Text("ACTIVE • LOADED")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.25))
                            .foregroundColor(.green)
                            .cornerRadius(6)
                    } else if isLoading {
                        Text("LOADING...")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.amberAccent.opacity(0.25))
                            .foregroundColor(Color.amberAccent)
                            .cornerRadius(6)
                    } else {
                        Text("ACTIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.amberAccent)
                            .foregroundColor(.black)
                            .cornerRadius(6)
                    }
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
                    VStack(alignment: .leading, spacing: 10) {
                        // Memory status badge
                        HStack(spacing: 8) {
                            if isLoaded {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("LOADED IN RAM (\(model.formattedRAM))")
                                        .font(.caption2.bold())
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(6)
                            } else if isLoading {
                                HStack(spacing: 5) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(Color.amberAccent)
                                    Text("LOADING INTO RAM...")
                                        .font(.caption2.bold())
                                        .foregroundColor(Color.amberAccent)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.amberAccent.opacity(0.15))
                                .cornerRadius(6)
                            } else {
                                HStack(spacing: 5) {
                                    Circle()
                                        .stroke(Color.secondary, lineWidth: 1.5)
                                        .frame(width: 8, height: 8)
                                    Text("UNLOADED (On Disk)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(6)
                            }
                        }
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            if !isActive {
                                Button("Activate & Load") {
                                    Task {
                                        try? await modelManager.loadModel(withId: model.id)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.tealAccent)
                            } else {
                                if isLoaded {
                                    Button("Unload") {
                                        modelManager.unloadModel(withId: model.id)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.secondary)
                                } else {
                                    Button("Load into RAM") {
                                        Task {
                                            try? await modelManager.loadModel(withId: model.id)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color.amberAccent)
                                    .disabled(isLoading)
                                }
                            }
                            
                            Button {
                                modelManager.deleteModel(model.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.85))
                            }
                            .help("Delete model weights")
                        }
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
