//
//  VisualSQLGenerator.swift
//  DragonDB
//
//  Pure Postgres SQL generation from visual query documents.
//

import Foundation

enum VisualSQLGenerator {
    static func generateSQL(document: VisualQueryDocument) -> String? {
        switch document.statementKind {
        case .none, .update, .delete:
            return nil
        case .createTable:
            return generateCreateTable(document)
        case .select:
            return generateSelect(document)
        }
    }

    // MARK: - SELECT

    private static func generateSelect(_ document: VisualQueryDocument) -> String {
        var parts: [String] = []
        parts.append("SELECT \(projectionSQL(document.selectProjection))")

        if document.clauseKinds.contains(.from), let table = document.fromTable {
            parts.append("FROM \(quoteTableReference(table))")
        }

        if document.clauseKinds.contains(.where), let condition = document.whereCondition {
            parts.append("WHERE \(whereSQL(condition))")
        }

        if document.clauseKinds.contains(.orderBy), let orderBy = document.orderBy {
            let direction = orderBy.direction == .desc ? "DESC" : "ASC"
            parts.append("ORDER BY \(quoteIdentifier(orderBy.column)) \(direction)")
        }

        if document.clauseKinds.contains(.limit) {
            if case .value(let limit) = document.limitInput, limit >= 1 {
                parts.append("LIMIT \(limit)")
            }
        }

        return parts.joined(separator: " ")
    }

    private static func projectionSQL(_ projection: VisualSelectProjection) -> String {
        switch projection {
        case .allColumns:
            return "*"
        case .columns(let columns):
            let named = columns.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if named.isEmpty {
                return "*"
            }
            return named.map(quoteIdentifier).joined(separator: ", ")
        }
    }

    private static func whereSQL(_ condition: VisualWhereCondition) -> String {
        let column = quoteIdentifier(condition.column)
        switch condition.op {
        case .equals:
            return "\(column) = \(quoteLiteral(condition.value ?? ""))"
        case .notEquals:
            return "\(column) <> \(quoteLiteral(condition.value ?? ""))"
        case .greaterThan:
            return "\(column) > \(quoteLiteral(condition.value ?? ""))"
        case .lessThan:
            return "\(column) < \(quoteLiteral(condition.value ?? ""))"
        case .contains:
            let pattern = escapeLikePattern(condition.value ?? "")
            return "\(column) LIKE \(quoteLiteral("%\(pattern)%")) ESCAPE '\\'"
        case .isEmpty:
            return "\(column) IS NULL"
        }
    }

    // MARK: - CREATE TABLE

    private static func generateCreateTable(_ document: VisualQueryDocument) -> String {
        let tableName = quoteIdentifier(document.createTableName)
        let columns = document.createColumns.map { column in
            "\(quoteIdentifier(column.name)) \(sqlType(for: column.type))"
        }.joined(separator: ", ")
        return "CREATE TABLE \(tableName) (\(columns))"
    }

    private static func sqlType(for type: VisualCreateColumnType) -> String {
        switch type {
        case .text: return "TEXT"
        case .number: return "NUMERIC"
        case .date: return "DATE"
        case .boolean: return "BOOLEAN"
        }
    }

    // MARK: - Quoting & escaping

    private static func quoteTableReference(_ table: VisualTableReference) -> String {
        if let schema = table.schema, !schema.isEmpty {
            return "\(quoteIdentifier(schema)).\(quoteIdentifier(table.name))"
        }
        return quoteIdentifier(table.name)
    }

    /// Quote a Postgres identifier, doubling embedded double quotes.
    private static func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// Quote a Postgres string literal, doubling embedded single quotes.
    private static func quoteLiteral(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }

    /// Escape LIKE metacharacters (`\`, `%`, `_`) so user input is literal.
    private static func escapeLikePattern(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
