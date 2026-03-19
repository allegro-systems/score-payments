/// Errors returned by the payments plugin.
public enum PaymentError: Error, Sendable {
    /// No provider configured with the given ID.
    case providerNotFound(String)
    /// The request parameters were invalid.
    case invalidRequest(String)
    /// The payment provider returned an error.
    case providerError(provider: String, code: String, message: String)
    /// Webhook signature verification failed.
    case webhookVerificationFailed
    /// A network request failed.
    case networkError(message: String)
}
