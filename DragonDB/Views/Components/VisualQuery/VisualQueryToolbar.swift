//
//  VisualQueryToolbar.swift
//  DragonDB
//
//  Visual query chrome: Run (disabled + help from VM), View generated SQL, Start over.
//

import SwiftUI

struct VisualQueryToolbar: View {
    let runEnabled: Bool
    let runHelpMessage: String?
    let isRunning: Bool
    let canStartOver: Bool
    let onRun: () -> Void
    let onViewGeneratedSQL: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        HStack(spacing: Constants.Spacing.small) {
            Button(action: onRun) {
                Label {
                    Text(VisualQueryCopy.runQueryTitle)
                } icon: {
                    Image(systemName: isRunning ? "hourglass" : "play.circle.fill")
                }
            }
            .buttonStyle(.glass)
            .clipShape(Capsule())
            .tint(.green)
            .disabled(!runEnabled || isRunning)
            .help(runHelpMessage ?? "")
            .accessibilityIdentifier(VisualQueryAccessibility.runQuery)

            Button(VisualQueryCopy.viewGeneratedSQLTitle, action: onViewGeneratedSQL)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(VisualQueryAccessibility.viewGeneratedSQL)

            if canStartOver {
                Button(VisualQueryCopy.startOverTitle, action: onStartOver)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(VisualQueryAccessibility.startOver)
            }

            Spacer()

            if let runHelpMessage, !runEnabled {
                Text(runHelpMessage)
                    .font(.system(size: Constants.FontSize.small))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(Constants.Spacing.small)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
