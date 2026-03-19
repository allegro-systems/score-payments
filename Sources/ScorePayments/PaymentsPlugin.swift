import Score
import ScoreData

/// A Score plugin that provides unified payment processing
/// with Stripe and Revolut.
///
/// Register this plugin in your application:
///
/// ```swift
/// @main
/// struct MySite: Application {
///     var plugins: [any ScorePlugin] {
///         [
///             PaymentsPlugin(providers: [
///                 .stripe(secretKey: "sk_...", webhookSecret: "whsec_..."),
///                 .revolut(apiKey: "sk_...", webhookSecret: "...", sandbox: true),
///             ])
///         ]
///     }
/// }
/// ```
///
/// The plugin auto-registers webhook routes at
/// `{basePath}/webhook/{provider}` for each configured provider.
public struct PaymentsPlugin: ScorePlugin {
    public let name = "Payments"

    private let config: PaymentConfig
    private let broadcaster: PaymentEventBroadcaster

    /// Creates a payments plugin with the given provider configurations.
    ///
    /// - Parameters:
    ///   - providers: One or more payment provider configurations.
    ///   - basePath: Base path for webhook routes. Defaults to `"/payments"`.
    ///   - customerResolver: Custom customer ID resolver. Defaults to ScoreData/SQLite.
    public init(
        providers: [PaymentProviderConfig],
        basePath: String = "/payments",
        customerResolver: (any CustomerResolver)? = nil
    ) {
        self.config = PaymentConfig(
            providers: providers,
            basePath: basePath,
            customerResolver: customerResolver
        )
        self.broadcaster = PaymentEventBroadcaster()
    }

    public var controllers: [any Controller] {
        [PaymentsController(config: config, broadcaster: broadcaster, providerFactory: makeProvider)]
    }

    /// Returns the payment provider for the given ID.
    ///
    /// - Parameter id: The provider identifier (e.g. "stripe", "revolut").
    /// - Returns: The payment provider instance.
    /// - Throws: `PaymentError.providerNotFound` if no provider is configured with that ID.
    public func provider(_ id: String) throws -> any PaymentProvider {
        guard let providerConfig = config.providers[id] else {
            throw PaymentError.providerNotFound(id)
        }
        return makeProvider(from: providerConfig)
    }

    /// Creates a new independent event stream.
    ///
    /// Each call returns a fresh stream — multiple consumers are supported.
    /// The stream ends when the plugin is deallocated or `finish()` is called.
    public func makeEventStream() -> AsyncStream<PaymentEvent> {
        broadcaster.makeStream()
    }

    /// Returns the customer resolver (default or custom).
    func resolveCustomerResolver() throws -> any CustomerResolver {
        if let custom = config.customerResolver {
            return custom
        }
        return try ScoreDataCustomerResolver.persistent()
    }
}

// MARK: - Provider Factory

extension PaymentsPlugin {

    private func makeProvider(from config: PaymentProviderConfig) -> any PaymentProvider {
        switch config.id {
        case "stripe":
            return StripeProvider(config: config)
        case "revolut":
            return RevolutProvider(config: config)
        default:
            fatalError("Unknown payment provider: \(config.id)")
        }
    }
}
