//
//  VisualStatementPickerView.swift
//  DragonDB
//
//  Statement type menu for the empty-canvas +. SELECT/CREATE runnable; UPDATE/DELETE Coming soon.
//

import SwiftUI

struct VisualStatementPickerView: View {
    let onChoose: (VisualStatementKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(VisualQueryCopy.statementMenuItems(), id: \.kind) { item in
                Button {
                    onChoose(item.kind)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold))
                            if let badge = item.badge {
                                Text(badge)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundStyle(.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        Text(item.helper)
                            .font(.system(size: Constants.FontSize.small))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(VisualQueryAccessibility.statementMenuItem(item.kind))
            }
        }
        .padding(4)
        .frame(minWidth: 220)
        .accessibilityIdentifier(VisualQueryAccessibility.statementMenu)
    }
}
