//
//  QueryExecutionSource.swift
//  DragonDB
//
//  Distinguishes text-editor vs visual-builder query execution so results,
// history, and saved-query association can share one pathway safely.
//

import Foundation

enum QueryExecutionSource: Equatable, Sendable {
    case textEditor
    case visualBuilder
}

enum QueryEditorMode: String, CaseIterable, Identifiable, Sendable {
    case visual = "Visual"
    case sql = "SQL"

    var id: String { rawValue }
}
