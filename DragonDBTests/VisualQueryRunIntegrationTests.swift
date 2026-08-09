//
//  VisualQueryRunIntegrationTests.swift
//  DragonDBTests
//
//  Integration tests for visual query Run path, shared QueryEditor results,
// metadata cache-miss loading, and CREATE confirm / sidebar refresh.
//

import Foundation
import SwiftData
import Testing
@testable import DragonDB

@MainActor
private final class VisualQueryMockQueryService: QueryServiceProtocol {
    private(set) var executeCallCount = 0
    private(set) var executedSQL: [String] = []
    var result: QueryResult = .success(rows: [], columnNames: [], executionTime: 0.01)

    func executeQuery(_ sql: String, preferredColumnOrder: [String]?) async -> QueryResult {
        executeCallCount += 1
        executedSQL.append(sql)
        return result
    }

    func executeTableQuery(
        for table: TableInfo,
        limit: Int,
        offset: Int,
        preferredColumnOrder: [String]?
    ) async -> QueryResult {
        result
    }

    func cancelCurrentQuery() {}
}

@MainActor
private final class VisualQueryMockDatabaseService: DatabaseServiceProtocol {
    var isConnected: Bool = true
    var connectedDatabase: String? = "analytics"
    private(set) var fetchColumnInfoCallCount = 0
    var columnInfo: [ColumnInfo] = []
    var fetchColumnInfoError: Error?

    func connect(
        host: String,
        port: Int,
        username: String,
        password: String,
        database: String,
        sslMode: SSLMode
    ) async throws {
        isConnected = true
        connectedDatabase = database
    }

    func disconnect() async {
        isConnected = false
        connectedDatabase = nil
    }

    func shutdown() async {
        isConnected = false
        connectedDatabase = nil
    }

    func interruptInFlightTableBrowseLoadForSupersession() async {}

    func fetchDatabases() async throws -> [DatabaseInfo] { [] }
    func createDatabase(name: String) async throws {}
    func deleteDatabase(name: String) async throws {}
    func fetchTables(database: String) async throws -> [TableInfo] { [] }
    func fetchSchemas(database: String) async throws -> [String] { [] }
    func deleteTable(schema: String, table: String) async throws {}
    func truncateTable(schema: String, table: String) async throws {}
    func generateDDL(schema: String, table: String) async throws -> String { "" }
    func fetchAllTableData(schema: String, table: String) async throws -> ([TableRow], [String]) {
        ([], [])
    }

    func executeQuery(_ sql: String) async throws -> ([TableRow], [String]) { ([], []) }
    func executeDisplayQuery(_ sql: String) async throws -> ([TableRow], [String]) { ([], []) }
    func deleteRows(
        schema: String,
        table: String,
        primaryKeyColumns: [String],
        rows: [TableRow]
    ) async throws {}
    func updateRow(
        schema: String,
        table: String,
        primaryKeyColumns: [String],
        originalRow: TableRow,
        updatedValues: [String: RowEditValue]
    ) async throws {}
    func fetchPrimaryKeyColumns(schema: String, table: String) async throws -> [String] { [] }

    func fetchColumnInfo(schema: String, table: String) async throws -> [ColumnInfo] {
        fetchColumnInfoCallCount += 1
        if let fetchColumnInfoError {
            throw fetchColumnInfoError
        }
        return columnInfo
    }
}

private actor RefreshCallProbe {
    private(set) var count = 0
    func increment() { count += 1 }
}

/// Harness that wires VisualQueryViewModel through the real QueryEditorViewModel pathway.
@MainActor
private final class VisualQueryEditorHarness {
    let appState: AppState
    let tabManager: TabManager
    let tab: TabViewModel
    let service: VisualQueryMockQueryService
    let editorViewModel: QueryEditorViewModel
    let modelContext: ModelContext
    /// Must retain the container for the lifetime of `modelContext` or SwiftData traps on insert.
    private let container: ModelContainer

    static func make(result: QueryResult) throws -> VisualQueryEditorHarness {
        let container = try DragonDBModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let service = VisualQueryMockQueryService()
        service.result = result

        let connectionState = ConnectionState(databaseService: DelayedMockDatabaseService())
        connectionState.currentConnection = ConnectionProfile(
            name: "Local",
            host: "localhost",
            username: "postgres",
            database: "analytics"
        )
        connectionState.selectedDatabase = DatabaseInfo(name: "analytics")

        let appState = AppState(connection: connectionState, query: QueryState())
        let tab = TabViewModel(isActive: true)
        let tabManager = TabManager()
        tabManager.activeTab = tab
        tabManager.tabs = [tab]

        let editorViewModel = QueryEditorViewModel(
            appState: appState,
            tabManager: tabManager,
            modelContext: context,
            queryService: service
        )

        return VisualQueryEditorHarness(
            appState: appState,
            tabManager: tabManager,
            tab: tab,
            service: service,
            editorViewModel: editorViewModel,
            modelContext: context,
            container: container
        )
    }

