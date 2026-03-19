import CryptoKit
import Foundation

/// Revolut payment provider implementation.
///
/// Uses the Revolut Merchant API directly via `URLSession`.
/// No third-party SDK dependency.
struct RevolutProvider: PaymentProvider, SupportsSubscriptions {
    let config: PaymentProviderConfig

    var id: String { "revolut" }
    var displayName: String { "Revolut" }

    // MARK: - Private HTTP Helper

    private func request(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        idempotencyKey: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: "\(config.baseURL)\(path)") else {
            throw PaymentError.invalidRequest("Invalid URL: \(config.baseURL)\(path)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(config.secretKey)", forHTTPHeaderField: "Authorization")

        if let body = body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        if let idempotencyKey = idempotencyKey {
            urlRequest.setValue(idempotencyKey, forHTTPHeaderField: "Revolut-Request-Id")
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

    private func checkedRequest(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        idempotencyKey: String? = nil
    ) async throws -> Data {
        let (data, httpResponse) = try await request(
            path: path, method: method, body: body, idempotencyKey: idempotencyKey)

        if httpResponse.statusCode >= 400 {
            throw Self.parseError(from: data, statusCode: httpResponse.statusCode)
        }

        return data
    }

    // MARK: - Charges

    func createCharge(_ params: ChargeParams) async throws -> Charge {
        var body: [String: Any] = [
            "amount": params.amount,
            "currency": params.currency,
        ]
        if let customerId = params.customerId {
            body["customer_id"] = customerId
        }
        if let description = params.description {
            body["description"] = description
        }
        if !params.metadata.isEmpty {
            body["metadata"] = params.metadata
        }

        let data = try await checkedRequest(
            path: "/1.0/orders",
            method: "POST",
            body: body,
            idempotencyKey: params.idempotencyKey
        )
        return try Self.parseCharge(from: data)
    }

    func getCharge(id: String) async throws -> Charge {
        let data = try await checkedRequest(path: "/1.0/orders/\(id)")
        return try Self.parseCharge(from: data)
    }

    func refundCharge(id: String, amount: Int?) async throws -> Refund {
        var body: [String: Any] = [:]
        if let amount = amount {
            body["amount"] = amount
        }

        let data = try await checkedRequest(
            path: "/1.0/orders/\(id)/refund",
            method: "POST",
            body: body.isEmpty ? nil : body
        )
        return try Self.parseRefund(from: data)
    }

    // MARK: - Customers

    func createCustomer(_ params: CustomerParams) async throws -> Customer {
        var body: [String: Any] = [:]
        if let email = params.email {
            body["email"] = email
        }
        if let name = params.name {
            body["full_name"] = name
        }

        let data = try await checkedRequest(
            path: "/1.0/customers",
            method: "POST",
            body: body
        )
        return try Self.parseCustomer(from: data)
    }

    func getCustomer(id: String) async throws -> Customer {
        let data = try await checkedRequest(path: "/1.0/customers/\(id)")
        return try Self.parseCustomer(from: data)
    }

    func deleteCustomer(id: String) async throws {
        let (_, httpResponse) = try await request(
            path: "/1.0/customers/\(id)",
            method: "DELETE"
        )
        if httpResponse.statusCode >= 400 {
            let data = Data()
            throw Self.parseError(from: data, statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Checkout

    func createCheckoutSession(_ params: CheckoutParams) async throws -> CheckoutSession {
        let totalAmount = params.lineItems.reduce(0) { $0 + $1.amount * $1.quantity }
        let currency = params.lineItems.first?.currency ?? "GBP"

        var body: [String: Any] = [
            "amount": totalAmount,
            "currency": currency,
            "checkout_url": params.successURL,
        ]
        if let customerId = params.customerId {
            body["customer_id"] = customerId
        }
        if !params.metadata.isEmpty {
            body["metadata"] = params.metadata
        }

        let data = try await checkedRequest(
            path: "/1.0/orders",
            method: "POST",
            body: body,
            idempotencyKey: params.idempotencyKey
        )

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let orderId = json["id"] as? String ?? ""
        let checkoutUrl = json["checkout_url"] as? String ?? params.successURL
        let state = json["state"] as? String ?? "PENDING"

        let checkoutStatus: CheckoutStatus
        switch state {
        case "COMPLETED": checkoutStatus = .complete
        case "EXPIRED": checkoutStatus = .expired
        default: checkoutStatus = .open
        }

        return CheckoutSession(
            id: orderId,
            providerId: "revolut",
            url: checkoutUrl,
            status: checkoutStatus,
            customerId: params.customerId,
            amount: totalAmount,
            currency: currency,
            metadata: params.metadata
        )
    }

    // MARK: - Webhooks

    func verifyWebhook(payload: Data, headers: [String: String]) throws -> PaymentEvent {
        guard let signature = headers["revolut-signature"] else {
            throw PaymentError.webhookVerificationFailed
        }

        let expectedSignature = Self.computeHMAC(payload: payload, secret: config.webhookSecret)
        guard signature == expectedSignature else {
            throw PaymentError.webhookVerificationFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
            let eventType = json["event"] as? String
        else {
            throw PaymentError.webhookVerificationFailed
        }

        switch eventType {
        case "ORDER_COMPLETED":
            let orderData: Data
            if let dataObj = json["data"] as? [String: Any] {
                orderData = try JSONSerialization.data(withJSONObject: dataObj)
            } else {
                orderData = payload
            }
            let charge = try Self.parseCharge(from: orderData)
            return .chargeSucceeded(charge)

        case "ORDER_PAYMENT_FAILED":
            let orderData: Data
            if let dataObj = json["data"] as? [String: Any] {
                orderData = try JSONSerialization.data(withJSONObject: dataObj)
            } else {
                orderData = payload
            }
            let charge = try Self.parseCharge(from: orderData)
            return .chargeFailed(charge)

        case "ORDER_REFUNDED":
            let refundData: Data
            if let dataObj = json["data"] as? [String: Any] {
                refundData = try JSONSerialization.data(withJSONObject: dataObj)
            } else {
                refundData = payload
            }
            let refund = try Self.parseRefund(from: refundData)
            return .refundCreated(refund)

        default:
            return .unknown(provider: "revolut", type: eventType, rawPayload: payload)
        }
    }

    // MARK: - Subscriptions

    func createSubscription(_ params: SubscriptionParams) async throws -> Subscription {
        var metadata = params.metadata
        metadata["recurring"] = "true"
        metadata["price_id"] = params.priceId

        var body: [String: Any] = [
            "amount": 0,
            "currency": "GBP",
            "customer_id": params.customerId,
            "metadata": metadata,
        ]

        // If metadata contains interval or amount info, use it
        if let interval = metadata["interval"] {
            body["metadata"] = metadata
            _ = interval  // stored in metadata
        }

        let data = try await checkedRequest(
            path: "/1.0/orders",
            method: "POST",
            body: body,
            idempotencyKey: params.idempotencyKey
        )
        return try Self.parseSubscription(from: data)
    }

    func getSubscription(id: String) async throws -> Subscription {
        let data = try await checkedRequest(path: "/1.0/orders/\(id)")
        return try Self.parseSubscription(from: data)
    }

    func cancelSubscription(id: String) async throws -> Subscription {
        let data = try await checkedRequest(
            path: "/1.0/orders/\(id)/cancel",
            method: "POST"
        )
        return try Self.parseSubscription(from: data)
    }

    func listSubscriptions(customerId: String) async throws -> [Subscription] {
        let data = try await checkedRequest(
            path: "/1.0/orders?customer_id=\(customerId)")

        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }

        var subscriptions: [Subscription] = []
        for item in jsonArray {
            if let metadata = item["metadata"] as? [String: String],
                metadata["recurring"] == "true"
            {
                let itemData = try JSONSerialization.data(withJSONObject: item)
                let sub = try Self.parseSubscription(from: itemData)
                subscriptions.append(sub)
            }
        }
        return subscriptions
    }

    // MARK: - Static Parse Helpers

    /// Compute HMAC-SHA256 of the payload using the given secret, returning a lowercase hex string.
    static func computeHMAC(payload: Data, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return signature.map { String(format: "%02x", $0) }.joined()
    }

    /// Parse a Revolut order JSON response into a `Charge` model.
    static func parseCharge(from data: Data) throws -> Charge {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaymentError.invalidRequest("Invalid charge JSON")
        }

        let id = json["id"] as? String ?? ""
        let amount = json["amount"] as? Int ?? 0
        let currency = json["currency"] as? String ?? ""
        let state = json["state"] as? String ?? "PENDING"
        let customerId = json["customer_id"] as? String

        let status: ChargeStatus
        switch state {
        case "COMPLETED": status = .succeeded
        case "FAILED": status = .failed
        default: status = .pending
        }

        let metadata: [String: String]
        if let meta = json["metadata"] as? [String: String] {
            metadata = meta
        } else {
            metadata = [:]
        }

        return Charge(
            id: id,
            providerId: "revolut",
            amount: amount,
            currency: currency,
            status: status,
            customerId: customerId,
            metadata: metadata
        )
    }

    /// Parse a Revolut refund JSON response into a `Refund` model.
    static func parseRefund(from data: Data) throws -> Refund {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaymentError.invalidRequest("Invalid refund JSON")
        }

        let id = json["id"] as? String ?? ""
        let orderId = json["order_id"] as? String ?? ""
        let amount = json["amount"] as? Int ?? 0
        let currency = json["currency"] as? String ?? ""

        return Refund(
            id: id,
            providerId: "revolut",
            chargeId: orderId,
            amount: amount,
            currency: currency,
            status: .succeeded
        )
    }

    /// Parse a Revolut customer JSON response into a `Customer` model.
    static func parseCustomer(from data: Data) throws -> Customer {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaymentError.invalidRequest("Invalid customer JSON")
        }

        let id = json["id"] as? String ?? ""
        let email = json["email"] as? String
        let name = json["full_name"] as? String

        return Customer(
            id: id,
            providerId: "revolut",
            email: email,
            name: name
        )
    }

    /// Parse a Revolut error response into a `PaymentError`.
    static func parseError(from data: Data, statusCode: Int) -> PaymentError {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let code = json["code"] as? String,
            let message = json["message"] as? String
        {
            return .providerError(provider: "revolut", code: code, message: message)
        }
        return .providerError(
            provider: "revolut",
            code: "\(statusCode)",
            message: "HTTP error \(statusCode)")
    }

    /// Parse a Revolut order JSON into a `Subscription` model (for recurring payment orders).
    static func parseSubscription(from data: Data) throws -> Subscription {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaymentError.invalidRequest("Invalid subscription JSON")
        }

        let id = json["id"] as? String ?? ""
        let amount = json["amount"] as? Int ?? 0
        let currency = json["currency"] as? String ?? "GBP"
        let customerId = json["customer_id"] as? String ?? ""
        let state = json["state"] as? String ?? "PENDING"

        let metadata: [String: String]
        if let meta = json["metadata"] as? [String: String] {
            metadata = meta
        } else {
            metadata = [:]
        }

        let status: SubscriptionStatus
        switch state {
        case "COMPLETED": status = .active
        case "FAILED": status = .unpaid
        case "CANCELLED": status = .canceled
        default: status = .active
        }

        let interval: BillingInterval
        switch metadata["interval"] {
        case "day": interval = .day
        case "week": interval = .week
        case "year": interval = .year
        default: interval = .month
        }

        let now = Date()
        let periodEnd: Date
        switch interval {
        case .day: periodEnd = now.addingTimeInterval(86400)
        case .week: periodEnd = now.addingTimeInterval(604800)
        case .month: periodEnd = now.addingTimeInterval(2_592_000)
        case .year: periodEnd = now.addingTimeInterval(31_536_000)
        }

        return Subscription(
            id: id,
            providerId: "revolut",
            customerId: customerId,
            status: status,
            priceAmount: amount,
            currency: currency,
            interval: interval,
            currentPeriodStart: now,
            currentPeriodEnd: periodEnd,
            canceledAt: state == "CANCELLED" ? now : nil,
            metadata: metadata
        )
    }
}
