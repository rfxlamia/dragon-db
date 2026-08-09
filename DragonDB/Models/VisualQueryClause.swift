//
//  VisualQueryClause.swift
//  DragonDB
//
//  Domain types for the visual query builder block document.
//

import Foundation

enum VisualStatementKind: Equatable, Hashable, Sendable {
    case select
    case createTable
    case update
    case delete
}

enum VisualClauseKind: Equatable, Hashable, Sendable {
    case select
    case from
    case `where`
    case orderBy
    case limit
    case join
}

enum VisualSelectProjection: Equatable, Hashable, Sendable {
    case allColumns
    case columns([String])
}

enum VisualWhereOperator: Equatable, Hashable, Sendable {
    case equals
    case notEquals
    case greaterThan
    case lessThan
    case contains
    case isEmpty
}

enum VisualOrderDirection: Equatable, Hashable, Sendable {
    case asc
    case desc
}

enum VisualCreateColumnType: Equatable, Hashable, Sendable {
    case text
    case number
    case date
    case boolean
}

struct VisualCreateColumn: Equatable, Hashable, Sendable {
    var name: String
    var type: VisualCreateColumnType
}

struct VisualTableReference: Equatable, Hashable, Sendable {
    var schema: String?
    var name: String
}

enum VisualLimitInput: Equatable, Hashable, Sendable {
    case empty
    case value(Int)
    case invalid(String)
}

struct VisualWhereCondition: Equatable, Hashable, Sendable {
    var column: String
    var op: VisualWhereOperator
    var value: String?
}

struct VisualOrderBy: Equatable, Hashable, Sendable {
    var column: String
    var direction: VisualOrderDirection
}
