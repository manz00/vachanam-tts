//
//  AnnotationExportView.swift
//  Vachanam
//
//  Export summary view showing formatted Markdown notes and sharing actions.
//

import SwiftUI

public struct AnnotationExportView: View {
    public let markdownContent: String
    @Environment(\.dismiss) var dismiss
    @State private var copied: Bool = false
    
    public init(markdownContent: String) {
        self.markdownContent = markdownContent
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(markdownContent)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.08, green: 0.11, blue: 0.16))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Export Annotations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        #if os(iOS) || targetEnvironment(macCatalyst)
                        UIPasteboard.general.string = markdownContent
                        #endif
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            copied = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied!" : "Copy")
                        }
                    }
                }
            }
        }
    }
}
