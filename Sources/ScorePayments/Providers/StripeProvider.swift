import CryptoKit
import Foundation

/// Stripe payment provider implementation.
///
/// Uses the Stripe REST API directly via `URLSession`.
/// No third-party SDK dependency.
struct StripeProvider: PaymentProvider, SupportsSubscriptions {
    let config: PaymentProviderConfig

    var id: String { "stripe" }
    var displayName: String { "Stripe" }

    // MARK: - Private HTTP Helper

    private func request(
        path: String,
        method: String = "GET",
        body: [(String, String)]? = nil,
        idempotencyKey: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: "\(config.baseURL)\(path)") else {
            throw PaymentError.invalidRequest("Invalid URL: \(config.baseURL)\(path)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(config.secretKey)", forHTTPHeaderField: "Authorization")

        if let idempotencyKey {
            urlRequest.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        if let body, method == "POST" || method == "DELETE" {
            urlRequest.setValue(
                "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let encoded = body.map { key, value in
                "\(Self.formEncode(key))=\(Self.formEncode(value))"
            }.joined(separator: "&")
            urlRequest.httpBody = encoded.data(using: .utf8)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw PaymentError.networkError(message: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.networkError(message: "Invalid HTTP response")
        }

        return (data, httpResponse)
    }

    private static func formEncode(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    // MARK: - Charges

    func createCharge(_ params: ChargeParams) async throws -> Charge {
        var body: [(String, String)] = [
            ("amount", String(params.amount)),
            ("currency", params.currency),
        ]
        if let customerId = params.customerId {
            body.append(("customer", customerId))
        }
        if let description = params.description {
            body.append(("description", description))
        }
        for (key, value) in params.metadata {
            body.append(("metadata[\(key)]", value))
        }

        let (data, response) = try await request(
            path: "/charges", method: "POST", body: body, idempotencyKey: params.idempotencyKey)

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }

        return try Self.parseCharge(from: data)
    }

    func getCharge(id: String) async throws -> Charge {
        let (data, response) = try await request(path: "/charges/\(id)")

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }

        return try Self.parseCharge(from: data)
    }

    func refundCharge(id: String, amount: Int?) async throws -> Refund {
        var body: [(String, String)] = [("charge", id)]
        if let amount {
            body.append(("amount", String(amount)))
        }

        let (data, response) = try await request(path: "/refunds", method: "POST", body: body)

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }

        return try Self.parseRefund(from: data)
    }

    // MARK: - Customers

    func createCustomer(_ params: CustomerParams) async throws -> Customer {
        var body: [(String, String)] = []
        if let email = params.email {
            body.append(("email", email))
        }
        if let name = params.name {
            body.append(("name", name))
        }
        for (key, value) in params.metadata {
            body.append(("metadata[\(key)]", value))
        }

        let (data, response) = try await request(path: "/customers", method: "POST", body: body)

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }

