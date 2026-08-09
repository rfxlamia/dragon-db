//
//  VisualQueryAccessibility.swift
//  DragonDB
//
//  Stable accessibility identifiers for visual query interactive controls.
//

import Foundation

enum VisualQueryAccessibility {
    static let modeToggle = "visualQuery.modeToggle"
    static let initialAddBlock = "visualQuery.initialAddBlock"
    static let trailingAddBlock = "visualQuery.trailingAddBlock"
    static let statementMenu = "visualQuery.statementMenu"
    static let clauseMenu = "visualQuery.clauseMenu"
    static let startOver = "visualQuery.startOver"
    static let runQuery = "visualQuery.runQuery"
    static let viewGeneratedSQL = "visualQuery.viewGeneratedSQL"
    static let generatedSQLText = "visualQuery.generatedSQLText"
    static let copySQL = "visualQuery.copySQL"
    static let allColumnsToggle = "visualQuery.allColumnsToggle"
    static let selectColumnsField = "visualQuery.selectColumnsField"
    static let fromTableField = "visualQuery.fromTableField"
    static let whereColumnField = "visualQuery.whereColumnField"
    static let whereOperatorField = "visualQuery.whereOperatorField"
    static let whereValueField = "visualQuery.whereValueField"
    static let orderByColumnField = "visualQuery.orderByColumnField"
    static let orderByDirectionField = "visualQuery.orderByDirectionField"
    static let limitField = "visualQuery.limitField"
    static let createTableNameField = "visualQuery.createTableNameField"
    static let createColumnsList = "visualQuery.createColumnsList"
    static let schemaPopoverSearch = "visualQuery.schemaPopoverSearch"
    static let schemaPopoverList = "visualQuery.schemaPopoverList"
    static let confirmCreateContinue = "visualQuery.confirmCreateContinue"
    static let confirmCreateCancel = "visualQuery.confirmCreateCancel"

    static func clauseCard(_ kind: VisualClauseKind) -> String {
        "visualQuery.clauseCard.\(clauseKey(kind))"
    }

    static func deleteClause(_ kind: VisualClauseKind) -> String {
        "visualQuery.deleteClause.\(clauseKey(kind))"
    }

    static func statementMenuItem(_ kind: VisualStatementKind) -> String {
        "visualQuery.statementMenu.\(statementKey(kind))"
    }

    static func clauseMenuItem(_ kind: VisualClauseKind) -> String {
        "visualQuery.clauseMenu.\(clauseKey(kind))"
    }

    static func deleteStatementRoot(_ kind: VisualStatementKind) -> String {
        "visualQuery.deleteRoot.\(statementKey(kind))"
    }

    /// Every interactive identifier used by the canvas — must stay unique.
    static var allInteractiveIdentifiers: [String] {
        var ids: [String] = [
            modeToggle,
            initialAddBlock,
            trailingAddBlock,
            statementMenu,
            clauseMenu,
            startOver,
            runQuery,
            viewGeneratedSQL,
            generatedSQLText,
            copySQL,
            allColumnsToggle,
            selectColumnsField,
            fromTableField,
            whereColumnField,
            whereOperatorField,
            whereValueField,
            orderByColumnField,
            orderByDirectionField,
            limitField,
            createTableNameField,
            createColumnsList,
            schemaPopoverSearch,
            schemaPopoverList,
            confirmCreateContinue,
            confirmCreateCancel,
        ]

        let clauseKinds: [VisualClauseKind] = [.select, .from, .where, .orderBy, .limit, .join]
        for kind in clauseKinds {
            ids.append(clauseCard(kind))
            ids.append(deleteClause(kind))
            ids.append(clauseMenuItem(kind))
        }

        let statementKinds: [VisualStatementKind] = [.select, .createTable, .update, .delete]
        for kind in statementKinds {
            ids.append(statementMenuItem(kind))
            ids.append(deleteStatementRoot(kind))
        }

        return ids
    }

    private static func clauseKey(_ kind: VisualClauseKind) -> String {
        switch kind {
        case .select: return "select"
        case .from: return "from"
        case .where: return "where"
        case .orderBy: return "orderBy"
        case .limit: return "limit"
        case .join: return "join"
        }
    }

    private static func statementKey(_ kind: VisualStatementKind) -> String {
        switch kind {
        case .select: return "select"
        case .createTable: return "createTable"
        case .update: return "update"
        case .delete: return "delete"
        }
    }
}
