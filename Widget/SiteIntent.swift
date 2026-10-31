import AppIntents
import WidgetKit

struct SiteEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Website"
    static var defaultQuery = SiteQuery()

    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName(for: id))")
    }
}

struct SiteQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SiteEntity] {
        identifiers.map(SiteEntity.init(id:))
    }

    func suggestedEntities() async throws -> [SiteEntity] {
        SharedStore.sites.map(SiteEntity.init(id:))
    }

    func defaultResult() async -> SiteEntity? {
        SharedStore.sites.first.map(SiteEntity.init(id:))
    }
}

struct SelectSiteIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Website wählen"
    static var description = IntentDescription("Welche Website das Widget zeigt.")

    @Parameter(title: "Website")
    var site: SiteEntity?
}
