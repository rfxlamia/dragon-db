//
//  VisualClauseCardFieldViews.swift
//  DragonDB
//
//  Focused field sections for each supported SELECT clause card.
//

import SwiftUI

extension VisualClauseCardView {
    @ViewBuilder
    var fields: some View {
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
            .onSubmit { onCommitFromTable(fromDisplayName) }
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

    private var selectedColumnsText: String {
        if case .columns(let columns) = document.selectProjection {
            return columns.joined(separator: ", ")
        }
        return ""
    }

    private var fromDisplayName: String {
        guard let table = document.fromTable else { return "" }
        if let schema = table.schema, !schema.isEmpty {
            return "\(schema).\(table.name)"
        }
        return table.name
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

    private func parseSelectColumns(_ text: String) -> [String] {
        text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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
}
