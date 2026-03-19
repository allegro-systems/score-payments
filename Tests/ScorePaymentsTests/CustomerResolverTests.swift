import Testing

@testable import ScorePayments

@Suite("ScoreDataCustomerResolver")
struct CustomerResolverTests {

    @Test("Store and resolve a customer mapping")
    func storeAndResolve() async throws {
        let resolver = try ScoreDataCustomerResolver.forTesting()

        try await resolver.store(appUserId: "user-1", provider: "stripe", providerCustomerId: "cus_abc")
        let result = try await resolver.resolve(appUserId: "user-1", provider: "stripe")
        #expect(result == "cus_abc")
    }

    @Test("Resolve returns nil for unknown mapping")
    func resolveUnknown() async throws {
        let resolver = try ScoreDataCustomerResolver.forTesting()

        let result = try await resolver.resolve(appUserId: "user-999", provider: "stripe")
        #expect(result == nil)
    }

    @Test("Different providers are stored independently")
    func differentProviders() async throws {
        let resolver = try ScoreDataCustomerResolver.forTesting()

        try await resolver.store(appUserId: "user-1", provider: "stripe", providerCustomerId: "cus_stripe")
        try await resolver.store(appUserId: "user-1", provider: "revolut", providerCustomerId: "cus_revolut")

        let stripe = try await resolver.resolve(appUserId: "user-1", provider: "stripe")
        let revolut = try await resolver.resolve(appUserId: "user-1", provider: "revolut")
        #expect(stripe == "cus_stripe")
        #expect(revolut == "cus_revolut")
    }

    @Test("Delete removes a mapping")
    func deleteMapping() async throws {
        let resolver = try ScoreDataCustomerResolver.forTesting()

        try await resolver.store(appUserId: "user-1", provider: "stripe", providerCustomerId: "cus_abc")
        try await resolver.delete(appUserId: "user-1", provider: "stripe")
        let result = try await resolver.resolve(appUserId: "user-1", provider: "stripe")
        #expect(result == nil)
    }
}
