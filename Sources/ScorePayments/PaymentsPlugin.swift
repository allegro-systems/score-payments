import Score

/// A Score plugin that provides unified payment processing
/// with Stripe and Revolut.
public struct PaymentsPlugin: ScorePlugin {
    public let name = "Payments"

    public init() {}
}
