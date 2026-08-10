// DragonDBTests/VisualQueryDocumentTests.swift
import Foundation
import Testing
@testable import DragonDB

@Suite("VisualQueryDocument")
struct VisualQueryDocumentTests {

    @Test func selectThenFromAddsOnlyThoseClausesInOrder() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.clauseKinds == [.select])
        #expect(document.addClause(.from) == true)
        #expect(document.clauseKinds == [.select, .from])
        // Progressive add: SELECT alone must not invent FROM/WHERE/ORDER BY/LIMIT
        #expect(!document.clauseKinds.contains(.where))
        #expect(!document.clauseKinds.contains(.orderBy))
        #expect(!document.clauseKinds.contains(.limit))
    }

    @Test func selectAloneDoesNotMaterializeFullChain() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.clauseKinds == [.select])
        #expect(document.availableNextClauses() == [.from, .where, .orderBy, .limit])
    }

    @Test func duplicateWhereIsRejected() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.from) == true)
        #expect(document.addClause(.where) == true)
        #expect(document.addClause(.where) == false)
        #expect(document.clauseKinds.filter { $0 == .where }.count == 1)
    }

    @Test func startOverClearsDocument() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.from) == true)
        document.startOver()
        #expect(document.statementKind == nil)
        #expect(document.clauseKinds.isEmpty)
    }

    @Test func committingADifferentFromTableResetsProjectionAndDependentColumns() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.from) == true)
        document.commitFromTable("orders")
        document.setSelectColumns(["status", "amount"])
        #expect(document.selectProjection == .columns(["status", "amount"]))
        #expect(document.addClause(.where) == true)
        document.setWhereCondition(column: "status", op: .equals, value: "paid")
        #expect(document.addClause(.orderBy) == true)
        document.setOrderBy(column: "amount", direction: .desc)

        document.commitFromTable("customers")

        #expect(document.selectProjection == .allColumns)
        #expect(document.whereCondition?.column.isEmpty == true)
        #expect(document.orderBy?.column.isEmpty == true)
        #expect(document.fromTable == VisualTableReference(schema: nil, name: "customers"))
    }

    @Test func pickingADifferentTableFromThePopoverResetsProjection() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.from) == true)
        document.setFromTable(name: "orders", schema: "public")
        document.setSelectColumns(["status"])

        document.setFromTable(name: "customers", schema: "public")

        #expect(document.selectProjection == .allColumns)
        #expect(document.fromTable == VisualTableReference(schema: "public", name: "customers"))
    }

    @Test func joinClauseIsRejected() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.join) == false)
        #expect(!document.clauseKinds.contains(.join))
        #expect(!document.availableNextClauses().contains(.join))
    }

    @Test func removingFromClearsProjectionAndDependentColumnReferences() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        _ = document.addClause(.from)
        document.setFromTable(name: "orders", schema: "sales")
        document.setSelectColumns(["status"])
        _ = document.addClause(.where)
        document.setWhereCondition(column: "status", op: .equals, value: "paid")
        _ = document.addClause(.orderBy)
        document.setOrderBy(column: "status", direction: .asc)

        document.removeClause(.from)

        #expect(document.fromTable == nil)
        #expect(document.selectProjection == .allColumns)
        #expect(document.whereCondition?.column.isEmpty == true)
        #expect(document.orderBy?.column.isEmpty == true)
    }

    @Test func limitInputDistinguishesEmptyMalformedAndValidValues() {
        var document = VisualQueryDocument()
        document.setLimitText("")
        #expect(document.limitInput == .empty)
        document.setLimitText("abc")
        #expect(document.limitInput == .invalid("abc"))
        document.setLimitText("25")
        #expect(document.limitInput == .value(25))
    }

    @Test func pickerTableReferencePreservesSchema() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        _ = document.addClause(.from)
        document.setFromTable(name: "events", schema: "audit")
        #expect(document.fromTable == VisualTableReference(schema: "audit", name: "events"))

        document.setFromTable("reporting.monthly_events")
        #expect(document.fromTable == VisualTableReference(schema: "reporting", name: "monthly_events"))
        document.setFromTable("custom_table")
        #expect(document.fromTable == VisualTableReference(schema: nil, name: "custom_table"))
    }
}
