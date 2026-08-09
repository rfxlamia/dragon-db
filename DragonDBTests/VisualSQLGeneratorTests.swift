//
//  VisualSQLGeneratorTests.swift
//  DragonDBTests
//

import Foundation
import Testing
@testable import DragonDB

@Suite("VisualSQLGenerator")
struct VisualSQLGeneratorTests {

    @Test func allColumnsGeneratesSelectStar() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        _ = document.addClause(.from)
        document.setFromTable("orders")
        let sql = VisualSQLGenerator.generateSQL(document: document)
        #expect(sql?.hasPrefix("SELECT *") == true)
        #expect(sql?.contains("FROM \"orders\"") == true)
        // Generator must not invent missing WHERE/ORDER BY/LIMIT
        #expect(sql?.localizedCaseInsensitiveContains("WHERE") != true)
        #expect(sql?.localizedCaseInsensitiveContains("ORDER BY") != true)
        #expect(sql?.localizedCaseInsensitiveContains("LIMIT") != true)
    }

    @Test func containsEscapesLikeMetacharactersAndQuotes() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        _ = document.addClause(.from)
        document.setFromTable("orders")
        _ = document.addClause(.where)
        document.setWhereCondition(column: "name", op: .contains, value: "O'Brien%")
        let sql = VisualSQLGenerator.generateSQL(document: document)
        #expect(sql?.contains("\"name\"") == true)
        #expect(sql?.contains("LIKE") == true)
        #expect(sql?.contains("O''Brien") == true)
        // LIKE metacharacters in user input must be escaped (e.g. \% for literal %)
        #expect(sql?.contains("%") == true)
        #expect(sql?.contains("\\%") == true)
    }

    @Test func isEmptyGeneratesIsNull() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        _ = document.addClause(.from)
        document.setFromTable("orders")
        _ = document.addClause(.where)
        document.setWhereCondition(column: "email", op: .isEmpty, value: nil)
        let sql = VisualSQLGenerator.generateSQL(document: document)
        #expect(sql?.contains("\"email\" IS NULL") == true)
        #expect(sql?.contains("= ''") != true)
    }

    @Test func createTableMapsSimpleTypes() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.createTable)
        document.setCreateTableName("notes")
        document.setCreateColumns([
            VisualCreateColumn(name: "body", type: .text),
            VisualCreateColumn(name: "amount", type: .number),
            VisualCreateColumn(name: "created_at", type: .date),
            VisualCreateColumn(name: "active", type: .boolean)
        ])
        let sql = VisualSQLGenerator.generateSQL(document: document)
        #expect(sql?.contains("CREATE TABLE \"notes\"") == true)
        #expect(sql?.contains("\"body\" TEXT") == true)
        #expect(sql?.contains("\"amount\" NUMERIC") == true)
        #expect(sql?.contains("\"created_at\" DATE") == true)
        #expect(sql?.contains("\"active\" BOOLEAN") == true)
    }

    @Test func updateAndDeleteDoNotGenerateRunnableSQL() {
        for kind in [VisualStatementKind.update, .delete] {
            var document = VisualQueryDocument()
            _ = document.chooseStatement(kind)
            #expect(VisualSQLGenerator.generateSQL(document: document) == nil)
        }
    }

    @Test func schemaAndEmbeddedIdentifierQuotesAreEscapedPerComponent() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        _ = document.addClause(.from)
        document.setFromTable(name: "odd\"table", schema: "audit")
        document.setSelectColumns(["quoted\"column"])
        let sql = VisualSQLGenerator.generateSQL(document: document)
        #expect(sql?.contains("SELECT \"quoted\"\"column\"") == true)
        #expect(sql?.contains("FROM \"audit\".\"odd\"\"table\"") == true)
    }

    @Test func containsEscapesPercentUnderscoreBackslashAndApostrophe() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        _ = document.addClause(.from)
        document.setFromTable("orders")
        _ = document.addClause(.where)
        document.setWhereCondition(column: "name", op: .contains, value: "O'Brien%_\\")
        let sql = VisualSQLGenerator.generateSQL(document: document)
        #expect(sql?.contains("O''Brien") == true)
        #expect(sql?.contains("\\%") == true)
        #expect(sql?.contains("\\_") == true)
        #expect(sql?.contains("ESCAPE") == true)
    }

    @Test func generatorUsesCanonicalSQLOrderRegardlessOfAddOrder() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        _ = document.addClause(.limit)
        document.setLimitText("10")
        _ = document.addClause(.orderBy)
        document.setOrderBy(column: "created_at", direction: .desc)
        _ = document.addClause(.from)
        document.setFromTable("orders")
        let sql = VisualSQLGenerator.generateSQL(document: document) ?? ""
        #expect(sql.range(of: "FROM")!.lowerBound < sql.range(of: "ORDER BY")!.lowerBound)
        #expect(sql.range(of: "ORDER BY")!.lowerBound < sql.range(of: "LIMIT")!.lowerBound)
    }
}
