//
//  VisualStatementRootCardView.swift
//  DragonDB
//
//  Root card for CREATE / UPDATE / DELETE statement kinds.
//

import SwiftUI

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
