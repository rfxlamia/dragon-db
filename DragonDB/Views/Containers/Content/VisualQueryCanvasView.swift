//
//  VisualQueryCanvasView.swift
//  DragonDB
//
//  Linear visual query canvas: empty +, progressive clause cards, trailing + for missing clauses.
//  Durable chain state lives in VisualQueryViewModel/document — not duplicated in local @State.
//

import SwiftUI

struct VisualQueryCanvasView: View {
    @Bindable var viewModel: VisualQueryViewModel

    /// Injectable table references for the FROM popover.
    var tables: [VisualTableReference] = []
    /// Injectable column names for column popovers (empty until FROM set / metadata wired in T5).
    var columnNames: [String] = []

    @State private var showStatementPicker = false
    @State private var showClausePicker = false
    @State private var showGeneratedSQL = false

    private var presentation: VisualQueryCanvasPresentation {
        VisualQueryCanvasPresentation(document: viewModel.document)
    }

    var body: some View {
        VStack(spacing: 0) {
            VisualQueryToolbar(
                runEnabled: viewModel.runEnabled,
                runHelpMessage: viewModel.runHelpMessage,
                isRunning: viewModel.isRunning,
                canStartOver: !presentation.showsInitialAddButton,
                onRun: handleRun,
                onViewGeneratedSQL: { showGeneratedSQL = true },
                onStartOver: { viewModel.startOver() }
            )

            if let metadataError = viewModel.metadataErrorMessage, !metadataError.isEmpty {
                Text(metadataError)
                    .font(.system(size: Constants.FontSize.small))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Constants.Spacing.medium)
                    .padding(.vertical, Constants.Spacing.small)
            }

            Divider()

            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showGeneratedSQL) {
            GeneratedSQLPreviewView(sql: viewModel.generatedSQL) {
                showGeneratedSQL = false
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showCreateConfirmation },
            set: { presented in
                if !presented {
                    viewModel.cancelCreateConfirmation()
                }
            }
        )) {
            createConfirmationSheet
        }
    }

    @ViewBuilder
    private var canvas: some View {
        if presentation.showsInitialAddButton {
            emptyCanvas
        } else {
            chainCanvas
        }
    }

    private var emptyCanvas: some View {
        VStack(spacing: Constants.Spacing.medium) {
            Text("Build a query visually")
                .font(.system(size: 15, weight: .medium))
            Text("Add a block to start. Each + adds one clause — never a full chain at once.")
                .font(.system(size: Constants.FontSize.small))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            addBlockButton(isInitial: true) {
                showStatementPicker = true
            }
            .popover(isPresented: $showStatementPicker, arrowEdge: .bottom) {
                VisualStatementPickerView { kind in
                    _ = viewModel.chooseStatement(kind)
                    showStatementPicker = false
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Constants.Spacing.large)
    }

    private var chainCanvas: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: Constants.Spacing.small) {
                if presentation.showsStatementRootCard, let kind = presentation.statementKind {
                    VisualStatementRootCardView(
                        kind: kind,
                        document: viewModel.document,
                        onStartOver: { viewModel.startOver() },
                        onSetCreateTableName: { viewModel.setCreateTableName($0) },
                        onSetCreateColumns: { viewModel.setCreateColumns($0) }
                    )
                }

                ForEach(presentation.visibleClauseKinds, id: \.self) { kind in
                    VisualClauseCardView(
                        kind: kind,
                        document: viewModel.document,
                        tables: tables,
                        columnNames: columnNames,
                        metadataErrorMessage: viewModel.metadataErrorMessage,
                        onDelete: {
                            if kind == .select {
                                viewModel.startOver()
                            } else {
                                viewModel.removeClause(kind)
                            }
                        },
                        onSetSelectColumns: { viewModel.setSelectColumns($0) },
                        onSetFromTable: { viewModel.setFromTable($0) },
                        onSelectFromTable: { table in
                            Self.selectTable(table, using: viewModel)
                        },
                        onSetWhere: { column, op, value in
                            viewModel.setWhereCondition(column: column, op: op, value: value)
                        },
                        onSetOrderBy: { column, direction in
                            viewModel.setOrderBy(column: column, direction: direction)
                        },
                        onSetLimitText: { viewModel.setLimitText($0) }
                    )

                    if kind != presentation.visibleClauseKinds.last {
                        connector
                    }
                }

                if presentation.showsTrailingAddButton {
                    if !presentation.visibleClauseKinds.isEmpty {
                        connector
                    }
                    trailingAddControl
                }
            }
            .padding(Constants.Spacing.medium)
        }
    }

    private var trailingAddControl: some View {
        addBlockButton(isInitial: false) {
            showClausePicker = true
        }
        .popover(isPresented: $showClausePicker, arrowEdge: .bottom) {
            clausePickerMenu
        }
    }

    private var clausePickerMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(VisualQueryCopy.clauseMenuItems(for: viewModel.document), id: \.kind) { item in
                Button {
                    // Progressive add: at most one clause per + action.
                    _ = viewModel.addClause(item.kind)
                    showClausePicker = false
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .monospaced()
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
                .accessibilityIdentifier(VisualQueryAccessibility.clauseMenuItem(item.kind))
            }
        }
        .padding(4)
        .frame(minWidth: 220)
        .accessibilityIdentifier(VisualQueryAccessibility.clauseMenu)
    }

    private var connector: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.top, 28)
    }

    private func addBlockButton(isInitial: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(Color(nsColor: .separatorColor))
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(VisualQueryCopy.addBlockTitle)
        .accessibilityIdentifier(
            isInitial
                ? VisualQueryAccessibility.initialAddBlock
                : VisualQueryAccessibility.trailingAddBlock
        )
    }

    private var createConfirmationSheet: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            Text(VisualQueryCopy.confirmCreateTitle)
                .font(.headline)
            Text(viewModel.createConfirmationMessage)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(VisualQueryCopy.confirmCreateCancelTitle) {
                    viewModel.cancelCreateConfirmation()
                }
                .accessibilityIdentifier(VisualQueryAccessibility.confirmCreateCancel)
                Button(VisualQueryCopy.confirmCreateContinueTitle) {
                    Task {
                        await viewModel.confirmCreateAndExecute()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(VisualQueryAccessibility.confirmCreateContinue)
            }
        }
        .padding(Constants.Spacing.medium)
        .frame(minWidth: 360)
    }

    private func handleRun() {
        Task {
            await viewModel.runQuery()
        }
    }

    @MainActor
    static func selectTable(_ table: VisualTableReference, using viewModel: VisualQueryViewModel) {
        viewModel.setFromTable(name: table.name, schema: table.schema)
    }
}
