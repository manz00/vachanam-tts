//
//  SleepTimer.swift
//  Vachanam
//
//  Sleep timer options and countdown manager for bedtime listening.
//

import Foundation
import Combine

public enum SleepTimerOption: String, CaseIterable, Identifiable {
    case off = "Off"
    case minutes15 = "15 Minutes"
    case minutes30 = "30 Minutes"
    case minutes45 = "45 Minutes"
    case minutes60 = "60 Minutes"
    case endOfPage = "End of Page"
    
    public var id: String { rawValue }
    
    public var durationSeconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .minutes15: return 15 * 60
        case .minutes30: return 30 * 60
        case .minutes45: return 45 * 60
        case .minutes60: return 60 * 60
        case .endOfPage: return nil
        }
    }
}

public class SleepTimer: ObservableObject {
    public static let shared = SleepTimer()
    
    @Published public var activeOption: SleepTimerOption = .off
    @Published public var remainingSeconds: TimeInterval = 0
    
    private var timerCancellable: AnyCancellable?
    public var onTimerFired: (() -> Void)?
    
    public init() {}
    
    public func setOption(_ option: SleepTimerOption) {
        activeOption = option
        timerCancellable?.cancel()
        
        if let duration = option.durationSeconds {
            remainingSeconds = duration
            timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    if self.remainingSeconds > 1 {
                        self.remainingSeconds -= 1
                    } else {
                        self.stopTimer()
                        self.onTimerFired?()
                    }
                }
        } else {
            remainingSeconds = 0
        }
    }
    
    public func handlePageCompleted() {
        if activeOption == .endOfPage {
            stopTimer()
            onTimerFired?()
        }
    }
    
    public func stopTimer() {
        activeOption = .off
        remainingSeconds = 0
        timerCancellable?.cancel()
    }
    
    public var formattedRemainingTime: String {
        guard remainingSeconds > 0 else { return "Off" }
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
