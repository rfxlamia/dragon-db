// DragonDBTests/VisualQueryClauseCopyTests.swift
import Foundation
import Testing
@testable import DragonDB

@Suite("VisualQueryCopy")
struct VisualQueryClauseCopyTests {

    @Test func clauseHelpersMatchSpecExamples() {
        #expect(VisualQueryCopy.helper(forClause: .select).localizedCaseInsensitiveContains("column") == true)
        #expect(VisualQueryCopy.helper(forClause: .from).localizedCaseInsensitiveContains("table") == true)
        #expect(VisualQueryCopy.helper(forClause: .where).localizedCaseInsensitiveContains("condition") == true)
        #expect(VisualQueryCopy.helper(forClause: .orderBy).localizedCaseInsensitiveContains("sort") == true)
        #expect(VisualQueryCopy.helper(forClause: .limit).localizedCaseInsensitiveContains("row") == true)
    }

    @Test func statementMenuMarksUpdateAndDeleteComingSoon() {
        let items = VisualQueryCopy.statementMenuItems()
        let select = items.first { $0.kind == .select }
        let create = items.first { $0.kind == .createTable }
        let update = items.first { $0.kind == .update }
        let delete = items.first { $0.kind == .delete }
        #expect(select?.isRunnable == true)
        #expect(create?.isRunnable == true)
        #expect(update?.isRunnable == false)
        #expect(delete?.isRunnable == false)
        #expect(update?.badge?.localizedCaseInsensitiveContains("coming soon") == true)
        #expect(delete?.badge?.localizedCaseInsensitiveContains("coming soon") == true)
    }

    @Test func lifecycleChromeCopyExists() {
        #expect(VisualQueryCopy.startOverTitle.isEmpty == false)
        #expect(VisualQueryCopy.deleteClauseTitle.isEmpty == false)
        #expect(VisualQueryCopy.columnPopoverNeedsFromMessage.localizedCaseInsensitiveContains("from") == true)
        #expect(VisualQueryCopy.viewGeneratedSQLTitle.isEmpty == false)
        #expect(VisualQueryCopy.copySQLTitle.isEmpty == false)
    }

    @Test func trailingPlusOptionsAreProgressiveAndExcludeJoin() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        // After SELECT only: offer missing clauses one-at-a-time; never JOIN
        let afterSelect = VisualQueryCopy.nextClauseOptions(for: document)
        #expect(afterSelect == [.from, .where, .orderBy, .limit])
        #expect(!afterSelect.contains(.join))

        _ = document.addClause(.from)
        let afterFrom = VisualQueryCopy.nextClauseOptions(for: document)
        #expect(afterFrom == [.where, .orderBy, .limit])
        #expect(!afterFrom.contains(.from))
        #expect(!afterFrom.contains(.join))
    }

    @Test func generatedSQLPreviewIsReadOnlyCopyModel() {
        let preview = VisualQueryCopy.generatedSQLPreviewModel(sql: "SELECT * FROM \"orders\"")
        #expect(preview.isEditable == false)
        #expect(preview.allowsCopy == true)
        #expect(preview.sql == "SELECT * FROM \"orders\"")
    }
}
