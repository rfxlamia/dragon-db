//
//  VisualQueryViewModel.swift
//  DragonDB
//
//  Orchestrates a per-tab VisualQueryDocument for the visual query builder UI.
//  Does not sync with queryText; execution wiring arrives in a later task.
//

import Foundation

@Observable
@MainActor
final class VisualQueryViewModel {
    private(set) var document: VisualQueryDocument
    private(set) var isRunning = false
    private(set) var showCreateConfirmation = false

    private let onDocumentChange: ((VisualQueryDocument) -> Void)?
    private let isConnected: () -> Bool

    init(
        document: VisualQueryDocument = VisualQueryDocument(),
        onDocumentChange: ((VisualQueryDocument) -> Void)? = nil,
        isConnected: @escaping () -> Bool = { false }
    ) {
        self.document = document
        self.onDocumentChange = onDocumentChange
        self.isConnected = isConnected
    }

    // MARK: - Derived state

    var generatedSQL: String {
        VisualSQLGenerator.generateSQL(document: document) ?? ""
    }

    var runEnabled: Bool {
        VisualQueryValidation.canRun(document: document, isConnected: isConnected()).isRunnable
    }

    var runHelpMessage: String? {
        VisualQueryValidation.canRun(document: document, isConnected: isConnected()).helpMessage
    }

    // MARK: - Document mutators

    @discardableResult
    func chooseStatement(_ kind: VisualStatementKind) -> Bool {
        mutateReturning { $0.chooseStatement(kind) }
    }

    @discardableResult
    func addClause(_ kind: VisualClauseKind) -> Bool {
        mutateReturning { $0.addClause(kind) }
    }

    func removeClause(_ kind: VisualClauseKind) {
        mutateAndPublish { $0.removeClause(kind) }
    }

    func startOver() {
        mutateAndPublish { $0.startOver() }
    }

    func availableNextClauses() -> [VisualClauseKind] {
        document.availableNextClauses()
    }

    func setFromTable(_ rawName: String) {
        mutateAndPublish { $0.setFromTable(rawName) }
    }

    func setFromTable(name: String, schema: String?) {
        mutateAndPublish { $0.setFromTable(name: name, schema: schema) }
    }

    func setSelectColumns(_ columns: [String]) {
        mutateAndPublish { $0.setSelectColumns(columns) }
    }

    func setWhereCondition(column: String, op: VisualWhereOperator, value: String?) {
        mutateAndPublish { $0.setWhereCondition(column: column, op: op, value: value) }
    }

    func setOrderBy(column: String, direction: VisualOrderDirection) {
        mutateAndPublish { $0.setOrderBy(column: column, direction: direction) }
    }

    func setLimitText(_ text: String) {
        mutateAndPublish { $0.setLimitText(text) }
    }

    func setCreateTableName(_ name: String) {
        mutateAndPublish { $0.setCreateTableName(name) }
    }

    func setCreateColumns(_ columns: [VisualCreateColumn]) {
        mutateAndPublish { $0.setCreateColumns(columns) }
    }

    // MARK: - Run single-flight

    @discardableResult
    func beginRun() -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        return true
    }

    func endRun() {
        isRunning = false
    }

    // MARK: - CREATE confirmation presentation

    @discardableResult
    func requestCreateConfirmation() -> Bool {
        guard document.statementKind == .createTable else { return false }
        guard runEnabled else { return false }
        showCreateConfirmation = true
        return true
    }

    func cancelCreateConfirmation() {
        showCreateConfirmation = false
    }

    // MARK: - External text editor (no sync)

    /// Observes text-editor buffer changes without mutating the visual document.
    func noteExternalQueryTextChanged(_ text: String) {
        // Intentionally no-op: blocks and queryText stay independent.
        _ = text
    }

    // MARK: - Private

    @discardableResult
    private func mutateReturning(_ body: (inout VisualQueryDocument) -> Bool) -> Bool {
        var working = document
        let success = body(&working)
        guard success else { return false }
        document = working
        onDocumentChange?(document)
        return true
    }

    private func mutateAndPublish(_ body: (inout VisualQueryDocument) -> Void) {
        var working = document
        body(&working)
        document = working
        onDocumentChange?(document)
    }
}
