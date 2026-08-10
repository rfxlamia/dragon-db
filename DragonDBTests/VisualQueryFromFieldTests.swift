// DragonDBTests/VisualQueryFromFieldTests.swift
import Foundation
import Testing
@testable import DragonDB

@Suite("VisualQueryDocument FROM field")
struct VisualQueryFromFieldTests {

    // Clearing the FROM text field must mean "no table chosen", the state the
    // column popover reads to show "Choose a table in FROM first."
    @Test func clearingFromTextRestoresNoTableState() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.from) == true)
        document.setFromTable(name: "users", schema: "public")
        document.setSelectColumns(["email"])
        #expect(document.fromTable != nil)

        // User selects the field contents and deletes them.
        document.setFromTable("")

        // The column popover decides its helper with exactly this check
        // (VisualClauseCardView.swift:89).
        #expect(document.fromTable == nil)
        // Emptying the field is still an unfinished edit, not a committed change.
        #expect(document.selectProjection == .columns(["email"]))
    }

    @Test func retypingTheSameTableAfterClearingKeepsUserPicks() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.from) == true)
        document.setFromTable(name: "users", schema: "public")
        document.setSelectColumns(["email"])

        document.setFromTable("")
        document.commitFromTable("public.users")

        #expect(document.fromTable == VisualTableReference(schema: "public", name: "users"))
        #expect(document.selectProjection == .columns(["email"]))
    }

    @Test func committingADifferentTableAfterTypingItResetsPicks() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.from) == true)
        document.setFromTable(name: "users", schema: "public")
        document.setSelectColumns(["email"])

        // Typing reaches the document one character at a time, then Return commits.
        document.setFromTable("public.order")
        document.setFromTable("public.orders")
        document.commitFromTable("public.orders")

        #expect(document.selectProjection == .allColumns)
    }

    // Run validation and the column popover must agree about a cleared FROM.
    @Test func clearedFromBlocksRunAndPopoverAgree() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.from) == true)
        document.setFromTable(name: "users", schema: "public")
        document.setFromTable("")

        let eligibility = VisualQueryValidation.canRun(document: document, isConnected: true)
        #expect(eligibility.isRunnable == false)
        // Run already reports "no FROM"; the popover only does so when fromTable is nil.
        #expect(document.fromTable == nil)
    }

    // A half-finished edit of the table name must not discard the user's picks.
    // TextField writes the binding per keystroke, so every intermediate string
    // reaches setFromTable before the user is done typing.
    @Test func unfinishedFromEditKeepsUserPicks() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.from) == true)
        #expect(document.addClause(.where) == true)
        #expect(document.addClause(.orderBy) == true)

        document.setFromTable(name: "users", schema: "public")
        document.setSelectColumns(["email"])
        document.setWhereCondition(column: "name", op: .equals, value: "Budi")
        document.setOrderBy(column: "created_at", direction: .desc)

        // User clicks into the FROM field and presses backspace once.
        document.setFromTable("public.user")

        #expect(document.selectProjection == .columns(["email"]))
        #expect(document.whereCondition?.column == "name")
        #expect(document.orderBy?.column == "created_at")
    }

    // Re-applying the identical table name is already a no-op. Documents the
    // mechanism behind the failure above: only a *differing* string resets.
    @Test func editingFromWithoutChangingTableKeepsProjection() {
        var document = VisualQueryDocument()
        #expect(document.chooseStatement(.select) == true)
        #expect(document.addClause(.from) == true)
        document.setFromTable(name: "users", schema: "public")
        document.setSelectColumns(["email"])

        document.setFromTable("public.users")

        #expect(document.selectProjection == .columns(["email"]))
    }
}
