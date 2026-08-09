//
//  SchemaFieldPopover.swift
//  DragonDB
//
//  In-place schema popover shell: search + list, injectable names (no live DB required).
//

import SwiftUI

struct SchemaFieldPopover: View {
    let title: String
    let items: [String]
    let needsFromMessage: String?
    let onSelect: (String) -> Void

    @State private var searchText = ""

    private var filteredItems: [String] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
            Text(title)
                .font(.system(size: Constants.FontSize.small, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(VisualQueryAccessibility.schemaPopoverSearch)

            if let needsFromMessage, items.isEmpty {
                Text(needsFromMessage)
                    .font(.system(size: Constants.FontSize.small))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if filteredItems.isEmpty {
                Text("No matches")
                    .font(.system(size: Constants.FontSize.small))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredItems, id: \.self) { item in
                            Button {
                                onSelect(item)
                            } label: {
                                Text(item)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                        }
                    }
                }
                .frame(maxHeight: 180)
                .accessibilityIdentifier(VisualQueryAccessibility.schemaPopoverList)
            }
        }
        .padding(Constants.Spacing.small)
        .frame(width: 240)
    }
}
