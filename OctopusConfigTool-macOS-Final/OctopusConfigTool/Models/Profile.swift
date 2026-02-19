import Foundation

struct Profile: Codable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var config: OctopusConfig
    var createdAt: Date
    var updatedAt: Date

    /// Create a new profile from the current configuration
    init(name: String, config: OctopusConfig) {
        self.id = UUID()
        self.name = name
        self.config = config
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