    private init(
        appState: AppState,
        tabManager: TabManager,
        tab: TabViewModel,
        service: VisualQueryMockQueryService,
        editorViewModel: QueryEditorViewModel,
        modelContext: ModelContext,
        container: ModelContainer
    ) {
        self.appState = appState
        self.tabManager = tabManager
        self.tab = tab
        self.service = service
        self.editorViewModel = editorViewModel
        self.modelContext = modelContext
        self.container = container
    }

    func makeVisualViewModel() -> VisualQueryViewModel {
        let editor = editorViewModel
        return VisualQueryViewModel(
            document: tab.visualQueryDocument,
            onDocumentChange: { [tab] in tab.visualQueryDocument = $0 },
            isConnected: { true },
            databaseName: { "analytics" },
            executeSQL: { sql in
                await editor.executeQuery(sql: sql, source: .visualBuilder)
            }
        )
    }

    func historySQL() throws -> String? {
        let entries = try modelContext.fetch(FetchDescriptor<QueryHistory>())
        return entries.first?.queryText
    }
}

/// Harness for TableMetadataService.fetchAndCacheColumns cache hit/miss without sidebar selection.
@MainActor
private final class VisualQueryMetadataHarness {
    let table: TableInfo
    let connectionState: ConnectionState
    let databaseService: VisualQueryMockDatabaseService
    private let metadataService = TableMetadataService()

    init(table: TableInfo) {
        self.table = table
        let databaseService = VisualQueryMockDatabaseService()
        databaseService.columnInfo = [
            ColumnInfo(name: "id", dataType: "integer"),
            ColumnInfo(name: "payload", dataType: "jsonb"),
        ]
        self.databaseService = databaseService
        self.connectionState = ConnectionState(databaseService: databaseService)
        connectionState.currentConnection = ConnectionProfile(
            name: "Local",
            host: "localhost",
            username: "postgres",
            database: "analytics"
        )
        connectionState.selectedDatabase = DatabaseInfo(name: "analytics")
        // Intentionally leave selectedTable nil — picker must not mutate sidebar selection.
    }

    func loadColumns() async -> [ColumnInfo]? {
        let result = await metadataService.fetchAndCacheColumns(
            for: table,
            connectionState: connectionState,
            databaseService: databaseService
        )
        switch result {
        case .success(let columns):
            return columns
        case .failure:
            return nil
        }
    }
}

@Suite("VisualQueryRunIntegration")
@MainActor
struct VisualQueryRunIntegrationTests {

    private func makeVM(
        connected: Bool,
        service: VisualQueryMockQueryService,
        databaseName: String = "analytics",
        onTablesRefresh: (@Sendable () async -> Void)? = nil
    ) -> VisualQueryViewModel {
        VisualQueryViewModel(
            isConnected: { connected },
            databaseName: { databaseName },
            executeSQL: { sql in
                await service.executeQuery(sql, preferredColumnOrder: nil)
            },
            onTablesRefresh: onTablesRefresh
        )
    }

    @Test func disconnectedRunDoesNotCallQueryService() async {
        let service = VisualQueryMockQueryService()
        let vm = makeVM(connected: false, service: service)
        _ = vm.chooseStatement(.select)
        _ = vm.addClause(.from)
        vm.setFromTable("orders")
        #expect(vm.runEnabled == false)
        await vm.runQuery()
        #expect(service.executeCallCount == 0)
        #expect(vm.runHelpMessage?.localizedCaseInsensitiveContains("connect") == true)
    }

    @Test func createConfirmCancelDoesNotExecute() async {
        let service = VisualQueryMockQueryService()
        let vm = makeVM(connected: true, service: service)
        _ = vm.chooseStatement(.createTable)
        vm.setCreateTableName("notes")
        vm.setCreateColumns([VisualCreateColumn(name: "body", type: .text)])
        await vm.runQuery()
        #expect(vm.showCreateConfirmation == true)
        #expect(service.executeCallCount == 0)
        vm.cancelCreateConfirmation()
        #expect(vm.showCreateConfirmation == false)
        #expect(service.executeCallCount == 0)
    }

