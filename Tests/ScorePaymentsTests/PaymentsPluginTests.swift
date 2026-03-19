import Testing

@testable import ScorePayments

@Suite("PaymentsPlugin")
struct PaymentsPluginTests {

    @Test("Plugin has correct name")
    func pluginName() {
        let plugin = PaymentsPlugin(providers: [
            .stripe(secretKey: "sk_test_123", webhookSecret: "whsec_123"),
        ])
        #expect(plugin.name == "Payments")
    }

    @Test("Plugin registers controllers when providers are configured")
    func registersControllers() {
        let plugin = PaymentsPlugin(providers: [
            .stripe(secretKey: "sk_test_123", webhookSecret: "whsec_123"),
        ])
        #expect(!plugin.controllers.isEmpty)
    }

    @Test("Plugin provides provider access by ID")
    func providerAccess() throws {
        let plugin = PaymentsPlugin(providers: [
            .stripe(secretKey: "sk_test_123", webhookSecret: "whsec_123"),
        ])
        let provider = try plugin.provider("stripe")
        #expect(provider.id == "stripe")
    }

    @Test("Plugin throws for unknown provider")
    func unknownProvider() {
        let plugin = PaymentsPlugin(providers: [
            .stripe(secretKey: "sk_test_123", webhookSecret: "whsec_123"),
        ])
        #expect(throws: PaymentError.self) {
            try plugin.provider("paypal")
        }
    }

    @Test("Plugin creates event streams")
    func eventStream() async {
        let plugin = PaymentsPlugin(providers: [
            .stripe(secretKey: "sk_test_123", webhookSecret: "whsec_123"),
        ])
        // Should not crash — just verifies the method exists and returns a stream
        let _ = plugin.makeEventStream()
    }

    @Test("Plugin uses default base path")
    func defaultBasePath() {
        let plugin = PaymentsPlugin(providers: [])
        let controllers = plugin.controllers
        // Controller base path should be "/payments"
        if let controller = controllers.first {
            #expect(controller.base == "/payments")
        }
    }

    @Test("Plugin uses custom base path")
    func customBasePath() {
        let plugin = PaymentsPlugin(providers: [], basePath: "/billing")
        let controllers = plugin.controllers
        if let controller = controllers.first {
            #expect(controller.base == "/billing")
        }
    }

    @Test("Default customer resolver is ScoreData-backed")
    func defaultCustomerResolver() throws {
        let plugin = PaymentsPlugin(providers: [])
        let resolver = try plugin.resolveCustomerResolver()
        #expect(resolver is ScoreDataCustomerResolver)
    }

    @Test("Custom customer resolver is used when provided")
    func customCustomerResolver() throws {
        let custom = MockCustomerResolver()
        let plugin = PaymentsPlugin(providers: [], customerResolver: custom)
        let resolver = try plugin.resolveCustomerResolver()
        #expect(resolver is MockCustomerResolver)
    }
}

/// Test-only mock for verifying custom resolver injection.
struct MockCustomerResolver: CustomerResolver {
    func resolve(appUserId: String, provider: String) async throws -> String? { nil }
    func store(appUserId: String, provider: String, providerCustomerId: String) async throws {}
    func delete(appUserId: String, provider: String) async throws {}
}
