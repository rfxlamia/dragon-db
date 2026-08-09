//
//  VisualClauseCardView.swift
//  DragonDB
//
//  Single clause card shell with English helper, fields, and delete control.
//

import SwiftUI

struct VisualClauseCardView: View {
    let kind: VisualClauseKind
    let document: VisualQueryDocument
    let tables: [VisualTableReference]
    let columnNames: [String]
    let metadataErrorMessage: String?
    let onDelete: () -> Void
    let onSetSelectColumns: ([String]) -> Void
    let onSetFromTable: (String) -> Void
    let onSelectFromTable: (VisualTableReference) -> Void
    let onSetWhere: (String, VisualWhereOperator, String?) -> Void
    let onSetOrderBy: (String, VisualOrderDirection) -> Void
    let onSetLimitText: (String) -> Void

    @State var showSchemaPopover = false
    @State var popoverMode: SchemaPopoverMode = .columns

    enum SchemaPopoverMode {
        case tables
        case columns
    }

    private var isRootSelect: Bool { kind == .select }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(VisualQueryCopy.clauseTitle(for: kind))
                        .font(.system(size: 13, weight: .semibold))
                        .monospaced()
                    Text(VisualQueryCopy.helper(forClause: kind))
                        .font(.system(size: Constants.FontSize.small))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isRootSelect ? VisualQueryCopy.startOverTitle : VisualQueryCopy.deleteClauseTitle)
                .accessibilityIdentifier(VisualQueryAccessibility.deleteClause(kind))
            }

            fields
        }
        .padding(Constants.Spacing.small)
        .frame(minWidth: 220, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityIdentifier(VisualQueryAccessibility.clauseCard(kind))
        .popover(isPresented: $showSchemaPopover, arrowEdge: .bottom) {
            schemaPopoverContent
        }
    }

    @ViewBuilder
    private var schemaPopoverContent: some View {
        switch popoverMode {
        case .tables:
            SchemaFieldPopover(
                title: "Tables",
                items: tables,
                itemTitle: tableDisplayName,
                needsFromMessage: nil,
                errorMessage: nil
            ) { table in
                onSelectFromTable(table)
                showSchemaPopover = false
            }
        case .columns:
            let needsFrom = document.fromTable == nil
            SchemaFieldPopover(
                title: "Columns",
                items: needsFrom ? [] : columnNames,
                itemTitle: { $0 },
                needsFromMessage: needsFrom ? VisualQueryCopy.columnPopoverNeedsFromMessage : nil,
                errorMessage: needsFrom ? nil : metadataErrorMessage
            ) { name in
                applyColumnSelection(name)
                showSchemaPopover = false
            }
        }
    }

    private func tableDisplayName(_ table: VisualTableReference) -> String {
        guard let schema = table.schema, schema != "public" else {
            return table.name
        }
        return "\(schema).\(table.name)"
    }

    private func applyColumnSelection(_ name: String) {
        switch kind {
        case .select:
            if case .columns(let existing) = document.selectProjection {
                var next = existing.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                if !next.contains(name) {
                    next.append(name)
                }
                onSetSelectColumns(next)
            } else {
                onSetSelectColumns([name])
            }
        case .where:
            let op = document.whereCondition?.op ?? .equals
            let value = document.whereCondition?.value
            onSetWhere(name, op, value)
        case .orderBy:
            let direction = document.orderBy?.direction ?? .asc
            onSetOrderBy(name, direction)
        case .from, .limit, .join:
            break
        }
    }
}
