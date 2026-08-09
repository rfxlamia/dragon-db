//
//  VisualQueryValidation.swift
//  DragonDB
//
//  Pure run-eligibility checks for visual query documents.
//

import Foundation

struct VisualRunEligibility: Equatable, Sendable {
    let isRunnable: Bool
    let helpMessage: String?

    static func runnable() -> VisualRunEligibility {
        VisualRunEligibility(isRunnable: true, helpMessage: nil)
    }

    static func blocked(_ message: String) -> VisualRunEligibility {
        VisualRunEligibility(isRunnable: false, helpMessage: message)
    }
}

enum VisualQueryValidation {
    static func canRun(document: VisualQueryDocument, isConnected: Bool) -> VisualRunEligibility {
        guard isConnected else {
            return .blocked("Connect a database first")
        }

        switch document.statementKind {
        case .none:
            return .blocked("Add a statement to start building a query")
        case .update, .delete:
            return .blocked("Coming soon")
        case .createTable:
            return validateCreate(document)
        case .select:
            return validateSelect(document)
        }
    }

    // MARK: - SELECT

    private static func validateSelect(_ document: VisualQueryDocument) -> VisualRunEligibility {
        guard document.clauseKinds.contains(.from),
              let table = document.fromTable,
              !table.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .blocked("Choose a table in FROM")
        }

        if let schema = table.schema,
           schema.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .blocked("Choose a table in FROM")
        }

        switch document.selectProjection {
        case .allColumns:
            break
        case .columns(let columns):
            let named = columns.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if named.isEmpty {
                return .blocked("Choose at least one column, or use All columns")
            }
        }

        if document.clauseKinds.contains(.where) {
            guard let whereCondition = document.whereCondition else {
                return .blocked("Choose a column for the WHERE condition")
            }
            if whereCondition.column.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .blocked("Choose a column for the WHERE condition")
            }
            if whereCondition.op != .isEmpty {
                let value = whereCondition.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if value.isEmpty {
                    return .blocked("Enter a value for the WHERE condition")
                }
            }
        }

        if document.clauseKinds.contains(.orderBy) {
            guard let orderBy = document.orderBy,
                  !orderBy.column.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .blocked("Choose a column to sort by")
            }
        }

        if document.clauseKinds.contains(.limit) {
            switch document.limitInput {
            case .empty:
                break
            case .value(let value):
                if value < 1 {
                    return .blocked("Enter a positive whole number for LIMIT")
                }
            case .invalid:
                return .blocked("Enter a positive whole number for LIMIT")
            }
        }

        return .runnable()
    }

    // MARK: - CREATE TABLE

    private static func validateCreate(_ document: VisualQueryDocument) -> VisualRunEligibility {
        if document.createTableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .blocked("Enter a table name")
        }

        let validColumns = document.createColumns.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if validColumns.isEmpty {
            return .blocked("Add at least one column with a name")
        }

        return .runnable()
    }
}
