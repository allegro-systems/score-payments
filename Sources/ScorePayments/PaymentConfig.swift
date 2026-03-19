/// Configuration for a single payment provider.
///
/// Use the static factory methods to create provider configurations:
/// ```swift
/// .stripe(secretKey: "sk_...", webhookSecret: "whsec_...")
/// .revolut(apiKey: "sk_...", webhookSecret: "...", sandbox: true)
/// ```
public struct PaymentProviderConfig: Sendable {
    /// The provider identifier (e.g. "stripe", "revolut").
    public let id: String
    /// Human-readable display name.
    public let displayName: String
    /// The API secret key.
    public let secretKey: String
    /// The webhook signing secret.
    public let webhookSecret: String
    /// Whether to use the sandbox/test environment.
    public let sandbox: Bool
    /// The base URL for API requests.
    let baseURL: String
}

// MARK: - Built-in Providers

extension PaymentProviderConfig {

    /// Stripe payment provider configuration.
    public static func stripe(
        secretKey: String,
        webhookSecret: String
    ) -> PaymentProviderConfig {
        PaymentProviderConfig(
            id: "stripe",
            displayName: "Stripe",
            secretKey: secretKey,
            webhookSecret: webhookSecret,
            sandbox: secretKey.hasPrefix("sk_test_"),
            baseURL: "https://api.stripe.com/v1"
        )
    }

    /// Revolut payment provider configuration.
    public static func revolut(
        apiKey: String,
        webhookSecret: String,
        sandbox: Bool = true
    ) -> PaymentProviderConfig {
        PaymentProviderConfig(
            id: "revolut",
            displayName: "Revolut",
            secretKey: apiKey,
            webhookSecret: webhookSecret,
            sandbox: sandbox,
            baseURL: sandbox
                ? "https://sandbox-merchant.revolut.com/api"
                : "https://merchant.revolut.com/api"
        )
    }
}

/// Internal configuration holding all registered providers and settings.
struct PaymentConfig: Sendable {
    /// Providers keyed by their identifier.
    let providers: [String: PaymentProviderConfig]
    /// Base path for webhook routes (default: "/payments").
    let basePath: String
    /// Optional custom customer resolver.
    let customerResolver: (any CustomerResolver)?

    init(
        providers: [PaymentProviderConfig],
        basePath: String,
        customerResolver: (any CustomerResolver)?
    ) {
        var map: [String: PaymentProviderConfig] = [:]
        for provider in providers {
            map[provider.id] = provider
        }
        self.providers = map
        self.basePath = basePath
        self.customerResolver = customerResolver
    }
}
