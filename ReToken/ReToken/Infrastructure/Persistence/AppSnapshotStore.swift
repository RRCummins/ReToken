import Foundation

final class AppSnapshotStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() -> AppSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else {
            return nil
        }

        return try? decoder.decode(AppSnapshot.self, from: data)
    }

    func save(_ snapshot: AppSnapshot) {
        do {
            let directoryURL = snapshotURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save app snapshot: \(error)")
        }
    }

    private var snapshotURL: URL {
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupportURL
            .appendingPathComponent("ReToken", isDirectory: true)
            .appendingPathComponent("app-snapshot.json", isDirectory: false)
    }
}
