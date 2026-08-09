//
//  VisualQueryDocument.swift
//  DragonDB
//
//  In-memory visual query document with progressive-add clause mutations.
//

import Foundation

struct VisualQueryDocument: Equatable, Sendable {
    private(set) var statementKind: VisualStatementKind?
    private(set) var clauseKinds: [VisualClauseKind] = []

    private(set) var selectProjection: VisualSelectProjection = .allColumns
    private(set) var fromTable: VisualTableReference?
    private(set) var whereCondition: VisualWhereCondition?
    private(set) var orderBy: VisualOrderBy?
    private(set) var limitInput: VisualLimitInput = .empty
    private(set) var createTableName: String = ""
    private(set) var createColumns: [VisualCreateColumn] = []

    private static let selectClauseOptions: [VisualClauseKind] = [.from, .where, .orderBy, .limit]

    // MARK: - Statement & clause lifecycle

    @discardableResult
    mutating func chooseStatement(_ kind: VisualStatementKind) -> Bool {
        guard statementKind == nil else { return false }
        statementKind = kind
        switch kind {
        case .select:
            clauseKinds = [.select]
            selectProjection = .allColumns
        case .createTable, .update, .delete:
            clauseKinds = []
        }
        return true
    }

    @discardableResult
    mutating func addClause(_ kind: VisualClauseKind) -> Bool {
        guard statementKind == .select else { return false }
        guard kind != .join else { return false }
        guard kind != .select else { return false }
        guard !clauseKinds.contains(kind) else { return false }
        guard Self.selectClauseOptions.contains(kind) else { return false }

        clauseKinds.append(kind)
        switch kind {
        case .where:
            if whereCondition == nil {
                whereCondition = VisualWhereCondition(column: "", op: .equals, value: nil)
            }
        case .orderBy:
            if orderBy == nil {
                orderBy = VisualOrderBy(column: "", direction: .asc)
            }
        case .select, .from, .limit, .join:
            break
        }
        return true
    }

    mutating func removeClause(_ kind: VisualClauseKind) {
        guard let index = clauseKinds.firstIndex(of: kind) else { return }
        clauseKinds.remove(at: index)

        switch kind {
        case .select:
            startOver()
        case .from:
            fromTable = nil
            resetProjectionAndDependentColumns()
        case .where:
            whereCondition = nil
        case .orderBy:
            orderBy = nil
        case .limit:
            limitInput = .empty
        case .join:
            break
        }
    }

    mutating func startOver() {
        statementKind = nil
        clauseKinds = []
        selectProjection = .allColumns
        fromTable = nil
        whereCondition = nil
        orderBy = nil
        limitInput = .empty
        createTableName = ""
        createColumns = []
    }

    func availableNextClauses() -> [VisualClauseKind] {
        guard statementKind == .select else { return [] }
        return Self.selectClauseOptions.filter { !clauseKinds.contains($0) }
    }

    // MARK: - Field mutators

    mutating func setFromTable(_ rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dot = trimmed.firstIndex(of: ".") {
            let schema = String(trimmed[..<dot])
            let name = String(trimmed[trimmed.index(after: dot)...])
            if !schema.isEmpty, !name.isEmpty, !name.contains(".") {
                applyFromTable(VisualTableReference(schema: schema, name: name))
                return
            }
        }
        applyFromTable(VisualTableReference(schema: nil, name: trimmed))
    }

    mutating func setFromTable(name: String, schema: String?) {
        applyFromTable(VisualTableReference(schema: schema, name: name))
    }

    mutating func setSelectColumns(_ columns: [String]) {
        if columns.isEmpty {
            selectProjection = .allColumns
        } else {
            selectProjection = .columns(columns)
        }
    }

    mutating func setWhereCondition(column: String, op: VisualWhereOperator, value: String?) {
        whereCondition = VisualWhereCondition(column: column, op: op, value: value)
    }

    mutating func setOrderBy(column: String, direction: VisualOrderDirection) {
        orderBy = VisualOrderBy(column: column, direction: direction)
    }

    mutating func setLimitText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            limitInput = .empty
            return
        }
        if let value = Int(trimmed) {
            limitInput = .value(value)
        } else {
            limitInput = .invalid(trimmed)
        }
    }

    mutating func setCreateTableName(_ name: String) {
        createTableName = name
    }

    mutating func setCreateColumns(_ columns: [VisualCreateColumn]) {
        createColumns = columns
    }

    // MARK: - Private helpers

    private mutating func applyFromTable(_ table: VisualTableReference) {
        let previous = fromTable
        fromTable = table
        if previous != table {
            resetProjectionAndDependentColumns()
        }
    }

    private mutating func resetProjectionAndDependentColumns() {
        selectProjection = .allColumns
        if whereCondition != nil {
            whereCondition?.column = ""
        }
        if orderBy != nil {
            orderBy?.column = ""
        }
    }
}
