//
//  VisualQueryViewModelTests.swift
//  DragonDBTests
//

import Foundation
import Testing
@testable import DragonDB

@Suite("VisualQueryViewModel")
@MainActor
struct VisualQueryViewModelTests {

    @Test func progressiveAddSelectThenFromDoesNotInventLaterClauses() {
        let vm = VisualQueryViewModel()
        #expect(vm.chooseStatement(.select) == true)
        #expect(vm.document.clauseKinds == [.select])
        #expect(vm.addClause(.from) == true)
        #expect(vm.document.clauseKinds == [.select, .from])
        #expect(!vm.document.clauseKinds.contains(.where))
        #expect(!vm.document.clauseKinds.contains(.orderBy))
        #expect(!vm.document.clauseKinds.contains(.limit))
        vm.setFromTable("orders")
        #expect(vm.generatedSQL.contains("SELECT *"))
        #expect(vm.generatedSQL.contains("FROM \"orders\""))
        #expect(!vm.generatedSQL.localizedCaseInsensitiveContains("WHERE"))
    }

    @Test func runEnabledMirrorsValidationHelp() {
        let vm = VisualQueryViewModel(isConnected: { true })
        _ = vm.chooseStatement(.select)
        #expect(vm.runEnabled == false)
        #expect(vm.runHelpMessage?.isEmpty == false)
        _ = vm.addClause(.from)
        vm.setFromTable("orders")
        #expect(vm.runEnabled == true)
    }

    @Test func beginRunIsSingleFlightUntilEndRun() {
        let vm = VisualQueryViewModel(isConnected: { true })
        _ = vm.chooseStatement(.select)
        _ = vm.addClause(.from)
        vm.setFromTable("orders")
        #expect(vm.beginRun() == true)
        #expect(vm.isRunning == true)
        #expect(vm.beginRun() == false)
        vm.endRun()
        #expect(vm.isRunning == false)
        #expect(vm.beginRun() == true)
        vm.endRun()
    }

    @Test func visualDocumentsAreIsolatedAndRestoredPerTab() {
        let tabA = TabViewModel(isActive: true)
        let tabB = TabViewModel(isActive: false)
        let vmA = VisualQueryViewModel(
            document: tabA.visualQueryDocument,
            onDocumentChange: { tabA.visualQueryDocument = $0 }
        )
        _ = vmA.chooseStatement(.select)
        _ = vmA.addClause(.from)
        vmA.setFromTable("orders")

        let vmB = VisualQueryViewModel(
            document: tabB.visualQueryDocument,
            onDocumentChange: { tabB.visualQueryDocument = $0 }
        )
        _ = vmB.chooseStatement(.createTable)
        vmB.setCreateTableName("notes")

        let restoredA = VisualQueryViewModel(
            document: tabA.visualQueryDocument,
            onDocumentChange: { tabA.visualQueryDocument = $0 }
        )
        #expect(restoredA.document.statementKind == .select)
        #expect(restoredA.document.fromTable?.name == "orders")
        #expect(tabB.visualQueryDocument.statementKind == .createTable)
        #expect(tabB.visualQueryDocument.createTableName == "notes")
    }

    @Test func queryTextChangesDoNotMutateVisualDocument() {
        let vm = VisualQueryViewModel()
        _ = vm.chooseStatement(.select)
        _ = vm.addClause(.from)
        vm.setFromTable("orders")
        let snapshot = vm.document.clauseKinds
        // Visual mode must not auto-sync from text editor buffer
        vm.noteExternalQueryTextChanged("SELECT 1")
        #expect(vm.document.clauseKinds == snapshot)
        #expect(vm.document.fromTable == VisualTableReference(schema: nil, name: "orders"))
    }

    @Test func cancelCreateConfirmationDoesNotExecute() {
        let vm = VisualQueryViewModel(isConnected: { true })
        _ = vm.chooseStatement(.createTable)
        vm.setCreateTableName("notes")
        vm.setCreateColumns([VisualCreateColumn(name: "body", type: .text)])
        #expect(vm.requestCreateConfirmation() == true)
        #expect(vm.showCreateConfirmation == true)
        vm.cancelCreateConfirmation()
        #expect(vm.showCreateConfirmation == false)
        #expect(vm.isRunning == false)
    }
}
