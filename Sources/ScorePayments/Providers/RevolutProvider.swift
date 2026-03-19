import Foundation

/// Revolut payment provider implementation.
///
/// Uses the Revolut Merchant API directly via `URLSession`.
/// No third-party SDK dependency.
struct RevolutProvider: PaymentProvider, SupportsSubscriptions {
    let config: PaymentProviderConfig

    var id: String { "revolut" }
    var displayName: String { "Revolut" }

    // MARK: - Charges

    func createCharge(_ params: ChargeParams) async throws -> Charge {
        fatalError("TODO: implement Revolut createCharge")
    }

    func getCharge(id: String) async throws -> Charge {
        fatalError("TODO: implement Revolut getCharge")
    }

    func refundCharge(id: String, amount: Int?) async throws -> Refund {
        fatalError("TODO: implement Revolut refundCharge")
    }

    // MARK: - Customers

    func createCustomer(_ params: CustomerParams) async throws -> Customer {
        fatalError("TODO: implement Revolut createCustomer")
    }

    func getCustomer(id: String) async throws -> Customer {
        fatalError("TODO: implement Revolut getCustomer")
    }

    func deleteCustomer(id: String) async throws {
        fatalError("TODO: implement Revolut deleteCustomer")
    }

    // MARK: - Checkout

    func createCheckoutSession(_ params: CheckoutParams) async throws -> CheckoutSession {
        fatalError("TODO: implement Revolut createCheckoutSession")
    }

    // MARK: - Webhooks

    func verifyWebhook(payload: Data, headers: [String: String]) throws -> PaymentEvent {
        fatalError("TODO: implement Revolut verifyWebhook")
    }

    // MARK: - Subscriptions

    func createSubscription(_ params: SubscriptionParams) async throws -> Subscription {
        fatalError("TODO: implement Revolut createSubscription")
    }

    func getSubscription(id: String) async throws -> Subscription {
        fatalError("TODO: implement Revolut getSubscription")
    }

    func cancelSubscription(id: String) async throws -> Subscription {
        fatalError("TODO: implement Revolut cancelSubscription")
    }

    func listSubscriptions(customerId: String) async throws -> [Subscription] {
        fatalError("TODO: implement Revolut listSubscriptions")
    }
}
