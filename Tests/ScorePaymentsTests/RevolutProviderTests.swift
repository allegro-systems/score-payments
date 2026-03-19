import Foundation
import Testing

@testable import ScorePayments

@Suite("RevolutProvider")
struct RevolutProviderTests {

    private func makeProvider(sandbox: Bool = true) -> RevolutProvider {
        RevolutProvider(
            config: .revolut(apiKey: "sk_test_revolut", webhookSecret: "wh_secret", sandbox: sandbox))
    }

    @Test("Sandbox provider uses sandbox base URL")
    func sandboxURL() {
        let provider = makeProvider(sandbox: true)
        #expect(provider.config.baseURL.contains("sandbox"))
    }

    @Test("Production provider uses production base URL")
    func productionURL() {
        let provider = makeProvider(sandbox: false)
        #expect(!provider.config.baseURL.contains("sandbox"))
    }

    @Test("Parse Revolut order JSON into Charge model")
    func parseOrderJSON() throws {
        let json = """
            {"id":"order_123","type":"payment","amount":3000,"currency":"GBP","state":"COMPLETED","customer_id":"cust_456","metadata":{"ref":"abc"}}
            """
        let charge = try RevolutProvider.parseCharge(from: Data(json.utf8))
        #expect(charge.id == "order_123")
        #expect(charge.providerId == "revolut")
        #expect(charge.amount == 3000)
        #expect(charge.currency == "GBP")
        #expect(charge.status == .succeeded)
        #expect(charge.customerId == "cust_456")
        #expect(charge.metadata["ref"] == "abc")
    }

    @Test("Parse Revolut order with PENDING state")
    func parsePendingOrder() throws {
        let json = """
            {"id":"order_456","type":"payment","amount":1500,"currency":"EUR","state":"PENDING"}
            """
        let charge = try RevolutProvider.parseCharge(from: Data(json.utf8))
        #expect(charge.status == .pending)
    }

    @Test("Parse Revolut order with FAILED state")
    func parseFailedOrder() throws {
        let json = """
            {"id":"order_789","type":"payment","amount":500,"currency":"USD","state":"FAILED"}
            """
        let charge = try RevolutProvider.parseCharge(from: Data(json.utf8))
        #expect(charge.status == .failed)
    }

    @Test("Parse Revolut refund JSON into Refund model")
    func parseRefundJSON() throws {
        let json = """
            {"id":"refund_001","order_id":"order_123","amount":1000,"currency":"GBP","state":"COMPLETED"}
            """
        let refund = try RevolutProvider.parseRefund(from: Data(json.utf8))
        #expect(refund.id == "refund_001")
        #expect(refund.providerId == "revolut")
        #expect(refund.chargeId == "order_123")
        #expect(refund.amount == 1000)
        #expect(refund.currency == "GBP")
        #expect(refund.status == .succeeded)
    }

    @Test("Parse Revolut customer JSON into Customer model")
    func parseCustomerJSON() throws {
        let json = """
            {"id":"cust_123","full_name":"John Doe","email":"john@example.com"}
            """
        let customer = try RevolutProvider.parseCustomer(from: Data(json.utf8))
        #expect(customer.id == "cust_123")
        #expect(customer.providerId == "revolut")
        #expect(customer.email == "john@example.com")
        #expect(customer.name == "John Doe")
    }

    @Test("Parse Revolut error JSON into PaymentError")
    func parseErrorJSON() throws {
        let json = """
            {"code":"1001","message":"Insufficient funds"}
            """
        let error = RevolutProvider.parseError(from: Data(json.utf8), statusCode: 400)
        if case .providerError(let provider, let code, let message) = error {
            #expect(provider == "revolut")
            #expect(code == "1001")
            #expect(message == "Insufficient funds")
        } else {
            #expect(Bool(false), "Expected providerError")
        }
    }

    @Test("Parse error with unknown JSON falls back to status code")
    func parseErrorFallback() throws {
        let json = """
            {"unexpected":"format"}
            """
        let error = RevolutProvider.parseError(from: Data(json.utf8), statusCode: 500)
        if case .providerError(let provider, let code, let message) = error {
            #expect(provider == "revolut")
            #expect(code == "500")
            #expect(message.contains("500"))
        } else {
            #expect(Bool(false), "Expected providerError")
        }
    }

    @Test("HMAC computation produces consistent hex string")
    func hmacComputation() {
        let payload = Data("test payload".utf8)
        let secret = "test_secret"
        let hmac1 = RevolutProvider.computeHMAC(payload: payload, secret: secret)
        let hmac2 = RevolutProvider.computeHMAC(payload: payload, secret: secret)
        #expect(hmac1 == hmac2)
        #expect(!hmac1.isEmpty)
        // HMAC-SHA256 produces 64 hex characters
        #expect(hmac1.count == 64)
    }

