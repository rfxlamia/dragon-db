//
//  VisualClauseCardView.swift
//  DragonDB
//
//  Single clause / statement card with English helper, fields, and delete control.
//

import SwiftUI

struct VisualClauseCardView: View {
    let kind: VisualClauseKind
    let document: VisualQueryDocument
    let tableNames: [String]
    let columnNames: [String]
    let onDelete: () -> Void
    let onSetSelectColumns: ([String]) -> Void
    let onSetFromTable: (String) -> Void
    let onSetWhere: (String, VisualWhereOperator, String?) -> Void
    let onSetOrderBy: (String, VisualOrderDirection) -> Void
    let onSetLimitText: (String) -> Void

    @State private var showSchemaPopover = false
    @State private var popoverMode: SchemaPopoverMode = .columns

    private enum SchemaPopoverMode {
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
    private var fields: some View {
        switch kind {
        case .select:
            selectFields
        case .from:
            fromFields
        case .where:
            whereFields
        case .orderBy:
            orderByFields
        case .limit:
            limitFields
        case .join:
            EmptyView()
        }
    }

    private var selectFields: some View {
        let allColumns = document.selectProjection == .allColumns
        return VStack(alignment: .leading, spacing: 6) {
            Toggle(VisualQueryCopy.allColumnsTitle, isOn: Binding(
                get: { allColumns },
                set: { enabled in
                    if enabled {
                        onSetSelectColumns([])
                    } else if case .columns(let columns) = document.selectProjection, !columns.isEmpty {
                        onSetSelectColumns(columns)
                    } else {
                        onSetSelectColumns([""])
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .accessibilityIdentifier(VisualQueryAccessibility.allColumnsToggle)

            if !allColumns {
                schemaColumnField(
                    text: Binding(
                        get: { selectedColumnsText },
                        set: { onSetSelectColumns(parseSelectColumns($0)) }
                    ),
                    placeholder: "column, column",
                    fieldAccessibilityID: VisualQueryAccessibility.selectColumnsField,
                    pickerAccessibilityID: VisualQueryAccessibility.selectColumnsPicker
                )
            }
        }
    }

    private var selectedColumnsText: String {
        if case .columns(let columns) = document.selectProjection {
            return columns.joined(separator: ", ")
        }
        return ""
    }

    private func parseSelectColumns(_ text: String) -> [String] {
        text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private var fromFields: some View {
        HStack(spacing: 6) {
            TextField(
                "table",
                text: Binding(
                    get: { fromDisplayName },
                    set: { onSetFromTable($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier(VisualQueryAccessibility.fromTableField)

            Button {
                popoverMode = .tables
                showSchemaPopover = true
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .help("Choose a table")
            .accessibilityIdentifier(VisualQueryAccessibility.fromTablePicker)
        }
    }

    private var fromDisplayName: String {
        guard let table = document.fromTable else { return "" }
        if let schema = table.schema, !schema.isEmpty {
            return "\(schema).\(table.name)"
        }
        return table.name
    }

    private var whereFields: some View {
        let condition = document.whereCondition ?? VisualWhereCondition(column: "", op: .equals, value: nil)
        return VStack(alignment: .leading, spacing: 6) {
            schemaColumnField(
                text: Binding(
                    get: { condition.column },
                    set: { onSetWhere($0, condition.op, condition.value) }
                ),
                placeholder: "column",
                fieldAccessibilityID: VisualQueryAccessibility.whereColumnField,
                pickerAccessibilityID: VisualQueryAccessibility.whereColumnPicker
            )

            Picker(
                "Operator",
                selection: Binding(
                    get: { condition.op },
                    set: { onSetWhere(condition.column, $0, condition.value) }
                )
            ) {
                ForEach(whereOperators, id: \.self) { op in
                    Text(VisualQueryCopy.whereOperatorTitle(op)).tag(op)
                }
            }
            .labelsHidden()
            .accessibilityIdentifier(VisualQueryAccessibility.whereOperatorField)

            if condition.op != .isEmpty {
                TextField(
                    "value",
                    text: Binding(
                        get: { condition.value ?? "" },
                        set: { onSetWhere(condition.column, condition.op, $0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(VisualQueryAccessibility.whereValueField)
            }
        }
    }

    private var orderByFields: some View {
        let order = document.orderBy ?? VisualOrderBy(column: "", direction: .asc)
        return HStack(spacing: 6) {
            schemaColumnField(
                text: Binding(
                    get: { order.column },
                    set: { onSetOrderBy($0, order.direction) }
                ),
                placeholder: "column",
                fieldAccessibilityID: VisualQueryAccessibility.orderByColumnField,
                pickerAccessibilityID: VisualQueryAccessibility.orderByColumnPicker
            )

            Picker(
                "Direction",
                selection: Binding(
                    get: { order.direction },
                    set: { onSetOrderBy(order.column, $0) }
                )
            ) {
                Text(VisualQueryCopy.orderDirectionTitle(.asc)).tag(VisualOrderDirection.asc)
                Text(VisualQueryCopy.orderDirectionTitle(.desc)).tag(VisualOrderDirection.desc)
            }
            .labelsHidden()
            .frame(width: 72)
            .accessibilityIdentifier(VisualQueryAccessibility.orderByDirectionField)
        }
    }

    private var limitFields: some View {
        TextField(
            "rows",
            text: Binding(
                get: { limitText },
                set: { onSetLimitText($0) }
            )
        )
        .textFieldStyle(.roundedBorder)
        .frame(width: 100)
        .accessibilityIdentifier(VisualQueryAccessibility.limitField)
    }

    private var limitText: String {
        switch document.limitInput {
        case .empty:
            return ""
        case .value(let value):
            return String(value)
        case .invalid(let raw):
            return raw
        }
    }

    private var whereOperators: [VisualWhereOperator] {
        [.equals, .notEquals, .greaterThan, .lessThan, .contains, .isEmpty]
    }

    private func schemaColumnField(
        text: Binding<String>,
        placeholder: String,
        fieldAccessibilityID: String,
        pickerAccessibilityID: String
    ) -> some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(fieldAccessibilityID)

            Button {
                popoverMode = .columns
                showSchemaPopover = true
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .help("Choose a column")
            .accessibilityIdentifier(pickerAccessibilityID)
        }
    }

    @ViewBuilder
    private var schemaPopoverContent: some View {
        switch popoverMode {
        case .tables:
            SchemaFieldPopover(
                title: "Tables",
                items: tableNames,
                needsFromMessage: nil
            ) { name in
                onSetFromTable(name)
                showSchemaPopover = false
            }
        case .columns:
            let needsFrom = document.fromTable == nil
            SchemaFieldPopover(
                title: "Columns",
                items: needsFrom ? [] : columnNames,
                needsFromMessage: needsFrom ? VisualQueryCopy.columnPopoverNeedsFromMessage : nil
            ) { name in
                applyColumnSelection(name)
                showSchemaPopover = false
            }
        }
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

/// Root card for CREATE / UPDATE / DELETE (non-SELECT statement kinds).
struct VisualStatementRootCardView: View {
    let kind: VisualStatementKind
    let document: VisualQueryDocument
    let onStartOver: () -> Void
    let onSetCreateTableName: (String) -> Void
    let onSetCreateColumns: ([VisualCreateColumn]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(VisualQueryCopy.statementTitle(for: kind))
                            .font(.system(size: 13, weight: .semibold))
                            .monospaced()
                        if kind == .update || kind == .delete {
                            Text("Coming soon")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text(VisualQueryCopy.statementHelper(for: kind))
                        .font(.system(size: Constants.FontSize.small))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(action: onStartOver) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(VisualQueryCopy.startOverTitle)
                .accessibilityIdentifier(VisualQueryAccessibility.deleteStatementRoot(kind))
            }

            if kind == .createTable {
                createFields
            }
        }
        .padding(Constants.Spacing.small)
        .frame(minWidth: 260, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var createFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "Table name",
                text: Binding(
                    get: { document.createTableName },
                    set: { onSetCreateTableName($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier(VisualQueryAccessibility.createTableNameField)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(document.createColumns.enumerated()), id: \.offset) { index, column in
                    HStack(spacing: 6) {
                        TextField(
                            "Column name",
                            text: Binding(
                                get: { column.name },
                                set: { newName in
                                    var next = document.createColumns
                                    next[index].name = newName
                                    onSetCreateColumns(next)
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier(VisualQueryAccessibility.createColumnNameField(index))

                        Picker(
                            "Type",
                            selection: Binding(
                                get: { column.type },
                                set: { newType in
                                    var next = document.createColumns
                                    next[index].type = newType
                                    onSetCreateColumns(next)
                                }
                            )
                        ) {
                            ForEach(createTypes, id: \.self) { type in
                                Text(VisualQueryCopy.createColumnTypeTitle(type)).tag(type)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                        .accessibilityIdentifier(VisualQueryAccessibility.createColumnTypePicker(index))

                        Button {
                            var next = document.createColumns
                            next.remove(at: index)
                            onSetCreateColumns(next)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(document.createColumns.count <= 1)
                        .accessibilityIdentifier(VisualQueryAccessibility.removeCreateColumn(index))
                    }
                }
            }
            .accessibilityIdentifier(VisualQueryAccessibility.createColumnsList)

            Button("Add column") {
                var next = document.createColumns
                if next.isEmpty {
                    next = [VisualCreateColumn(name: "", type: .text)]
                } else {
                    next.append(VisualCreateColumn(name: "", type: .text))
                }
                onSetCreateColumns(next)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(VisualQueryAccessibility.addCreateColumn)
        }
        .onAppear {
            if document.createColumns.isEmpty {
                onSetCreateColumns([VisualCreateColumn(name: "", type: .text)])
            }
        }
    }

    private var createTypes: [VisualCreateColumnType] {
        [.text, .number, .date, .boolean]
    }
}

extension VisualQueryAccessibility {
    static let selectColumnsPicker = "visualQuery.selectColumnsPicker"
    static let fromTablePicker = "visualQuery.fromTablePicker"
    static let whereColumnPicker = "visualQuery.whereColumnPicker"
    static let orderByColumnPicker = "visualQuery.orderByColumnPicker"
    static let addCreateColumn = "visualQuery.addCreateColumn"

    static func createColumnNameField(_ index: Int) -> String {
        "visualQuery.createColumn.\(index).name"
    }

    static func createColumnTypePicker(_ index: Int) -> String {
        "visualQuery.createColumn.\(index).type"
    }

    static func removeCreateColumn(_ index: Int) -> String {
        "visualQuery.createColumn.\(index).remove"
    }
}
