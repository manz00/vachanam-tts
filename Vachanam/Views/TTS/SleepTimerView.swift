//
//  SleepTimerView.swift
//  Vachanam
//
//  Sleep timer selection sheet with live countdown.
//

import SwiftUI

public struct SleepTimerView: View {
    @ObservedObject var sleepTimer = SleepTimer.shared
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                if sleepTimer.activeOption != .off {
                    Section {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(Color.amberAccent)
                            Text("Time Remaining")
                            Spacer()
                            Text(sleepTimer.formattedRemainingTime)
                                .font(.title3.bold())
                                .foregroundColor(Color.amberAccent)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Turn Off Playback After")) {
                    ForEach(SleepTimerOption.allCases) { option in
                        Button {
                            sleepTimer.setOption(option)
                            if option == .off {
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundColor(.white)
                                Spacer()
                                if sleepTimer.activeOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.amberAccent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
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
