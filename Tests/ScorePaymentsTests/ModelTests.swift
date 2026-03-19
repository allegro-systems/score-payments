import Foundation
import Testing

@testable import ScorePayments

@Suite("Models")
struct ModelTests {

    @Test("Charge round-trips through JSON")
    func chargeRoundTrip() throws {
        let charge = Charge(
            id: "ch_123",
            providerId: "stripe",
            amount: 2000,
            currency: "usd",
            status: .succeeded,
            customerId: "cus_456",
            metadata: ["order": "789"],
            createdAt: Date(timeIntervalSince1970: 1_000_000)
        )
        let data = try JSONEncoder().encode(charge)
        let decoded = try JSONDecoder().decode(Charge.self, from: data)
        #expect(decoded.id == "ch_123")
        #expect(decoded.providerId == "stripe")
        #expect(decoded.amount == 2000)
        #expect(decoded.currency == "usd")
        #expect(decoded.status == .succeeded)
        #expect(decoded.customerId == "cus_456")
        #expect(decoded.metadata["order"] == "789")
    }

    @Test("Refund round-trips through JSON")
    func refundRoundTrip() throws {
        let refund = Refund(
            id: "re_123",
            providerId: "stripe",
            chargeId: "ch_123",
            amount: 1000,
            currency: "usd",
            status: .succeeded,
            createdAt: Date(timeIntervalSince1970: 1_000_000)
        )
        let data = try JSONEncoder().encode(refund)
        let decoded = try JSONDecoder().decode(Refund.self, from: data)
        #expect(decoded.id == "re_123")
        #expect(decoded.chargeId == "ch_123")
        #expect(decoded.status == .succeeded)
    }

    @Test("Customer round-trips through JSON")
    func customerRoundTrip() throws {
        let customer = Customer(
            id: "cus_123",
            providerId: "revolut",
            email: "test@example.com",
            name: "Alice",
            metadata: [:]
        )
        let data = try JSONEncoder().encode(customer)
        let decoded = try JSONDecoder().decode(Customer.self, from: data)
        #expect(decoded.id == "cus_123")
        #expect(decoded.providerId == "revolut")
        #expect(decoded.email == "test@example.com")
    }

    @Test("Subscription round-trips through JSON")
    func subscriptionRoundTrip() throws {
        let sub = Subscription(
            id: "sub_123",
            providerId: "stripe",
            customerId: "cus_456",
            status: .active,
            priceAmount: 999,
            currency: "usd",
            interval: .month,
            currentPeriodStart: Date(timeIntervalSince1970: 1_000_000),
            currentPeriodEnd: Date(timeIntervalSince1970: 2_000_000),
            canceledAt: nil,
            metadata: [:]
        )
        let data = try JSONEncoder().encode(sub)
        let decoded = try JSONDecoder().decode(Subscription.self, from: data)
        #expect(decoded.status == .active)
        #expect(decoded.interval == .month)
        #expect(decoded.priceAmount == 999)
    }

    @Test("CheckoutSession round-trips through JSON")
    func checkoutSessionRoundTrip() throws {
        let session = CheckoutSession(
            id: "cs_123",
            providerId: "stripe",
            url: "https://checkout.stripe.com/pay/cs_123",
            status: .open,
            customerId: nil,
            amount: 5000,
            currency: "gbp",
            metadata: [:]
        )
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(CheckoutSession.self, from: data)
        #expect(decoded.url == "https://checkout.stripe.com/pay/cs_123")
        #expect(decoded.status == .open)
    }

    @Test("Payout round-trips through JSON")
    func payoutRoundTrip() throws {
        let payout = Payout(
            id: "po_123",
            providerId: "revolut",
            amount: 10000,
            currency: "eur",
            status: .pending,
            createdAt: Date(timeIntervalSince1970: 1_000_000)
        )
        let data = try JSONEncoder().encode(payout)
        let decoded = try JSONDecoder().decode(Payout.self, from: data)
        #expect(decoded.status == .pending)
        #expect(decoded.currency == "eur")
    }

    @Test("ChargeStatus raw values are correct")
    func chargeStatusValues() {
        #expect(ChargeStatus.pending.rawValue == "pending")
        #expect(ChargeStatus.succeeded.rawValue == "succeeded")
        #expect(ChargeStatus.failed.rawValue == "failed")
        #expect(ChargeStatus.refunded.rawValue == "refunded")
    }

    @Test("BillingInterval raw values are correct")
    func billingIntervalValues() {
        #expect(BillingInterval.day.rawValue == "day")
        #expect(BillingInterval.week.rawValue == "week")
        #expect(BillingInterval.month.rawValue == "month")
        #expect(BillingInterval.year.rawValue == "year")
    }
}
