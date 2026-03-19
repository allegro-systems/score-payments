/// A payment provider that supports recurring subscriptions.
public protocol SupportsSubscriptions: PaymentProvider {
    func createSubscription(_ params: SubscriptionParams) async throws -> Subscription
    func getSubscription(id: String) async throws -> Subscription
    func cancelSubscription(id: String) async throws -> Subscription
    func listSubscriptions(customerId: String) async throws -> [Subscription]
}

/// Marker protocol indicating a provider supports multiple currencies.
///
/// All providers already accept a `currency` field in `ChargeParams`.
/// Conforming to this trait signals the provider can handle currencies
/// beyond a single default, and provides discovery of supported currencies.
public protocol SupportsMultiCurrency: PaymentProvider {
    func listSupportedCurrencies() async throws -> [String]
}

/// A payment provider that supports sending money out.
public protocol SupportsPayouts: PaymentProvider {
    func createPayout(_ params: PayoutParams) async throws -> Payout
    func getPayout(id: String) async throws -> Payout
}
