import Foundation

/// A payment provider that can process charges, manage customers,
/// create checkout sessions, and verify webhooks.
public protocol PaymentProvider: Sendable {
    /// The provider identifier (e.g. "stripe", "revolut").
    var id: String { get }

    /// Human-readable display name.
    var displayName: String { get }

    // MARK: - Charges

    /// Creates a new charge.
    func createCharge(_ params: ChargeParams) async throws -> Charge

    /// Retrieves a charge by its provider-native ID.
    func getCharge(id: String) async throws -> Charge

    /// Refunds a charge. Pass `nil` for `amount` to refund the full amount.
    func refundCharge(id: String, amount: Int?) async throws -> Refund

    // MARK: - Customers

    /// Creates a new customer.
    func createCustomer(_ params: CustomerParams) async throws -> Customer

    /// Retrieves a customer by their provider-native ID.
    func getCustomer(id: String) async throws -> Customer

    /// Deletes a customer.
    func deleteCustomer(id: String) async throws

    // MARK: - Checkout

    /// Creates a hosted checkout session.
    func createCheckoutSession(_ params: CheckoutParams) async throws -> CheckoutSession

    // MARK: - Webhooks

    /// Verifies a webhook payload and parses it into a payment event.
    func verifyWebhook(payload: Data, headers: [String: String]) throws -> PaymentEvent
}