    @Test("HMAC computation differs with different secrets")
    func hmacDifferentSecrets() {
        let payload = Data("test payload".utf8)
        let hmac1 = RevolutProvider.computeHMAC(payload: payload, secret: "secret1")
        let hmac2 = RevolutProvider.computeHMAC(payload: payload, secret: "secret2")
        #expect(hmac1 != hmac2)
    }

    @Test("Webhook verification fails with invalid signature")
    func webhookVerificationFails() {
        let provider = makeProvider()
        let payload = Data("{\"event\":\"ORDER_COMPLETED\"}".utf8)
        let headers = ["revolut-signature": "invalid_signature"]
        #expect(throws: PaymentError.self) {
            try provider.verifyWebhook(payload: payload, headers: headers)
        }
    }

    @Test("Webhook verification succeeds with valid signature and maps ORDER_COMPLETED")
    func webhookVerificationSucceeds() throws {
        let provider = makeProvider()
        let json = """
            {"event":"ORDER_COMPLETED","order_id":"order_abc","data":{"id":"order_abc","type":"payment","amount":5000,"currency":"GBP","state":"COMPLETED"}}
            """
        let payload = Data(json.utf8)
        let validSig = RevolutProvider.computeHMAC(payload: payload, secret: "wh_secret")
        let headers = ["revolut-signature": validSig]
        let event = try provider.verifyWebhook(payload: payload, headers: headers)
        if case .chargeSucceeded(let charge) = event {
            #expect(charge.id == "order_abc")
        } else {
            #expect(Bool(false), "Expected chargeSucceeded event")
        }
    }

    @Test("Webhook maps ORDER_PAYMENT_FAILED to chargeFailed")
    func webhookChargeFailed() throws {
        let provider = makeProvider()
        let json = """
            {"event":"ORDER_PAYMENT_FAILED","order_id":"order_fail","data":{"id":"order_fail","type":"payment","amount":2000,"currency":"EUR","state":"FAILED"}}
            """
        let payload = Data(json.utf8)
        let validSig = RevolutProvider.computeHMAC(payload: payload, secret: "wh_secret")
        let headers = ["revolut-signature": validSig]
        let event = try provider.verifyWebhook(payload: payload, headers: headers)
        if case .chargeFailed(let charge) = event {
            #expect(charge.id == "order_fail")
            #expect(charge.status == .failed)
        } else {
            #expect(Bool(false), "Expected chargeFailed event")
        }
    }

    @Test("Webhook maps ORDER_REFUNDED to refundCreated")
    func webhookRefundCreated() throws {
        let provider = makeProvider()
        let json = """
            {"event":"ORDER_REFUNDED","order_id":"order_ref","data":{"id":"refund_x","order_id":"order_ref","amount":1000,"currency":"GBP","state":"COMPLETED"}}
            """
        let payload = Data(json.utf8)
        let validSig = RevolutProvider.computeHMAC(payload: payload, secret: "wh_secret")
        let headers = ["revolut-signature": validSig]
        let event = try provider.verifyWebhook(payload: payload, headers: headers)
        if case .refundCreated(let refund) = event {
            #expect(refund.chargeId == "order_ref")
        } else {
            #expect(Bool(false), "Expected refundCreated event")
        }
    }

    @Test("Webhook maps unknown event to unknown case")
    func webhookUnknownEvent() throws {
        let provider = makeProvider()
        let json = """
            {"event":"SOME_FUTURE_EVENT","order_id":"order_x"}
            """
        let payload = Data(json.utf8)
        let validSig = RevolutProvider.computeHMAC(payload: payload, secret: "wh_secret")
        let headers = ["revolut-signature": validSig]
        let event = try provider.verifyWebhook(payload: payload, headers: headers)
        if case .unknown(let provider, let type, _) = event {
            #expect(provider == "revolut")
            #expect(type == "SOME_FUTURE_EVENT")
        } else {
            #expect(Bool(false), "Expected unknown event")
        }
    }

    @Test("Parse subscription from order with recurring metadata")
    func parseSubscription() throws {
        let json = """
            {"id":"order_sub","type":"payment","amount":9900,"currency":"USD","state":"COMPLETED","customer_id":"cust_1","metadata":{"recurring":"true","price_id":"price_monthly","interval":"month"}}
            """
        let sub = try RevolutProvider.parseSubscription(from: Data(json.utf8))
        #expect(sub.id == "order_sub")
        #expect(sub.providerId == "revolut")
        #expect(sub.customerId == "cust_1")
        #expect(sub.priceAmount == 9900)
        #expect(sub.currency == "USD")
        #expect(sub.interval == .month)
        #expect(sub.status == .active)
    }

    @Test("Provider id and displayName")
    func providerIdentity() {
        let provider = makeProvider()
        #expect(provider.id == "revolut")
        #expect(provider.displayName == "Revolut")
    }
}
