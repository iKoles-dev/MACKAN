import Foundation

public enum AddRepositorySheetPresentationPolicy {
    public static let knownSourcesHeight: Double = 160
    public static let minimumSheetHeight: Double = 360

    public static func fields(
        for repositoryID: RepositorySummary.ID?,
        in repositories: [RepositorySummary]
    ) -> (name: String, url: String)? {
        guard let repositoryID,
              let repository = repositories.first(where: { $0.id == repositoryID })
        else {
            return nil
        }

        return (repository.name, repository.url)
    }
}
