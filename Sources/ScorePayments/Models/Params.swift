/// Parameters for creating a charge.
public struct ChargeParams: Sendable, Codable {
    public let amount: Int
    public let currency: String
    public let customerId: String?
    public let description: String?
    public let idempotencyKey: String?
    public let metadata: [String: String]

    public init(
        amount: Int,
        currency: String,
        customerId: String? = nil,
        description: String? = nil,
        idempotencyKey: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.amount = amount
        self.currency = currency
        self.customerId = customerId
        self.description = description
        self.idempotencyKey = idempotencyKey
        self.metadata = metadata
    }
}

/// Parameters for creating a customer.
public struct CustomerParams: Sendable, Codable {
    public let email: String?
    public let name: String?
    public let metadata: [String: String]

    public init(
        email: String? = nil,
        name: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.email = email
        self.name = name
        self.metadata = metadata
    }
}

/// Parameters for creating a checkout session.
public struct CheckoutParams: Sendable, Codable {
    public let lineItems: [LineItem]
    public let successURL: String
    public let cancelURL: String
    public let customerId: String?
    public let idempotencyKey: String?
    public let metadata: [String: String]

    public init(
        lineItems: [LineItem],
        successURL: String,
        cancelURL: String,
        customerId: String? = nil,
        idempotencyKey: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.lineItems = lineItems
        self.successURL = successURL
        self.cancelURL = cancelURL
        self.customerId = customerId
        self.idempotencyKey = idempotencyKey
        self.metadata = metadata
    }
}

/// A single line item in a checkout session.
public struct LineItem: Sendable, Codable {
    public let name: String
    public let amount: Int
    public let currency: String
    public let quantity: Int

    public init(name: String, amount: Int, currency: String, quantity: Int = 1) {
        self.name = name
        self.amount = amount
        self.currency = currency
        self.quantity = quantity
    }
}

/// Parameters for creating a subscription.
public struct SubscriptionParams: Sendable, Codable {
    public let customerId: String
    public let priceId: String
    public let idempotencyKey: String?
    public let metadata: [String: String]

    public init(
        customerId: String,
        priceId: String,
        idempotencyKey: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.customerId = customerId
        self.priceId = priceId
        self.idempotencyKey = idempotencyKey
        self.metadata = metadata
    }
}

/// Parameters for creating a payout.
public struct PayoutParams: Sendable, Codable {
    public let amount: Int
    public let currency: String
    public let description: String?
    public let idempotencyKey: String?
    public let metadata: [String: String]

    public init(
        amount: Int,
        currency: String,
        description: String? = nil,
        idempotencyKey: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.amount = amount
        self.currency = currency
        self.description = description
        self.idempotencyKey = idempotencyKey
        self.metadata = metadata
    }
}
