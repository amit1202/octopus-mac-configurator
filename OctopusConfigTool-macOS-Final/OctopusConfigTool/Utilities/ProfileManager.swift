import Foundation

/// Manages saving and loading configuration profiles to ~/Library/Application Support/OctopusConfigTool/Profiles/
final class ProfileManager: Sendable {
    static let shared = ProfileManager()

    private let profilesDirectory: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        profilesDirectory = appSupport
            .appendingPathComponent("OctopusConfigTool", isDirectory: true)
            .appendingPathComponent("Profiles", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: profilesDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Encoder / Decoder

    private var encoder: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    private var decoder: JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    // MARK: - File Path

    private func fileURL(for profile: Profile) -> URL {
        profilesDirectory.appendingPathComponent("\(profile.id.uuidString).json")
    }

    // MARK: - CRUD

    /// Load all saved profiles from disk, sorted by name
    func loadAllProfiles() -> [Profile] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: profilesDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        let profiles: [Profile] = files.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Profile.self, from: data)
        }

        return profiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Save a profile to disk (creates or overwrites)
    func save(_ profile: Profile) throws {
        let data = try encoder.encode(profile)
        try data.write(to: fileURL(for: profile))
    }

    /// Delete a profile from disk
    func delete(_ profile: Profile) throws {
        let url = fileURL(for: profile)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Export a profile to a user-chosen location
    func exportProfile(_ profile: Profile, to url: URL) throws {
        let data = try encoder.encode(profile)
        try data.write(to: url)
    }

    /// Import a profile from a file
    func importProfile(from url: URL) throws -> Profile {
        let data = try Data(contentsOf: url)
        var profile = try decoder.decode(Profile.self, from: data)
        // Give the imported profile a new UUID so it doesn't conflict with existing ones
        profile.id = UUID()
        profile.updatedAt = Date()
        // Save to local storage
        try save(profile)
        return profile
    }
}
