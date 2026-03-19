import Testing

@testable import ScorePayments

@Suite("PaymentProviderConfig")
struct PaymentProviderConfigTests {

    @Test("Stripe factory creates correct config")
    func stripeFactory() {
        let config = PaymentProviderConfig.stripe(
            secretKey: "sk_test_123",
            webhookSecret: "whsec_123"
        )
        #expect(config.id == "stripe")
        #expect(config.displayName == "Stripe")
        #expect(config.secretKey == "sk_test_123")
        #expect(config.webhookSecret == "whsec_123")
    }

    @Test("Revolut factory creates correct config")
    func revolutFactory() {
        let config = PaymentProviderConfig.revolut(
            apiKey: "sk_revolut_123",
            webhookSecret: "wh_revolut_123",
            sandbox: true
        )
        #expect(config.id == "revolut")
        #expect(config.displayName == "Revolut")
        #expect(config.secretKey == "sk_revolut_123")
        #expect(config.webhookSecret == "wh_revolut_123")
        #expect(config.sandbox == true)
    }

    @Test("Revolut defaults to sandbox")
    func revolutDefaultsSandbox() {
        let config = PaymentProviderConfig.revolut(
            apiKey: "key",
            webhookSecret: "secret"
        )
        #expect(config.sandbox == true)
    }
}
