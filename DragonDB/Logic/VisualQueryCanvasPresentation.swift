//
//  VisualQueryCanvasPresentation.swift
//  DragonDB
//
//  Presentation contract consumed by the SwiftUI visual query canvas.
//  Derives visible cards, trailing + options, and visible execution status.
//

import Foundation

struct VisualQueryCanvasPresentation: Equatable, Sendable {
    let document: VisualQueryDocument
    let statusMessage: String?

    init(document: VisualQueryDocument, statusMessage: String? = nil) {
        self.document = document
        self.statusMessage = statusMessage
    }

    var visibleStatusMessage: String? {
        guard let statusMessage else { return nil }
        let trimmed = statusMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Clause cards currently on the canvas — mirrors document clauseKinds exactly.
    /// Pressing + never invents a full SELECT chain here.
    var visibleClauseKinds: [VisualClauseKind] {
        document.clauseKinds
    }

    /// Trailing + menu options: missing SELECT clauses only (never JOIN).
    var trailingOptions: [VisualClauseKind] {
        VisualQueryCopy.nextClauseOptions(for: document)
    }

    /// Empty canvas shows the initial + until a statement is chosen (or after Start over).
    var showsInitialAddButton: Bool {
        document.statementKind == nil
    }

    /// True when a non-SELECT root (CREATE / UPDATE / DELETE) should render a root card.
    var showsStatementRootCard: Bool {
        switch document.statementKind {
        case .createTable, .update, .delete:
            return true
        case .select, .none:
            return false
        }
    }

    var statementKind: VisualStatementKind? {
        document.statementKind
    }

    var showsTrailingAddButton: Bool {
        document.statementKind == .select && !trailingOptions.isEmpty
    }
}
