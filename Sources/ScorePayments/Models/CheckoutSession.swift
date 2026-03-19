/// A checkout session for collecting payment.
public struct CheckoutSession: Sendable, Codable {
    public let id: String
    public let providerId: String
    /// The URL to redirect the user to for payment.
    public let url: String
    public let status: CheckoutStatus
    public let customerId: String?
    public let amount: Int?
    public let currency: String?
    public let metadata: [String: String]

    public init(
        id: String,
        providerId: String,
        url: String,
        status: CheckoutStatus,
        customerId: String? = nil,
        amount: Int? = nil,
        currency: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.providerId = providerId
        self.url = url
        self.status = status
        self.customerId = customerId
        self.amount = amount
        self.currency = currency
        self.metadata = metadata
    }
}

public enum CheckoutStatus: String, Sendable, Codable {
    case open
    case complete
    case expired
}
