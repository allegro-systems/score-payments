import Foundation

/// A recurring subscription.
public struct Subscription: Sendable, Codable {
    public let id: String
    public let providerId: String
    public let customerId: String
    public let status: SubscriptionStatus
    public let priceAmount: Int
    public let currency: String
    public let interval: BillingInterval
    public let currentPeriodStart: Date
    public let currentPeriodEnd: Date
    public let canceledAt: Date?
    public let metadata: [String: String]

    public init(
        id: String,
        providerId: String,
        customerId: String,
        status: SubscriptionStatus,
        priceAmount: Int,
        currency: String,
        interval: BillingInterval,
        currentPeriodStart: Date,
        currentPeriodEnd: Date,
        canceledAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.providerId = providerId
        self.customerId = customerId
        self.status = status
        self.priceAmount = priceAmount
        self.currency = currency
        self.interval = interval
        self.currentPeriodStart = currentPeriodStart
        self.currentPeriodEnd = currentPeriodEnd
        self.canceledAt = canceledAt
        self.metadata = metadata
    }
}

public enum SubscriptionStatus: String, Sendable, Codable {
    case active
    case pastDue
    case canceled
    case unpaid
    case trialing
}

public enum BillingInterval: String, Sendable, Codable {
    case day
    case week
    case month
    case year
}
