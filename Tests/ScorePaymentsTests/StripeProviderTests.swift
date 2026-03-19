import Foundation
import Testing

@testable import ScorePayments

@Suite("StripeProvider")
struct StripeProviderTests {

    private func makeProvider() -> StripeProvider {
        StripeProvider(config: .stripe(secretKey: "sk_test_123", webhookSecret: "whsec_test_secret"))
    }

    @Test("Verify webhook with valid signature")
    func validWebhookSignature() throws {
        let provider = makeProvider()
        let payload = Data("""
            {"id":"evt_1","type":"charge.succeeded","data":{"object":{"id":"ch_1","amount":2000,"currency":"usd","status":"succeeded"}}}
            """.utf8)

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let signedPayload = "\(timestamp).\(String(data: payload, encoding: .utf8)!)"
        let signature = StripeProvider.computeHMAC(payload: signedPayload, secret: "whsec_test_secret")
        let sigHeader = "t=\(timestamp),v1=\(signature)"

        let event = try provider.verifyWebhook(payload: payload, headers: ["stripe-signature": sigHeader])
        if case .chargeSucceeded(let charge) = event {
            #expect(charge.id == "ch_1")
            #expect(charge.amount == 2000)
        } else {
            #expect(Bool(false), "Expected chargeSucceeded event")
        }
    }

