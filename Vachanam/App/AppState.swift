//
//  AppState.swift
//  Vachanam
//
//  Global application state managing the active document, playback status, and navigation.
//

import Foundation
import Combine

public class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var currentDocument: ReaderDocument?
    @Published public var selectedTab: String = "library"
    
    public init() {}
    
    public func openDocument(_ document: ReaderDocument) {
        self.currentDocument = document
    }
    
    public func closeCurrentDocument() {
        self.currentDocument = nil
    }
}
