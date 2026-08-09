//
//  QueryEditorView.swift
//  DragonDB
//
//  Container for query editor. Owns ViewModel and passes data to QueryEditorComponent.
//  Hosts per-tab VisualQueryViewModel when Visual mode is selected.
//

import SwiftUI
import SwiftData

struct QueryEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(TabManager.self) private var tabManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: QueryEditorViewModel?
    @State private var isShowingHistory = false
    @State private var editorMode: QueryEditorMode = .sql
    @State private var visualViewModel: VisualQueryViewModel?
    @State private var visualTabId: UUID?
    @State private var visualColumnNames: [String] = []

    private let tableRefresher = VisualQueryTableRefresher(service: TableRefreshService())
    private let metadataLoader = VisualQueryMetadataLoader(service: TableMetadataService())

    /// Check if the current query (for this saved query) is executing
    private var isCurrentQueryExecuting: Bool {
        if let currentSavedQueryId = appState.query.currentSavedQueryId {
            if appState.query.executingSavedQueryId == currentSavedQueryId {
                return true
            }
            if appState.query.executingSavedQueryId == nil {
                return appState.query.isExecutingQuery && !appState.query.isExecutingTableQuery
            }
            return false
        }

        // Ad-hoc (unsaved) editor query execution should still show progress.
        return appState.query.isExecutingQuery && !appState.query.isExecutingTableQuery
    }

    private var visualTableReferences: [VisualTableReference] {
        appState.connection.tables.map {
            VisualTableReference(schema: $0.schema, name: $0.name)
        }
    }

    var body: some View {
        QueryEditorComponent(
            isExecuting: isCurrentQueryExecuting,
            statusMessage: appState.query.statusMessage,
            lastExecutedAt: appState.query.lastExecutedAt,
            displayedElapsedTime: appState.query.displayedElapsedTime,
            queryText: Binding(
                get: { appState.query.queryText },
                set: { appState.query.queryText = $0 }
            ),
            editorMode: $editorMode,
            onRunQuery: {
                Task {
                    await viewModel?.executeQuery()
                }
            },
            onCancelQuery: {
                tabManager.activeTab?.cancelQuery()
                appState.query.cancelCurrentQuery()
            },
            onShowHistory: {
                isShowingHistory = true
            }
        ) {
            if let visualViewModel {
                VisualQueryCanvasView(
                    viewModel: visualViewModel,
                    tables: visualTableReferences,
                    columnNames: visualColumnNames
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = QueryEditorViewModel(
                    appState: appState,
                    tabManager: tabManager,
                    modelContext: modelContext
                )
            }
            restoreVisualViewModelIfNeeded()
        }
        .onChange(of: tabManager.activeTab?.id) { _, _ in
            restoreVisualViewModelIfNeeded()
            visualColumnNames = []
            Task {
                await loadColumnsForCurrentFromTable()
            }
        }
        .onChange(of: visualFromTableIdentity) { _, _ in
            Task {
                await loadColumnsForCurrentFromTable()
            }
        }
        .onChange(of: appState.query.queryText) { _, newText in
            viewModel?.handleQueryTextChange(newText)
            visualViewModel?.noteExternalQueryTextChanged(newText)
        }
        .alert("No Database Selected", isPresented: Binding(
            get: { viewModel?.showNoDatabaseAlert ?? false },
            set: { viewModel?.showNoDatabaseAlert = $0 }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Select a database from the sidebar before running queries.")
        }
        .alert("Failed to Save Query", isPresented: Binding(
            get: { viewModel?.showSaveErrorAlert ?? false },
            set: { viewModel?.showSaveErrorAlert = $0 }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel?.saveErrorMessage ?? "")
        }
        .alert("Query Timed Out", isPresented: Binding(
            get: { appState.query.showTimeoutAlert },
            set: { appState.query.showTimeoutAlert = $0 }
        )) {
            Button("Try Again") {
                appState.query.showTimeoutAlert = false
                appState.query.queryError = nil
                Task {
                    await viewModel?.executeQuery()
                }
            }
            Button("Cancel", role: .cancel) {
                appState.query.showTimeoutAlert = false
            }
        } message: {
            Text("The query took longer than \(Int(Constants.Timeout.databaseOperation)) seconds. The database may be slow or unresponsive.")
        }
        .sheet(isPresented: $isShowingHistory) {
            QueryHistoryView()
        }
    }

    /// Stable identity for FROM table changes (schema + name) to drive column loading.
    private var visualFromTableIdentity: String {
        guard let table = visualViewModel?.document.fromTable else { return "" }
        if let schema = table.schema {
            return "\(schema).\(table.name)"
        }
        return table.name
    }

    // MARK: - Per-tab visual VM

    private func restoreVisualViewModelIfNeeded() {
        guard let tab = tabManager.activeTab else {
            visualViewModel = nil
            visualTabId = nil
            return
        }

        // Reuse the VM when staying on the same tab (mode toggle within a tab).
        if visualTabId == tab.id, visualViewModel != nil {
            return
        }

        let editor = viewModel
        let refresher = tableRefresher
        visualViewModel = VisualQueryViewModel(
            document: tab.visualQueryDocument,
            onDocumentChange: { tab.visualQueryDocument = $0 },
            isConnected: { appState.connection.isConnected },
            databaseName: { appState.connection.selectedDatabase?.name ?? "" },
            tableRefreshContext: {
                refresher.captureContext(from: appState.connection)
            },
            executeSQL: { sql in
                await editor?.executeQuery(sql: sql, source: .visualBuilder)
            },
            onTablesRefresh: { context in
                await refresher.refreshTables(ifCurrent: context, appState: appState)
            }
        )
        visualTabId = tab.id
    }

    private func loadColumnsForCurrentFromTable() async {
        guard let fromTable = visualViewModel?.document.fromTable,
              !fromTable.name.isEmpty else {
            visualColumnNames = []
            visualViewModel?.clearMetadataError()
            return
        }

        let result = await metadataLoader.loadColumns(
            for: fromTable,
            availableTables: appState.connection.tables,
            connectionState: appState.connection,
            databaseService: appState.connection.databaseService
        )

        guard visualViewModel?.document.fromTable == fromTable else { return }
        visualColumnNames = result.columnNames
        if let visualViewModel {
            result.apply(to: visualViewModel)
        }
    }
}

@MainActor
struct VisualQueryTableRefresher {
    let service: TableRefreshServiceProtocol

    func captureContext(from connectionState: ConnectionState) -> VisualQueryTableRefreshContext? {
        guard let database = connectionState.selectedDatabase,
              let connection = connectionState.currentConnection else {
            return nil
        }
        return VisualQueryTableRefreshContext(
            databaseID: database.id,
            connectionID: connection.id
        )
    }

    func refreshTables(
        ifCurrent context: VisualQueryTableRefreshContext,
        appState: AppState
    ) async {
        guard let database = appState.connection.selectedDatabase,
              let connection = appState.connection.currentConnection,
              database.id == context.databaseID,
              connection.id == context.connectionID else {
            return
        }
        await service.loadTables(
            for: database,
            connection: connection,
            appState: appState
        )
    }
}

struct VisualQueryMetadataLoadResult {
    let columnNames: [String]
    let errorMessage: String?

    @MainActor
    func apply(to viewModel: VisualQueryViewModel) {
        if let errorMessage {
            viewModel.reportMetadataFailure(errorMessage)
        } else {
            viewModel.clearMetadataError()
        }
    }
}

@MainActor
struct VisualQueryMetadataLoader {
    let service: TableMetadataServiceProtocol

    func loadColumns(
        for reference: VisualTableReference,
        availableTables: [TableInfo],
        connectionState: ConnectionState,
        databaseService: DatabaseServiceProtocol
    ) async -> VisualQueryMetadataLoadResult {
        let table = availableTables.first { candidate in
            candidate.name == reference.name
                && (reference.schema == nil || candidate.schema == reference.schema)
        } ?? TableInfo(name: reference.name, schema: reference.schema ?? "public")

        let result = await service.fetchAndCacheColumns(
            for: table,
            connectionState: connectionState,
            databaseService: databaseService
        )

        switch result {
        case .success(let columns):
            return VisualQueryMetadataLoadResult(
                columnNames: columns.map(\.name),
                errorMessage: nil
            )
        case .failure:
            return VisualQueryMetadataLoadResult(
                columnNames: [],
                errorMessage: "Could not load columns. You can still type a name."
            )
        }
    }
}
