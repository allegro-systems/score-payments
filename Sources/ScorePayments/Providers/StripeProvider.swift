import Foundation

/// Stripe payment provider implementation.
///
/// Uses the Stripe REST API directly via `URLSession`.
/// No third-party SDK dependency.
struct StripeProvider: PaymentProvider, SupportsSubscriptions {
    let config: PaymentProviderConfig

    var id: String { "stripe" }
    var displayName: String { "Stripe" }

    // MARK: - Charges

    func createCharge(_ params: ChargeParams) async throws -> Charge {
        fatalError("TODO: implement Stripe createCharge")
    }

    func getCharge(id: String) async throws -> Charge {
        fatalError("TODO: implement Stripe getCharge")
    }

    func refundCharge(id: String, amount: Int?) async throws -> Refund {
        fatalError("TODO: implement Stripe refundCharge")
    }

    // MARK: - Customers

    func createCustomer(_ params: CustomerParams) async throws -> Customer {
        fatalError("TODO: implement Stripe createCustomer")
    }

    func getCustomer(id: String) async throws -> Customer {
        fatalError("TODO: implement Stripe getCustomer")
    }

    func deleteCustomer(id: String) async throws {
        fatalError("TODO: implement Stripe deleteCustomer")
    }

    // MARK: - Checkout

    func createCheckoutSession(_ params: CheckoutParams) async throws -> CheckoutSession {
        fatalError("TODO: implement Stripe createCheckoutSession")
    }

    // MARK: - Webhooks

    func verifyWebhook(payload: Data, headers: [String: String]) throws -> PaymentEvent {
        fatalError("TODO: implement Stripe verifyWebhook")
    }

    // MARK: - Subscriptions

    func createSubscription(_ params: SubscriptionParams) async throws -> Subscription {
        fatalError("TODO: implement Stripe createSubscription")
    }

    func getSubscription(id: String) async throws -> Subscription {
        fatalError("TODO: implement Stripe getSubscription")
    }

    func cancelSubscription(id: String) async throws -> Subscription {
        fatalError("TODO: implement Stripe cancelSubscription")
    }

    func listSubscriptions(customerId: String) async throws -> [Subscription] {
        fatalError("TODO: implement Stripe listSubscriptions")
    }
}
