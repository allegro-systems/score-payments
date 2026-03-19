import ScoreData

/// Resolves and stores the mapping between app user IDs
/// and payment provider customer IDs.
public protocol CustomerResolver: Sendable {
    /// Returns the provider's customer ID for the given app user, or `nil` if none.
    func resolve(appUserId: String, provider: String) async throws -> String?

    /// Stores a mapping from an app user to a provider customer ID.
    func store(appUserId: String, provider: String, providerCustomerId: String) async throws

    /// Removes a mapping.
    func delete(appUserId: String, provider: String) async throws
}

/// Default `CustomerResolver` backed by ScoreData's KV store.
///
/// Keys: `["score-payments", "customers", appUserId, providerId]`
/// Values: The provider's customer ID string.
struct ScoreDataCustomerResolver: CustomerResolver {

    private let store: KVStore

    init(store: KVStore) {
        self.store = store
    }

    /// Creates a resolver using the default persistent SQLite store.
    static func persistent() throws -> ScoreDataCustomerResolver {
        ScoreDataCustomerResolver(store: try KVStore.persistent())
    }

    /// Creates a resolver backed by an in-memory store (for testing).
    static func forTesting() throws -> ScoreDataCustomerResolver {
        ScoreDataCustomerResolver(store: KVStore.memory())
    }

    func resolve(appUserId: String, provider: String) async throws -> String? {
        try await store.get(key(appUserId: appUserId, provider: provider))
    }

    func store(appUserId: String, provider: String, providerCustomerId: String) async throws {
        try await store.set(key(appUserId: appUserId, provider: provider), value: providerCustomerId)
    }

    func delete(appUserId: String, provider: String) async throws {
        try await store.delete(key(appUserId: appUserId, provider: provider))
    }

    private func key(appUserId: String, provider: String) -> [String] {
        ["score-payments", "customers", appUserId, provider]
    }
}
