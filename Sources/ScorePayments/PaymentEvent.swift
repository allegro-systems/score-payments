import Foundation

/// An event received from a payment provider webhook.
public enum PaymentEvent: Sendable {
    case chargeSucceeded(Charge)
    case chargeFailed(Charge)
    case refundCreated(Refund)
    case subscriptionCreated(Subscription)
    case subscriptionUpdated(Subscription)
    case subscriptionCanceled(Subscription)
    case subscriptionRenewed(Subscription)
    case checkoutCompleted(CheckoutSession)
    case unknown(provider: String, type: String, rawPayload: Data)
}
