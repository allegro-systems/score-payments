/// A customer record from a payment provider.
public struct Customer: Sendable, Codable {
    /// The provider's native customer ID.
    public let id: String
    public let providerId: String
    public let email: String?
    public let name: String?
    public let metadata: [String: String]

    public init(
        id: String,
        providerId: String,
        email: String? = nil,
        name: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.providerId = providerId
        self.email = email
        self.name = name
        self.metadata = metadata
    }
}
