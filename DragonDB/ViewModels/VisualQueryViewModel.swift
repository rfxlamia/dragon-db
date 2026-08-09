//
//  VisualQueryViewModel.swift
//  DragonDB
//
//  Orchestrates a per-tab VisualQueryDocument for the visual query builder UI.
//  Does not sync with queryText. Execution is injected as a closure backed by
//  QueryEditorViewModel.executeQuery(sql:source:) in production.
//

import Foundation

struct VisualQueryTableRefreshContext: Equatable, Sendable {
    let databaseID: String
    let connectionID: UUID
}

@Observable
@MainActor
final class VisualQueryViewModel {
    private(set) var document: VisualQueryDocument
    private(set) var isRunning = false
    private(set) var showCreateConfirmation = false
    private(set) var createConfirmationDatabaseName = ""
    private(set) var metadataErrorMessage: String?
    private(set) var statusMessage: String?
    private(set) var lastQueryResult: QueryResult?

    private let onDocumentChange: ((VisualQueryDocument) -> Void)?
    private let isConnected: () -> Bool
    private let databaseName: () -> String
    private let tableRefreshContext: () -> VisualQueryTableRefreshContext?
    private let executeSQL: ((String) async -> QueryResult?)?
    private let onTablesRefresh: ((VisualQueryTableRefreshContext) async -> Void)?

    init(
        document: VisualQueryDocument = VisualQueryDocument(),
        onDocumentChange: ((VisualQueryDocument) -> Void)? = nil,
        isConnected: @escaping () -> Bool = { false },
        databaseName: @escaping () -> String = { "" },
        tableRefreshContext: @escaping () -> VisualQueryTableRefreshContext? = { nil },
        executeSQL: ((String) async -> QueryResult?)? = nil,
        onTablesRefresh: ((VisualQueryTableRefreshContext) async -> Void)? = nil
    ) {
        self.document = document
        self.onDocumentChange = onDocumentChange
        self.isConnected = isConnected
        self.databaseName = databaseName
        self.tableRefreshContext = tableRefreshContext
        self.executeSQL = executeSQL
        self.onTablesRefresh = onTablesRefresh
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

    var createConfirmationMessage: String {
        let tableName = document.createTableName
        if createConfirmationDatabaseName.isEmpty {
            return "This will create table \"\(tableName)\" in the connected database."
        }
        return "This will create table \"\(tableName)\" in database \"\(createConfirmationDatabaseName)\"."
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
        createConfirmationDatabaseName = ""
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
        createConfirmationDatabaseName = databaseName()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        showCreateConfirmation = true
        return true
    }

    func cancelCreateConfirmation() {
        showCreateConfirmation = false
    }

    // MARK: - Execution

    /// Validates and runs the current visual query. CREATE shows confirmation first.
    func runQuery() async {
        guard runEnabled else { return }

        if document.statementKind == .createTable {
            _ = requestCreateConfirmation()
            return
        }

        await performExecute()
    }

    /// Continues CREATE after user confirmation. Second call while in flight is a no-op.
    func confirmCreateAndExecute() async {
        guard showCreateConfirmation else { return }
        showCreateConfirmation = false
        await performExecute()
    }

    func reportMetadataFailure(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        metadataErrorMessage = trimmed.isEmpty ? nil : trimmed
    }

    func clearMetadataError() {
        metadataErrorMessage = nil
    }

    // MARK: - External text editor (no sync)

    /// Observes text-editor buffer changes without mutating the visual document.
    func noteExternalQueryTextChanged(_ text: String) {
        // Intentionally no-op: blocks and queryText stay independent.
        _ = text
    }

    // MARK: - Private

    private func performExecute() async {
        guard beginRun() else { return }
        defer { endRun() }

        let sql = generatedSQL
        guard !sql.isEmpty else { return }
        guard let executeSQL else { return }

        let executedStatementKind = document.statementKind
        let executedCreateTableName = document.createTableName
        let executedDatabaseName = createConfirmationDatabaseName
        let initiatingRefreshContext = executedStatementKind == .createTable
            ? tableRefreshContext()
            : nil

        let result = await executeSQL(sql)
        lastQueryResult = result

        guard let result else { return }

        if result.isSuccess {
            if executedStatementKind == .createTable {
                if executedDatabaseName.isEmpty {
                    statusMessage = "Created table \(executedCreateTableName)"
                } else {
                    statusMessage = "Created table \(executedCreateTableName) in \(executedDatabaseName)"
                }
                if let initiatingRefreshContext {
                    await onTablesRefresh?(initiatingRefreshContext)
                }
            } else {
                statusMessage = "Executed in \(QueryState.formatExecutionTime(result.executionTime))"
            }
        } else if let error = result.error {
            statusMessage = PostgresError.extractDetailedMessage(error)
        }
    }

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
