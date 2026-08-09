//
//  VisualQueryValidationTests.swift
//  DragonDBTests
//

import Foundation
import Testing
@testable import DragonDB

@Suite("VisualQueryValidation")
struct VisualQueryValidationTests {

    private func selectWithoutFrom() -> VisualQueryDocument {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        return document
    }

    private func validSelect(from table: String = "orders") -> VisualQueryDocument {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        _ = document.addClause(.from)
        document.setFromTable(table)
        return document
    }

    @Test func selectWithoutFromIsNotRunnable() {
        let eligibility = VisualQueryValidation.canRun(document: selectWithoutFrom(), isConnected: true)
        #expect(eligibility.isRunnable == false)
        #expect(eligibility.helpMessage?.isEmpty == false)
    }

    @Test func disconnectedIsNotRunnable() {
        let eligibility = VisualQueryValidation.canRun(document: validSelect(), isConnected: false)
        #expect(eligibility.isRunnable == false)
        #expect(eligibility.helpMessage?.localizedCaseInsensitiveContains("connect") == true)
    }

    @Test func whitespaceWhereValueIsNotRunnable() {
        var document = validSelect()
        _ = document.addClause(.where)
        document.setWhereCondition(column: "status", op: .equals, value: "   ")
        let eligibility = VisualQueryValidation.canRun(document: document, isConnected: true)
        #expect(eligibility.isRunnable == false)
    }

    @Test func limitZeroIsNotRunnable() {
        var document = validSelect()
        _ = document.addClause(.limit)
        document.setLimitText("0")
        let eligibility = VisualQueryValidation.canRun(document: document, isConnected: true)
        #expect(eligibility.isRunnable == false)
    }

    @Test func limitEmptyIsValidButMalformedAndNegativeAreNot() {
        var document = validSelect()
        _ = document.addClause(.limit)

        document.setLimitText("")
        #expect(VisualQueryValidation.canRun(document: document, isConnected: true).isRunnable)
        document.setLimitText("abc")
        #expect(!VisualQueryValidation.canRun(document: document, isConnected: true).isRunnable)
        document.setLimitText("-1")
        #expect(!VisualQueryValidation.canRun(document: document, isConnected: true).isRunnable)
        document.setLimitText("1")
        #expect(VisualQueryValidation.canRun(document: document, isConnected: true).isRunnable)
    }

    @Test func updateAndDeleteAreNotRunnable() {
        for kind in [VisualStatementKind.update, .delete] {
            var document = VisualQueryDocument()
            _ = document.chooseStatement(kind)
            let eligibility = VisualQueryValidation.canRun(document: document, isConnected: true)
            #expect(eligibility.isRunnable == false)
        }
    }

    @Test func validCreateTableIsRunnable() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.createTable)
        document.setCreateTableName("notes")
        document.setCreateColumns([
            VisualCreateColumn(name: "body", type: .text),
            VisualCreateColumn(name: "created_at", type: .date)
        ])
        let eligibility = VisualQueryValidation.canRun(document: document, isConnected: true)
        #expect(eligibility.isRunnable == true)
    }
}