    @Test func createSuccessInvokesRefreshAndKeepsBlocks() async {
        let service = VisualQueryMockQueryService()
        service.result = .success(rows: [], columnNames: [], executionTime: 0.02)
        let refreshProbe = RefreshCallProbe()
        let vm = makeVM(connected: true, service: service) {
            await refreshProbe.increment()
        }
        _ = vm.chooseStatement(.createTable)
        vm.setCreateTableName("notes")
        vm.setCreateColumns([
            VisualCreateColumn(name: "body", type: .text),
            VisualCreateColumn(name: "created_at", type: .date),
        ])
        await vm.runQuery()
        #expect(vm.showCreateConfirmation == true)
        await vm.confirmCreateAndExecute()
        #expect(service.executeCallCount == 1)
        #expect(service.executedSQL.first?.contains("CREATE TABLE \"notes\"") == true)
        #expect(await refreshProbe.count == 1)
        #expect(vm.document.statementKind == .createTable)
        #expect(vm.document.createTableName == "notes")
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("notes") == true)
    }

    @Test func metadataFailureAllowsManualFromAndDoesNotBlockRun() async {
        let service = VisualQueryMockQueryService()
        service.result = .success(
            rows: [TableRow(values: ["id": "1"])],
            columnNames: ["id"],
            executionTime: 0.01
        )
        let vm = makeVM(connected: true, service: service)
        _ = vm.chooseStatement(.select)
        _ = vm.addClause(.from)
        vm.reportMetadataFailure("Could not load tables. You can still type a name.")
        #expect(vm.metadataErrorMessage?.isEmpty == false)
        vm.setFromTable("custom_table")
        #expect(vm.runEnabled == true)
        await vm.runQuery()
        #expect(service.executeCallCount == 1)
        #expect(service.executedSQL.first?.contains("\"custom_table\"") == true)
    }

    @Test func selectSuccessUpdatesLocalStatusAfterSharedExecutorReturns() async {
        let service = VisualQueryMockQueryService()
        service.result = .success(
            rows: [TableRow(values: ["status": "paid"])],
            columnNames: ["status"],
            executionTime: 0.05
        )
        let vm = makeVM(connected: true, service: service)
        _ = vm.chooseStatement(.select)
        _ = vm.addClause(.from)
        vm.setFromTable("orders")
        await vm.runQuery()
        #expect(service.executeCallCount == 1)
        #expect(vm.lastQueryResult?.isSuccess == true)
        #expect(vm.statusMessage?.isEmpty == false)
    }

    @Test func sharedEditorExecutionPublishesVisualResultsToQueryStateAndActiveTab() async throws {
        let harness = try VisualQueryEditorHarness.make(
            result: .success(
                rows: [TableRow(values: ["status": "paid"])],
                columnNames: ["status"],
                executionTime: 0.05
            )
        )
        let vm = harness.makeVisualViewModel()
        _ = vm.chooseStatement(.select)
        _ = vm.addClause(.from)
        vm.setFromTable(name: "orders", schema: "sales")

        await vm.runQuery()

        #expect(harness.appState.query.showQueryResults)
        #expect(harness.appState.query.queryResults.count == 1)
        #expect(harness.appState.query.queryColumnNames == ["status"])
        #expect(harness.tab.cachedResults?.count == 1)
        #expect(harness.tab.cachedColumnNames == ["status"])
        #expect(harness.service.executedSQL.first?.contains("\"sales\".\"orders\"") == true)
        #expect(try harness.historySQL() == harness.service.executedSQL.first)
    }

    @Test func metadataCacheMissFetchesAndCachesColumnsWithoutSelectingSidebarTable() async {
        let harness = VisualQueryMetadataHarness(table: TableInfo(name: "events", schema: "audit"))
        #expect(harness.connectionState.selectedTable == nil)

        let columns = await harness.loadColumns()

        #expect(columns?.map(\.name) == ["id", "payload"])
        #expect(harness.databaseService.fetchColumnInfoCallCount == 1)
        #expect(harness.connectionState.getColumnInfo(for: harness.table)?.map(\.name) == ["id", "payload"])
        #expect(harness.connectionState.selectedTable == nil)
        _ = await harness.loadColumns()
        #expect(harness.databaseService.fetchColumnInfoCallCount == 1)
    }

    @Test func concurrentCreateConfirmationExecutesOnlyOnce() async {
        let service = VisualQueryMockQueryService()
        let vm = makeVM(connected: true, service: service)
        _ = vm.chooseStatement(.createTable)
        vm.setCreateTableName("notes")
        vm.setCreateColumns([VisualCreateColumn(name: "body", type: .text)])
        await vm.runQuery()

        async let first: Void = vm.confirmCreateAndExecute()
        async let second: Void = vm.confirmCreateAndExecute()
        _ = await (first, second)

        #expect(service.executeCallCount == 1)
    }

    @Test func updateComingSoonNeverCallsExecute() async {
        let service = VisualQueryMockQueryService()
        let vm = makeVM(connected: true, service: service)
        _ = vm.chooseStatement(.update)
        #expect(vm.runEnabled == false)
        await vm.runQuery()
        #expect(service.executeCallCount == 0)
    }
}
