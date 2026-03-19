import Foundation
import Score

/// Handles incoming webhook POST requests from payment providers.
///
/// Routes (relative to `config.basePath`):
/// - `POST /webhook/:provider` — Receives and verifies webhook payloads.
struct PaymentsController: Controller {
    let config: PaymentConfig
    let broadcaster: PaymentEventBroadcaster
    let providerFactory: @Sendable (PaymentProviderConfig) -> any PaymentProvider

    var base: String { config.basePath }

    var routes: [Route] {
        [
            Route(method: .post, path: "/webhook/:provider", handler: handleWebhook),
        ]
    }

    private func handleWebhook(_ request: RequestContext) async throws -> Response {
        let providerId = request.pathParameters["provider"] ?? ""
        guard let providerConfig = config.providers[providerId] else {
            return Response.text("Unknown provider: \(providerId)", status: .notFound)
        }

        guard let body = request.body, !body.isEmpty else {
            return Response.text("Empty request body", status: .badRequest)
        }

        let provider = providerFactory(providerConfig)

        do {
            let event = try provider.verifyWebhook(payload: body, headers: request.headers)
            broadcaster.broadcast(event)
            return Response.text("OK", status: .ok)
        } catch {
            return Response.text("Webhook verification failed", status: .badRequest)
        }
    }
}
