// DragonDBTests/VisualQueryCanvasPresentationTests.swift
import Foundation
import Testing
@testable import DragonDB

@Suite("VisualQueryCanvasPresentation")
struct VisualQueryCanvasPresentationTests {
    @Test func progressiveVisibleCardsFollowDocumentExactly() {
        var document = VisualQueryDocument()
        #expect(VisualQueryCanvasPresentation(document: document).visibleClauseKinds.isEmpty)
        _ = document.chooseStatement(.select)
        var presentation = VisualQueryCanvasPresentation(document: document)
        #expect(presentation.visibleClauseKinds == [.select])
        #expect(presentation.trailingOptions == [.from, .where, .orderBy, .limit])
        _ = document.addClause(.from)
        presentation = VisualQueryCanvasPresentation(document: document)
        #expect(presentation.visibleClauseKinds == [.select, .from])
        #expect(!presentation.visibleClauseKinds.contains(.where))
    }

    @Test func deleteAndStartOverPresentationReturnsExpectedOptions() {
        var document = VisualQueryDocument()
        _ = document.chooseStatement(.select)
        _ = document.addClause(.from)
        _ = document.addClause(.where)
        document.removeClause(.where)
        #expect(VisualQueryCanvasPresentation(document: document).trailingOptions.contains(.where))
        document.startOver()
        let empty = VisualQueryCanvasPresentation(document: document)
        #expect(empty.showsInitialAddButton)
        #expect(empty.visibleClauseKinds.isEmpty)
    }

    @Test func accessibilityIdentifiersAreStableAndUnique() {
        let identifiers = VisualQueryAccessibility.allInteractiveIdentifiers
        #expect(Set(identifiers).count == identifiers.count)
        #expect(identifiers.contains(VisualQueryAccessibility.modeToggle))
        #expect(identifiers.contains(VisualQueryAccessibility.initialAddBlock))
        #expect(identifiers.contains(VisualQueryAccessibility.runQuery))
        #expect(identifiers.contains(VisualQueryAccessibility.generatedSQLText))
    }

    @Test func repeatedInteractiveControlIdentifiersAreStableAndUnique() {
        let fixedIdentifiers = [
            VisualQueryAccessibility.selectColumnsPicker,
            VisualQueryAccessibility.fromTablePicker,
            VisualQueryAccessibility.whereColumnPicker,
            VisualQueryAccessibility.orderByColumnPicker,
            VisualQueryAccessibility.addCreateColumn,
            VisualQueryAccessibility.generatedSQLDone,
        ]
        #expect(Set(fixedIdentifiers).count == fixedIdentifiers.count)

        let firstCreateRow = [
            VisualQueryAccessibility.createColumnNameField(0),
            VisualQueryAccessibility.createColumnTypePicker(0),
            VisualQueryAccessibility.removeCreateColumn(0),
        ]
        let secondCreateRow = [
            VisualQueryAccessibility.createColumnNameField(1),
            VisualQueryAccessibility.createColumnTypePicker(1),
            VisualQueryAccessibility.removeCreateColumn(1),
        ]
        #expect(Set(firstCreateRow + secondCreateRow).count == 6)

        let tableItem = VisualQueryAccessibility.schemaPopoverItem(title: "Tables", item: "users")
        let columnItem = VisualQueryAccessibility.schemaPopoverItem(title: "Columns", item: "users")
        #expect(tableItem != columnItem)
        #expect(columnItem == VisualQueryAccessibility.schemaPopoverItem(title: "Columns", item: "users"))
    }
}
