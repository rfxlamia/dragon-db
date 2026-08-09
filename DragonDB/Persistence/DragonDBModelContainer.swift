//
//  DragonDBModelContainer.swift
//  DragonDB
//
//  Centralizes SwiftData schema setup and migration.
//

import Foundation
import SwiftData

enum DragonDBSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            ConnectionProfile.self,
            SavedQuery.self,
            QueryFolder.self,
            TabState.self,
        ]
    }
}

enum DragonDBSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [
            ConnectionProfile.self,
            SavedQuery.self,
            QueryFolder.self,
            TabState.self,
            QueryHistory.self,
        ]
    }
}

enum DragonDBMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            DragonDBSchemaV1.self,
            DragonDBSchemaV2.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: DragonDBSchemaV1.self, toVersion: DragonDBSchemaV2.self),
        ]
    }
}

enum DragonDBModelContainerFactory {
    static var currentSchema: Schema {
        Schema(versionedSchema: DragonDBSchemaV2.self)
    }

    static func makeModelContainer(
        isStoredInMemoryOnly: Bool = false,
        url: URL? = nil
    ) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration("default", schema: currentSchema, url: url)
        } else {
            configuration = ModelConfiguration(
                "default",
                schema: currentSchema,
                isStoredInMemoryOnly: isStoredInMemoryOnly
            )
        }

        return try ModelContainer(
            for: currentSchema,
            migrationPlan: DragonDBMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
