//
//  DeveloperModeManager.swift
//  Vachanam
//
//  Central manager for Developer & Diagnostics Mode, enabling deep inspection
//  of PDF structure, sentence segmentation, phonemization, and voice synthesis.
//

import SwiftUI
import Combine

extension Notification.Name {
    public static let openDeveloperInspector = Notification.Name("vachanam_open_developer_inspector")
    public static let toggleDeveloperMode = Notification.Name("vachanam_toggle_developer_mode")
}

@MainActor
public final class DeveloperModeManager: ObservableObject {
    public static let shared = DeveloperModeManager()
    
    private let userDefaultsKey = "vachanam_developer_mode_enabled"
    
    @Published public var isDeveloperModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDeveloperModeEnabled, forKey: userDefaultsKey)
        }
    }
    
    private init() {
        self.isDeveloperModeEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
    
    public func toggle() {
        isDeveloperModeEnabled.toggle()
    }
}
