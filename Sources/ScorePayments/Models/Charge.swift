import Foundation

/// A payment charge from any provider.
public struct Charge: Sendable, Codable {
    /// The provider's native charge/payment ID.
    public let id: String
    /// Which provider this charge belongs to ("stripe" or "revolut").
    public let providerId: String
    /// Amount in minor currency units (cents/pence).
    public let amount: Int
    /// ISO 4217 currency code.
    public let currency: String
    /// Current status of the charge.
    public let status: ChargeStatus
    /// The provider's customer ID, if associated.
    public let customerId: String?
    /// Arbitrary key-value metadata.
    public let metadata: [String: String]
    /// When the charge was created.
    public let createdAt: Date

    public init(
        id: String,
        providerId: String,
        amount: Int,
        currency: String,
        status: ChargeStatus,
        customerId: String? = nil,
        metadata: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.providerId = providerId
        self.amount = amount
        self.currency = currency
        self.status = status
        self.customerId = customerId
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

/// The status of a charge.
public enum ChargeStatus: String, Sendable, Codable {
    case pending
    case succeeded
    case failed
    case refunded
}
