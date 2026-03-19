import Foundation

/// A payout (sending money out).
public struct Payout: Sendable, Codable {
    public let id: String
    public let providerId: String
    public let amount: Int
    public let currency: String
    public let status: PayoutStatus
    public let createdAt: Date

    public init(
        id: String,
        providerId: String,
        amount: Int,
        currency: String,
        status: PayoutStatus,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.providerId = providerId
        self.amount = amount
        self.currency = currency
        self.status = status
        self.createdAt = createdAt
    }
}

public enum PayoutStatus: String, Sendable, Codable {
    case pending
    case paid
    case failed
    case canceled
}