    @Test("Verify webhook with invalid signature throws")
    func invalidWebhookSignature() {
        let provider = makeProvider()
        let payload = Data("{}".utf8)
        let headers = ["stripe-signature": "t=123,v1=bad_signature"]

        #expect(throws: PaymentError.self) {
            try provider.verifyWebhook(payload: payload, headers: headers)
        }
    }

    @Test("Parse Stripe charge JSON into Charge model")
    func parseChargeJSON() throws {
        let json = """
            {"id":"ch_abc","amount":5000,"currency":"gbp","status":"succeeded","customer":"cus_123","metadata":{"order_id":"ord_1"}}
            """
        let charge = try StripeProvider.parseCharge(from: Data(json.utf8))
        #expect(charge.id == "ch_abc")
        #expect(charge.providerId == "stripe")
        #expect(charge.amount == 5000)
        #expect(charge.currency == "gbp")
        #expect(charge.status == .succeeded)
        #expect(charge.customerId == "cus_123")
    }

    @Test("Parse Stripe error JSON into PaymentError")
    func parseErrorJSON() throws {
        let json = """
            {"error":{"type":"card_error","code":"card_declined","message":"Your card was declined."}}
            """
        let error = StripeProvider.parseError(from: Data(json.utf8), statusCode: 402)
        if case .providerError(let provider, let code, let message) = error {
            #expect(provider == "stripe")
            #expect(code == "card_declined")
            #expect(message == "Your card was declined.")
        } else {
            #expect(Bool(false), "Expected providerError")
        }
    }

    @Test("Parse Stripe refund JSON into Refund model")
    func parseRefundJSON() throws {
        let json = """
            {"id":"re_abc","charge":"ch_123","amount":1500,"currency":"usd","status":"succeeded"}
            """
        let refund = try StripeProvider.parseRefund(from: Data(json.utf8))
        #expect(refund.id == "re_abc")
        #expect(refund.providerId == "stripe")
        #expect(refund.chargeId == "ch_123")
        #expect(refund.amount == 1500)
        #expect(refund.currency == "usd")
        #expect(refund.status == .succeeded)
    }

    @Test("Parse Stripe customer JSON into Customer model")
    func parseCustomerJSON() throws {
        let json = """
            {"id":"cus_xyz","email":"test@example.com","name":"Jane Doe","metadata":{"tier":"premium"}}
            """
        let customer = try StripeProvider.parseCustomer(from: Data(json.utf8))
        #expect(customer.id == "cus_xyz")
        #expect(customer.providerId == "stripe")
        #expect(customer.email == "test@example.com")
        #expect(customer.name == "Jane Doe")
        #expect(customer.metadata["tier"] == "premium")
    }

    @Test("Parse Stripe subscription JSON into Subscription model")
    func parseSubscriptionJSON() throws {
        let json = """
            {"id":"sub_1","customer":"cus_1","status":"active","items":{"data":[{"price":{"unit_amount":999,"currency":"usd","recurring":{"interval":"month"}}}]},"current_period_start":1700000000,"current_period_end":1702592000,"canceled_at":null,"metadata":{}}
            """
        let subscription = try StripeProvider.parseSubscription(from: Data(json.utf8))
        #expect(subscription.id == "sub_1")
        #expect(subscription.providerId == "stripe")
        #expect(subscription.customerId == "cus_1")
        #expect(subscription.status == .active)
        #expect(subscription.priceAmount == 999)
        #expect(subscription.currency == "usd")
        #expect(subscription.interval == .month)
    }

    @Test("Parse Stripe checkout session JSON into CheckoutSession model")
    func parseCheckoutSessionJSON() throws {
        let json = """
            {"id":"cs_1","url":"https://checkout.stripe.com/pay/cs_1","status":"open","customer":"cus_1","amount_total":3000,"currency":"eur","metadata":{}}
            """
        let session = try StripeProvider.parseCheckoutSession(from: Data(json.utf8))
        #expect(session.id == "cs_1")
        #expect(session.providerId == "stripe")
        #expect(session.url == "https://checkout.stripe.com/pay/cs_1")
        #expect(session.status == .open)
        #expect(session.customerId == "cus_1")
        #expect(session.amount == 3000)
        #expect(session.currency == "eur")
    }

    @Test("Webhook with charge.failed event type")
    func webhookChargeFailed() throws {
        let provider = makeProvider()
        let payload = Data("""
            {"id":"evt_2","type":"charge.failed","data":{"object":{"id":"ch_2","amount":500,"currency":"usd","status":"failed"}}}
            """.utf8)

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let signedPayload = "\(timestamp).\(String(data: payload, encoding: .utf8)!)"
        let signature = StripeProvider.computeHMAC(payload: signedPayload, secret: "whsec_test_secret")
        let sigHeader = "t=\(timestamp),v1=\(signature)"

        let event = try provider.verifyWebhook(payload: payload, headers: ["stripe-signature": sigHeader])
        if case .chargeFailed(let charge) = event {
            #expect(charge.id == "ch_2")
            #expect(charge.status == .failed)
        } else {
            #expect(Bool(false), "Expected chargeFailed event")
        }
    }

    @Test("Webhook with unknown event type returns .unknown")
    func webhookUnknownEvent() throws {
        let provider = makeProvider()
        let payload = Data("""
            {"id":"evt_3","type":"some.unknown.event","data":{"object":{"id":"obj_1"}}}
            """.utf8)

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let signedPayload = "\(timestamp).\(String(data: payload, encoding: .utf8)!)"
        let signature = StripeProvider.computeHMAC(payload: signedPayload, secret: "whsec_test_secret")
        let sigHeader = "t=\(timestamp),v1=\(signature)"

        let event = try provider.verifyWebhook(payload: payload, headers: ["stripe-signature": sigHeader])
        if case .unknown(let prov, let type, _) = event {
            #expect(prov == "stripe")
            #expect(type == "some.unknown.event")
        } else {
            #expect(Bool(false), "Expected unknown event")
        }
    }

    @Test("HMAC computation is deterministic")
    func hmacDeterministic() {
        let result1 = StripeProvider.computeHMAC(payload: "test_payload", secret: "test_secret")
        let result2 = StripeProvider.computeHMAC(payload: "test_payload", secret: "test_secret")
        #expect(result1 == result2)
        #expect(!result1.isEmpty)
    }

    @Test("Charge status mapping")
    func chargeStatusMapping() throws {
        let pending = try StripeProvider.parseCharge(from: Data("""
            {"id":"ch_p","amount":100,"currency":"usd","status":"pending"}
            """.utf8))
        #expect(pending.status == .pending)

        let failed = try StripeProvider.parseCharge(from: Data("""
            {"id":"ch_f","amount":100,"currency":"usd","status":"failed"}
            """.utf8))
        #expect(failed.status == .failed)
    }

    @Test("Subscription status mapping")
    func subscriptionStatusMapping() throws {
        let pastDue = try StripeProvider.parseSubscription(from: Data("""
            {"id":"sub_pd","customer":"cus_1","status":"past_due","items":{"data":[{"price":{"unit_amount":100,"currency":"usd","recurring":{"interval":"month"}}}]},"current_period_start":1700000000,"current_period_end":1702592000,"metadata":{}}
            """.utf8))
        #expect(pastDue.status == .pastDue)

        let trialing = try StripeProvider.parseSubscription(from: Data("""
            {"id":"sub_t","customer":"cus_1","status":"trialing","items":{"data":[{"price":{"unit_amount":100,"currency":"usd","recurring":{"interval":"year"}}}]},"current_period_start":1700000000,"current_period_end":1702592000,"metadata":{}}
            """.utf8))
        #expect(trialing.status == .trialing)
        #expect(trialing.interval == .year)
    }
}
