//
//  SchemaFieldPopover.swift
//  DragonDB
//
//  In-place schema popover shell: search + list, injectable names (no live DB required).
//

import SwiftUI

struct SchemaFieldPopover<Item: Hashable>: View {
    let title: String
    let items: [Item]
    let itemTitle: (Item) -> String
    let needsFromMessage: String?
    let errorMessage: String?
    let onSelect: (Item) -> Void

    @State private var searchText = ""

    private var filteredItems: [Item] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { itemTitle($0).localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
            Text(title)
                .font(.system(size: Constants.FontSize.small, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(VisualQueryAccessibility.schemaPopoverSearch)

            if let emptyStateMessage {
                Text(emptyStateMessage)
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
                                Text(itemTitle(item))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .accessibilityIdentifier(
                                VisualQueryAccessibility.schemaPopoverItem(
                                    title: title,
                                    item: itemTitle(item)
                                )
                            )
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

    private var emptyStateMessage: String? {
        Self.emptyStateMessage(
            itemsAreEmpty: items.isEmpty,
            needsFromMessage: needsFromMessage,
            errorMessage: errorMessage
        )
    }

    static func emptyStateMessage(
        itemsAreEmpty: Bool,
        needsFromMessage: String?,
        errorMessage: String?
    ) -> String? {
        guard itemsAreEmpty else { return nil }
        return needsFromMessage ?? errorMessage
    }
}

extension VisualQueryAccessibility {
    static func schemaPopoverItem(title: String, item: String) -> String {
        "visualQuery.schemaPopover.\(title.lowercased()).item.\(item)"
    }
}
