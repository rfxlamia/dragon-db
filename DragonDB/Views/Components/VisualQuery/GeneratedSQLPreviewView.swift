//
//  GeneratedSQLPreviewView.swift
//  DragonDB
//
//  Read-only generated SQL preview with Copy — not an editable source of truth.
//

import AppKit
import SwiftUI

struct GeneratedSQLPreviewView: View {
    let sql: String
    let onDismiss: () -> Void

    private var preview: VisualQueryCopy.GeneratedSQLPreviewModel {
        VisualQueryCopy.generatedSQLPreviewModel(sql: sql)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            HStack {
                Text(VisualQueryCopy.viewGeneratedSQLTitle)
                    .font(.headline)
                Spacer()
                Button(VisualQueryCopy.copySQLTitle) {
                    copySQL()
                }
                .disabled(!preview.allowsCopy || preview.sql.isEmpty)
                .accessibilityIdentifier(VisualQueryAccessibility.copySQL)
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier(VisualQueryAccessibility.generatedSQLDone)
            }

            ScrollView {
                Text(preview.sql.isEmpty ? "—" : preview.sql)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Constants.Spacing.small)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityIdentifier(VisualQueryAccessibility.generatedSQLText)
            // Preview is intentionally non-editable; textSelection allows read/copy only.
        }
        .padding(Constants.Spacing.medium)
        .frame(minWidth: 480, minHeight: 280)
    }

    private func copySQL() {
        guard preview.allowsCopy else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(preview.sql, forType: .string)
    }
}
