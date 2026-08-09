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

    private let tableRefreshService: TableRefreshServiceProtocol = TableRefreshService()
    private let tableMetadataService: TableMetadataServiceProtocol = TableMetadataService()

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

    private var tableDisplayNames: [String] {
        appState.connection.tables.map(\.displayName)
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
                    tableNames: tableDisplayNames,
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
        let refreshService = tableRefreshService
        visualViewModel = VisualQueryViewModel(
            document: tab.visualQueryDocument,
            onDocumentChange: { tab.visualQueryDocument = $0 },
            isConnected: { appState.connection.isConnected },
            databaseName: { appState.connection.selectedDatabase?.name ?? "" },
            executeSQL: { sql in
                await editor?.executeQuery(sql: sql, source: .visualBuilder)
            },
            onTablesRefresh: {
                guard let database = appState.connection.selectedDatabase,
                      let connection = appState.connection.currentConnection else {
                    return
                }
                await refreshService.loadTables(
                    for: database,
                    connection: connection,
                    appState: appState
                )
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

        // Prefer matching a known sidebar table so schema/id align with the cache key.
        let matchedTable = appState.connection.tables.first { table in
            table.name == fromTable.name
                && (fromTable.schema == nil || fromTable.schema == table.schema)
        }

        let tableInfo: TableInfo
        if let matchedTable {
            tableInfo = matchedTable
        } else {
            tableInfo = TableInfo(
                name: fromTable.name,
                schema: fromTable.schema ?? "public"
            )
        }

        if let cached = appState.connection.getColumnInfo(for: tableInfo) {
            visualColumnNames = cached.map(\.name)
            visualViewModel?.clearMetadataError()
            return
        }

        let result = await tableMetadataService.fetchAndCacheColumns(
            for: tableInfo,
            connectionState: appState.connection,
            databaseService: appState.connection.databaseService
        )

        switch result {
        case .success(let columns):
            visualColumnNames = columns.map(\.name)
            visualViewModel?.clearMetadataError()
        case .failure:
            visualColumnNames = []
            visualViewModel?.reportMetadataFailure(
                "Could not load columns. You can still type a name."
            )
        }
    }
}
