//
//  QueryResultsToolbar.swift
//  DragonDB
//
//  Created by ghazi on 12/17/25.
//

import SwiftUI

/// Header bar sitting directly above the results table.
/// Provides JSON viewer, edit, delete buttons and the results filter field.
struct QueryResultsToolbar: View {
    @Environment(AppState.self) private var appState

    /// Nil until MainSplitView constructs it on first appear. The bar still
    /// renders (disabled) so its height never changes and the split divider
    /// does not jump.
    let viewModel: DetailContentViewModel?

    @Binding var searchText: String

    @FocusState private var isFilterFocused: Bool

    private var hasNoSelection: Bool {
        appState.query.selectedRowIDs.isEmpty
    }

    private var isEditingDisabledDueToContextMismatch: Bool {
        viewModel?.isEditingDisabledDueToContextMismatch ?? false
    }

    private var mutationHelpText: String? {
        isEditingDisabledDueToContextMismatch
            ? DetailContentViewModel.contextMismatchHelpText
            : nil
    }

    var body: some View {
        HStack(spacing: Constants.Spacing.small) {
            // JSON Viewer button
            IconActionButton(
                systemName: "square.and.arrow.down",
                action: { viewModel?.openJSONView() },
                isDisabled: viewModel == nil || hasNoSelection,
                helpText: "View selected rows as JSON",
                useHoverPopover: false
            )

            // Edit button
            IconActionButton(
                systemName: "square.and.pencil",
                action: { viewModel?.editSelectedRows() },
                isDisabled: viewModel == nil || hasNoSelection || isEditingDisabledDueToContextMismatch,
                helpText: mutationHelpText ?? "Edit selected row",
                useHoverPopover: isEditingDisabledDueToContextMismatch
            )

            // Delete button
            IconActionButton(
                systemName: "trash",
                action: { viewModel?.deleteSelectedRows() },
                isDisabled: viewModel == nil || hasNoSelection || isEditingDisabledDueToContextMismatch,
                helpText: mutationHelpText ?? "Delete selected rows",
                useHoverPopover: isEditingDisabledDueToContextMismatch
            )

            Spacer()

            filterField
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    /// Mirrors the saved-queries filter field so both filters in the window read
    /// as the same control.
    private var filterField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextField("Filter results", text: $searchText)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .focused($isFilterFocused)
                .onExitCommand {
                    isFilterFocused = false
                }
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: 260)
        .background(
            Capsule()
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            Capsule()
                .stroke(Color.secondary, lineWidth: 0.5)
                .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
                .clipShape(Capsule())
        )
        .clipShape(Capsule())
    }
}

private struct IconActionButton: View {
    let systemName: String
    let action: () -> Void
    let isDisabled: Bool
    let helpText: String
    let useHoverPopover: Bool

    @State private var isHovered = false

    var body: some View {
        ZStack {
            Button(action: action) {
                Image(systemName: systemName)
            }
            .buttonStyle(.borderless)
            .disabled(isDisabled)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(useHoverPopover ? "" : helpText)
        .popover(
            isPresented: Binding(
                get: { useHoverPopover && isHovered },
                set: { newValue in
                    if !newValue {
                        isHovered = false
                    }
                }
            ),
            arrowEdge: .bottom
        ) {
            Text(helpText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
        }
    }
}
