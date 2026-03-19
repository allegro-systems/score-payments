import Testing

@testable import ScorePayments

@Suite("PaymentConfig")
struct PaymentConfigTests {

    @Test("Config indexes providers by ID")
    func indexesByID() {
        let config = PaymentConfig(
            providers: [
                .stripe(secretKey: "sk", webhookSecret: "wh"),
                .revolut(apiKey: "ak", webhookSecret: "wh"),
            ],
            basePath: "/payments",
            customerResolver: nil
        )
        #expect(config.providers["stripe"] != nil)
        #expect(config.providers["revolut"] != nil)
        #expect(config.providers["paypal"] == nil)
    }

    @Test("Config uses custom base path")
    func customBasePath() {
        let config = PaymentConfig(
            providers: [],
            basePath: "/billing",
            customerResolver: nil
        )
        #expect(config.basePath == "/billing")
    }
}