        return try Self.parseCustomer(from: data)
    }

    func getCustomer(id: String) async throws -> Customer {
        let (data, response) = try await request(path: "/customers/\(id)")

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }

        return try Self.parseCustomer(from: data)
    }

    func deleteCustomer(id: String) async throws {
        let (data, response) = try await request(path: "/customers/\(id)", method: "DELETE")

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }
    }

    // MARK: - Checkout

    func createCheckoutSession(_ params: CheckoutParams) async throws -> CheckoutSession {
        var body: [(String, String)] = [
            ("success_url", params.successURL),
            ("cancel_url", params.cancelURL),
            ("mode", "payment"),
        ]
        if let customerId = params.customerId {
            body.append(("customer", customerId))
        }
        for (index, item) in params.lineItems.enumerated() {
            body.append(("line_items[\(index)][price_data][product_data][name]", item.name))
            body.append(("line_items[\(index)][price_data][unit_amount]", String(item.amount)))
            body.append(("line_items[\(index)][price_data][currency]", item.currency))
            body.append(("line_items[\(index)][quantity]", String(item.quantity)))
        }
        for (key, value) in params.metadata {
            body.append(("metadata[\(key)]", value))
        }

        let (data, response) = try await request(
            path: "/checkout/sessions", method: "POST", body: body,
            idempotencyKey: params.idempotencyKey)

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }

        return try Self.parseCheckoutSession(from: data)
    }

    // MARK: - Webhooks

    func verifyWebhook(payload: Data, headers: [String: String]) throws -> PaymentEvent {
        guard let sigHeader = headers["stripe-signature"] else {
            throw PaymentError.webhookVerificationFailed
        }

        // Parse the stripe-signature header
        var timestamp: String?
        var signatureV1: String?

        for part in sigHeader.split(separator: ",") {
            let kv = part.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = String(kv[0])
            let value = String(kv[1])
            switch key {
            case "t": timestamp = value
            case "v1": signatureV1 = value
            default: break
            }
        }

        guard let timestamp, let signatureV1 else {
            throw PaymentError.webhookVerificationFailed
        }

        guard let payloadString = String(data: payload, encoding: .utf8) else {
            throw PaymentError.webhookVerificationFailed
        }

        let signedPayload = "\(timestamp).\(payloadString)"
        let expectedSignature = Self.computeHMAC(
            payload: signedPayload, secret: config.webhookSecret)

        guard expectedSignature == signatureV1 else {
            throw PaymentError.webhookVerificationFailed
        }

        // Parse the event JSON
        guard
            let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
            let eventType = json["type"] as? String,
            let eventData = json["data"] as? [String: Any],
            let objectData = eventData["object"] as? [String: Any]
        else {
            throw PaymentError.invalidRequest("Invalid webhook payload")
        }

        let objectJSON = try JSONSerialization.data(withJSONObject: objectData)

        switch eventType {
        case "charge.succeeded":
            let charge = try Self.parseCharge(from: objectJSON)
            return .chargeSucceeded(charge)

        case "charge.failed":
            let charge = try Self.parseCharge(from: objectJSON)
            return .chargeFailed(charge)

        case "charge.refunded":
            let refund = try Self.parseRefund(from: objectJSON)
            return .refundCreated(refund)

        case "customer.subscription.created":
            let subscription = try Self.parseSubscription(from: objectJSON)
            return .subscriptionCreated(subscription)

        case "customer.subscription.updated":
            let subscription = try Self.parseSubscription(from: objectJSON)
            return .subscriptionUpdated(subscription)

        case "customer.subscription.deleted":
            let subscription = try Self.parseSubscription(from: objectJSON)
            return .subscriptionCanceled(subscription)

        case "invoice.payment_succeeded":
            if objectData["subscription"] != nil {
                let subscription = try Self.parseSubscription(from: objectJSON)
                return .subscriptionRenewed(subscription)
            }
            return .unknown(provider: "stripe", type: eventType, rawPayload: payload)

        case "checkout.session.completed":
            let session = try Self.parseCheckoutSession(from: objectJSON)
            return .checkoutCompleted(session)

        default:
            return .unknown(provider: "stripe", type: eventType, rawPayload: payload)
        }
    }

    // MARK: - Subscriptions

    func createSubscription(_ params: SubscriptionParams) async throws -> Subscription {
        var body: [(String, String)] = [
            ("customer", params.customerId),
            ("items[0][price]", params.priceId),
        ]
        for (key, value) in params.metadata {
            body.append(("metadata[\(key)]", value))
        }

        let (data, response) = try await request(
            path: "/subscriptions", method: "POST", body: body,
            idempotencyKey: params.idempotencyKey)

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }

        return try Self.parseSubscription(from: data)
    }

    func getSubscription(id: String) async throws -> Subscription {
        let (data, response) = try await request(path: "/subscriptions/\(id)")

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }

        return try Self.parseSubscription(from: data)
    }

    func cancelSubscription(id: String) async throws -> Subscription {
        let (data, response) = try await request(
            path: "/subscriptions/\(id)", method: "DELETE")

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }

        return try Self.parseSubscription(from: data)
    }

    func listSubscriptions(customerId: String) async throws -> [Subscription] {
        let encodedCustomerId = Self.formEncode(customerId)
        let (data, response) = try await request(
            path: "/subscriptions?customer=\(encodedCustomerId)")

        if response.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: response.statusCode)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["data"] as? [[String: Any]]
        else {
            throw PaymentError.invalidRequest("Invalid subscription list response")
        }

        return try items.map { item in
            let itemData = try JSONSerialization.data(withJSONObject: item)
            return try Self.parseSubscription(from: itemData)
        }
    }

    // MARK: - Static Parse Helpers

    static func computeHMAC(payload: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(payload.utf8), using: key)
        return signature.map { String(format: "%02x", $0) }.joined()
    }

    static func parseCharge(from data: Data) throws -> Charge {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaymentError.invalidRequest("Invalid charge JSON")
        }

        guard
            let id = json["id"] as? String,
            let amount = json["amount"] as? Int,
            let currency = json["currency"] as? String,
            let statusString = json["status"] as? String
        else {
            throw PaymentError.invalidRequest("Missing required charge fields")
        }

        let status: ChargeStatus
        switch statusString {
        case "succeeded": status = .succeeded
        case "pending": status = .pending
        case "failed": status = .failed
        default: status = .pending
        }

        let customerId = json["customer"] as? String
        let metadata = (json["metadata"] as? [String: String]) ?? [:]
        let createdTimestamp = json["created"] as? TimeInterval
        let createdAt = createdTimestamp.map { Date(timeIntervalSince1970: $0) } ?? Date()

        return Charge(
            id: id,
            providerId: "stripe",
            amount: amount,
            currency: currency,
            status: status,
            customerId: customerId,
            metadata: metadata,
            createdAt: createdAt
        )
    }

    static func parseRefund(from data: Data) throws -> Refund {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaymentError.invalidRequest("Invalid refund JSON")
        }

        guard
            let id = json["id"] as? String,
            let amount = json["amount"] as? Int,
            let currency = json["currency"] as? String,
            let statusString = json["status"] as? String
        else {
            throw PaymentError.invalidRequest("Missing required refund fields")
        }

        let chargeId = (json["charge"] as? String) ?? ""

        let status: RefundStatus
        switch statusString {
        case "succeeded": status = .succeeded
        case "pending": status = .pending
        case "failed": status = .failed
        default: status = .pending
        }

        let createdTimestamp = json["created"] as? TimeInterval
        let createdAt = createdTimestamp.map { Date(timeIntervalSince1970: $0) } ?? Date()

        return Refund(
            id: id,
            providerId: "stripe",
            chargeId: chargeId,
            amount: amount,
            currency: currency,
            status: status,
            createdAt: createdAt
        )
    }

    static func parseCustomer(from data: Data) throws -> Customer {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaymentError.invalidRequest("Invalid customer JSON")
        }

        guard let id = json["id"] as? String else {
            throw PaymentError.invalidRequest("Missing required customer fields")
        }

        let email = json["email"] as? String
        let name = json["name"] as? String
        let metadata = (json["metadata"] as? [String: String]) ?? [:]

        return Customer(
            id: id,
            providerId: "stripe",
            email: email,
            name: name,
            metadata: metadata
        )
    }

    static func parseSubscription(from data: Data) throws -> Subscription {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaymentError.invalidRequest("Invalid subscription JSON")
        }

        guard
            let id = json["id"] as? String,
            let customer = json["customer"] as? String,
            let statusString = json["status"] as? String
        else {
            throw PaymentError.invalidRequest("Missing required subscription fields")
        }

        let status: SubscriptionStatus
        switch statusString {
        case "active": status = .active
        case "past_due": status = .pastDue
        case "canceled": status = .canceled
        case "unpaid": status = .unpaid
        case "trialing": status = .trialing
        default: status = .active
        }

        // Extract price info from items
        var priceAmount = 0
        var currency = "usd"
        var interval: BillingInterval = .month

        if let items = json["items"] as? [String: Any],
            let itemsData = items["data"] as? [[String: Any]],
            let firstItem = itemsData.first,
            let price = firstItem["price"] as? [String: Any]
        {
            priceAmount = (price["unit_amount"] as? Int) ?? 0
            currency = (price["currency"] as? String) ?? "usd"
            if let recurring = price["recurring"] as? [String: Any],
                let intervalString = recurring["interval"] as? String
            {
                switch intervalString {
                case "day": interval = .day
                case "week": interval = .week
                case "month": interval = .month
                case "year": interval = .year
                default: interval = .month
                }
            }
        }

        let periodStart = (json["current_period_start"] as? TimeInterval) ?? 0
        let periodEnd = (json["current_period_end"] as? TimeInterval) ?? 0
        let canceledAtTimestamp = json["canceled_at"] as? TimeInterval
        let metadata = (json["metadata"] as? [String: String]) ?? [:]

        return Subscription(
            id: id,
            providerId: "stripe",
            customerId: customer,
            status: status,
            priceAmount: priceAmount,
            currency: currency,
            interval: interval,
            currentPeriodStart: Date(timeIntervalSince1970: periodStart),
            currentPeriodEnd: Date(timeIntervalSince1970: periodEnd),
            canceledAt: canceledAtTimestamp.map { Date(timeIntervalSince1970: $0) },
            metadata: metadata
        )
    }

    static func parseCheckoutSession(from data: Data) throws -> CheckoutSession {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaymentError.invalidRequest("Invalid checkout session JSON")
        }

        guard
            let id = json["id"] as? String
        else {
            throw PaymentError.invalidRequest("Missing required checkout session fields")
        }

        let url = (json["url"] as? String) ?? ""

        let statusString = json["status"] as? String
        let status: CheckoutStatus
        switch statusString {
        case "open": status = .open
        case "complete": status = .complete
        case "expired": status = .expired
        default: status = .open
        }

        let customerId = json["customer"] as? String
        let amount = json["amount_total"] as? Int
        let currency = json["currency"] as? String
        let metadata = (json["metadata"] as? [String: String]) ?? [:]

        return CheckoutSession(
            id: id,
            providerId: "stripe",
            url: url,
            status: status,
            customerId: customerId,
            amount: amount,
            currency: currency,
            metadata: metadata
        )
    }

    static func parseError(from data: Data, statusCode: Int) -> PaymentError {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any]
        else {
            return .providerError(
                provider: "stripe", code: "unknown",
                message: "HTTP \(statusCode)")
        }

        let code = (error["code"] as? String) ?? (error["type"] as? String) ?? "unknown"
        let message = (error["message"] as? String) ?? "Unknown error"

        return .providerError(provider: "stripe", code: code, message: message)
    }
}
