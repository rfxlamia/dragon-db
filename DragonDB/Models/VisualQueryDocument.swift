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

    /// Last FROM table the user actually committed (picked from the popover or
    /// submitted in the field). `fromTable` tracks every keystroke so the preview
    /// and Run gates stay honest; only a committed change resets column picks.
    private var committedFromTable: VisualTableReference?

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
            committedFromTable = nil
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
        committedFromTable = nil
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

    /// Typed input. Tracks the field character by character without discarding
    /// the user's column picks — an unfinished edit is not a table change.
    mutating func setFromTable(_ rawName: String) {
        fromTable = Self.parseTableReference(rawName)
    }

    /// Submitted input (Return in the FROM field). A change of table since the
    /// last commit resets the projection and dependent column references.
    mutating func commitFromTable(_ rawName: String) {
        fromTable = Self.parseTableReference(rawName)
        commitCurrentFromTable()
    }

    /// Popover selection. Choosing a table is itself a commit.
    mutating func setFromTable(name: String, schema: String?) {
        fromTable = VisualTableReference(schema: schema, name: name)
        commitCurrentFromTable()
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

    /// Parses `schema.table` when both halves are present; otherwise treats the
    /// whole string as a bare table name. An empty field means no table at all,
    /// which is what the column popover and the Run gates both check.
    private static func parseTableReference(_ rawName: String) -> VisualTableReference? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let dot = trimmed.firstIndex(of: ".") {
            let schema = String(trimmed[..<dot])
            let name = String(trimmed[trimmed.index(after: dot)...])
            if !schema.isEmpty, !name.isEmpty, !name.contains(".") {
                return VisualTableReference(schema: schema, name: name)
            }
        }
        return VisualTableReference(schema: nil, name: trimmed)
    }

    private mutating func commitCurrentFromTable() {
        if committedFromTable != fromTable {
            resetProjectionAndDependentColumns()
        }
        committedFromTable = fromTable
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
