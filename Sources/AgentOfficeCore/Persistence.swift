import Foundation

public actor LocalOrganizationStore {
    public nonisolated let rootURL: URL

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public var organizationFileURL: URL {
        rootURL.appendingPathComponent("organization.json", isDirectory: false)
    }

    public func loadOrCreate() throws -> OrganizationState {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        guard fileManager.fileExists(atPath: organizationFileURL.path) else {
            let organization = OrganizationState.seeded()
            try save(organization)
            return organization
        }

        let data = try Data(contentsOf: organizationFileURL)
        return try decoder.decode(OrganizationState.self, from: data)
    }

    public func save(_ organization: OrganizationState) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        var snapshot = organization
        snapshot.lastSavedAt = Date()
        let data = try encoder.encode(snapshot)
        try data.write(to: organizationFileURL, options: .atomic)
    }

    public func writeArtifact(relativePath: String, content: String) throws {
        let url = rootURL.appendingPathComponent(relativePath, isDirectory: false)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public func readArtifact(relativePath: String) throws -> String {
        let url = rootURL.appendingPathComponent(relativePath, isDirectory: false)
        return try String(contentsOf: url, encoding: .utf8)
    }

    public nonisolated static func artifactPath(
        employeeID: String,
        taskID: String,
        kind: ArtifactKind,
        revision: Int = 0
    ) -> String {
        let suffix = revision > 0 ? "-v\(revision + 1)" : ""
        return "employees/\(employeeID)/\(taskID)-\(kind.rawValue)\(suffix).md"
    }
}

