import Foundation

/// A refund against a charge.
public struct Refund: Sendable, Codable {
    public let id: String
    public let providerId: String
    public let chargeId: String
    public let amount: Int
    public let currency: String
    public let status: RefundStatus
    public let createdAt: Date

    public init(
        id: String,
        providerId: String,
        chargeId: String,
        amount: Int,
        currency: String,
        status: RefundStatus,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.providerId = providerId
        self.chargeId = chargeId
        self.amount = amount
        self.currency = currency
        self.status = status
        self.createdAt = createdAt
    }
}

/// The status of a refund.
public enum RefundStatus: String, Sendable, Codable {
    case pending
    case succeeded
    case failed
}
