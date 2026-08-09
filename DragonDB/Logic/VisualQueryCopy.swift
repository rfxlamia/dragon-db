//
//  VisualQueryCopy.swift
//  DragonDB
//
//  English helpers and chrome copy for the visual query canvas.
//

import Foundation

enum VisualQueryCopy {
    struct StatementMenuItem: Equatable, Sendable {
        let kind: VisualStatementKind
        let title: String
        let helper: String
        let isRunnable: Bool
        let badge: String?
    }

    struct GeneratedSQLPreviewModel: Equatable, Sendable {
        let sql: String
        let isEditable: Bool
        let allowsCopy: Bool
    }

    struct ClauseMenuItem: Equatable, Sendable {
        let kind: VisualClauseKind
        let title: String
        let helper: String
    }

    static func helper(forClause kind: VisualClauseKind) -> String {
        switch kind {
        case .select:
            return "Choose which columns to return"
        case .from:
            return "Which table should we read from?"
        case .where:
            return "Keep only rows that match a condition"
        case .orderBy:
            return "Sort the rows"
        case .limit:
            return "Cap how many rows come back"
        case .join:
            return "Join tables (coming soon)"
        }
    }

    static func statementHelper(for kind: VisualStatementKind) -> String {
        switch kind {
        case .select:
            return "Read rows from a table"
        case .createTable:
            return "Create a new table in this database."
        case .update:
            return "Change existing rows — not runnable in v1"
        case .delete:
            return "Remove rows — not runnable in v1"
        }
    }

    static func statementTitle(for kind: VisualStatementKind) -> String {
        switch kind {
        case .select:
            return "SELECT"
        case .createTable:
            return "CREATE TABLE"
        case .update:
            return "UPDATE"
        case .delete:
            return "DELETE"
        }
    }

    static func clauseTitle(for kind: VisualClauseKind) -> String {
        switch kind {
        case .select:
            return "SELECT"
        case .from:
            return "FROM"
        case .where:
            return "WHERE"
        case .orderBy:
            return "ORDER BY"
        case .limit:
            return "LIMIT"
        case .join:
            return "JOIN"
        }
    }

    static func statementMenuItems() -> [StatementMenuItem] {
        [
            StatementMenuItem(
                kind: .select,
                title: statementTitle(for: .select),
                helper: statementHelper(for: .select),
                isRunnable: true,
                badge: nil
            ),
            StatementMenuItem(
                kind: .createTable,
                title: "CREATE",
                helper: "Create a new table",
                isRunnable: true,
                badge: nil
            ),
            StatementMenuItem(
                kind: .update,
                title: statementTitle(for: .update),
                helper: statementHelper(for: .update),
                isRunnable: false,
                badge: "Coming soon"
            ),
            StatementMenuItem(
                kind: .delete,
                title: statementTitle(for: .delete),
                helper: statementHelper(for: .delete),
                isRunnable: false,
                badge: "Coming soon"
            ),
        ]
    }

    static func nextClauseOptions(for document: VisualQueryDocument) -> [VisualClauseKind] {
        document.availableNextClauses()
    }

    static func clauseMenuItems(for document: VisualQueryDocument) -> [ClauseMenuItem] {
        nextClauseOptions(for: document).map { kind in
            ClauseMenuItem(kind: kind, title: clauseTitle(for: kind), helper: helper(forClause: kind))
        }
    }

    static var startOverTitle: String { "Start over" }
    static var deleteClauseTitle: String { "Delete" }
    static var columnPopoverNeedsFromMessage: String { "Choose a table in FROM first." }
    static var viewGeneratedSQLTitle: String { "View generated SQL" }
    static var copySQLTitle: String { "Copy" }
    static var allColumnsTitle: String { "All columns" }
    static var addBlockTitle: String { "Add block" }
    static var runQueryTitle: String { "Run query" }
    static var confirmCreateTitle: String { "Create this table?" }
    static var confirmCreateContinueTitle: String { "Continue" }
    static var confirmCreateCancelTitle: String { "Cancel" }

    static func whereOperatorTitle(_ op: VisualWhereOperator) -> String {
        switch op {
        case .equals: return "equals"
        case .notEquals: return "does not equal"
        case .greaterThan: return "greater than"
        case .lessThan: return "less than"
        case .contains: return "contains"
        case .isEmpty: return "is empty"
        }
    }

    static func orderDirectionTitle(_ direction: VisualOrderDirection) -> String {
        switch direction {
        case .asc: return "ASC"
        case .desc: return "DESC"
        }
    }

    static func createColumnTypeTitle(_ type: VisualCreateColumnType) -> String {
        switch type {
        case .text: return "text"
        case .number: return "number"
        case .date: return "date"
        case .boolean: return "true/false"
        }
    }

    static func generatedSQLPreviewModel(sql: String) -> GeneratedSQLPreviewModel {
        GeneratedSQLPreviewModel(sql: sql, isEditable: false, allowsCopy: true)
    }
}
