//
//  BookCollectionManager.swift
//  Vachanam
//
//  Manages book organization, shelves/collections, favorites, finished status,
//  and complete document deletion with file system and reading progress cleanup.
//

import Foundation
import Combine

public struct BookShelf: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var isSystem: Bool
    public var iconName: String
    public var documentPaths: Set<String>
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        isSystem: Bool = false,
        iconName: String = "books.vertical",
        documentPaths: Set<String> = []
    ) {
        self.id = id
        self.name = name
        self.isSystem = isSystem
        self.iconName = iconName
        self.documentPaths = documentPaths
    }
}

public enum SystemShelfFilter: String, CaseIterable, Identifiable {
    case all = "All Books"
    case reading = "Reading"
    case favorites = "Favorites"
    case finished = "Finished"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .reading: return "book.circle"
        case .favorites: return "heart.fill"
        case .finished: return "checkmark.seal.fill"
        }
    }
}

public class BookCollectionManager: ObservableObject {
    public static let shared = BookCollectionManager()
    
    private let shelvesStorageKey = "vachanam_book_shelves"
    private let favoritesStorageKey = "vachanam_favorite_paths"
    private let finishedStorageKey = "vachanam_finished_paths"
    
    @Published public var customShelves: [BookShelf] = []
    @Published public var favoritePaths: Set<String> = []
    @Published public var finishedPaths: Set<String> = []
    
    public init() {
        loadData()
    }
    
    // MARK: - Favorites
    
    public func isFavorite(path: String) -> Bool {
        favoritePaths.contains(path)
    }
    
    public func toggleFavorite(path: String) {
        if favoritePaths.contains(path) {
            favoritePaths.remove(path)
        } else {
            favoritePaths.insert(path)
        }
        saveData()
    }
    
    // MARK: - Finished
    
    public func isFinished(path: String) -> Bool {
        finishedPaths.contains(path)
    }
    
    public func toggleFinished(path: String) {
        if finishedPaths.contains(path) {
            finishedPaths.remove(path)
        } else {
            finishedPaths.insert(path)
        }
        saveData()
    }
    
    // MARK: - Custom Shelves
    
    @discardableResult
    public func createShelf(name: String, iconName: String = "books.vertical") -> BookShelf {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "New Shelf" : trimmed
        let shelf = BookShelf(name: finalName, isSystem: false, iconName: iconName)
        customShelves.append(shelf)
        saveData()
        return shelf
    }
    
    public func deleteShelf(id: String) {
        customShelves.removeAll { $0.id == id }
        saveData()
    }
    
    public func addDocument(path: String, toShelf shelfID: String) {
        if let idx = customShelves.firstIndex(where: { $0.id == shelfID }) {
            customShelves[idx].documentPaths.insert(path)
            saveData()
        }
    }
    
    public func removeDocument(path: String, fromShelf shelfID: String) {
        if let idx = customShelves.firstIndex(where: { $0.id == shelfID }) {
            customShelves[idx].documentPaths.remove(path)
            saveData()
        }
    }
    
    public func shelvesContaining(path: String) -> [BookShelf] {
        customShelves.filter { $0.documentPaths.contains(path) }
    }
    
    // MARK: - Complete File Deletion & Sandbox Cleanup
    
    public func deleteDocument(at url: URL) {
        let path = url.path
        
        // 1. Stop audio playback if actively playing
        if TTSController.shared.isPlaying {
            TTSController.shared.stop()
        }
        
        // 2. Remove from filesystem if in local sandbox
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            try? fileManager.removeItem(at: url)
        }
        
        // Also check if there's a copy in Documents
        if let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docCopy = docsDir.appendingPathComponent(url.lastPathComponent)
            if docCopy.path != path && fileManager.fileExists(atPath: docCopy.path) {
                try? fileManager.removeItem(at: docCopy)
            }
        }
        
        // 3. Remove progress tracker record
        ReadingProgressTracker.shared.removeRecord(path: path)
        
        // 4. Remove from favorites and finished
        favoritePaths.remove(path)
        finishedPaths.remove(path)
        
        // 5. Remove from all custom shelves
        for i in 0..<customShelves.count {
            customShelves[i].documentPaths.remove(path)
        }
        
        // 6. Persist collections state
        saveData()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        if let encodedShelves = try? JSONEncoder().encode(customShelves) {
            UserDefaults.standard.set(encodedShelves, forKey: shelvesStorageKey)
        }
        let favArray = Array(favoritePaths)
        UserDefaults.standard.set(favArray, forKey: favoritesStorageKey)
        
        let finArray = Array(finishedPaths)
        UserDefaults.standard.set(finArray, forKey: finishedStorageKey)
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: shelvesStorageKey),
           let decoded = try? JSONDecoder().decode([BookShelf].self, from: data) {
            self.customShelves = decoded
        }
        if let favs = UserDefaults.standard.stringArray(forKey: favoritesStorageKey) {
            self.favoritePaths = Set(favs)
        }
        if let fins = UserDefaults.standard.stringArray(forKey: finishedStorageKey) {
            self.finishedPaths = Set(fins)
        }
    }
}
