import Foundation
import Testing

@testable import ScorePayments

@Suite("PaymentEventBroadcaster")
struct PaymentEventBroadcasterTests {

    @Test("Single consumer receives events")
    func singleConsumer() async {
        let broadcaster = PaymentEventBroadcaster()
        let stream = broadcaster.makeStream()

        let charge = Charge(
            id: "ch_1", providerId: "stripe", amount: 1000, currency: "usd", status: .succeeded
        )
        broadcaster.broadcast(.chargeSucceeded(charge))
        broadcaster.finish()

        var received: [PaymentEvent] = []
        for await event in stream {
            received.append(event)
        }
        #expect(received.count == 1)
    }

    @Test("Multiple consumers each receive all events")
    func multipleConsumers() async {
        let broadcaster = PaymentEventBroadcaster()
        let stream1 = broadcaster.makeStream()
        let stream2 = broadcaster.makeStream()

        let charge = Charge(
            id: "ch_1", providerId: "stripe", amount: 1000, currency: "usd", status: .succeeded
        )
        broadcaster.broadcast(.chargeSucceeded(charge))
        broadcaster.finish()

        var count1 = 0
        for await _ in stream1 { count1 += 1 }

        var count2 = 0
        for await _ in stream2 { count2 += 1 }

        #expect(count1 == 1)
        #expect(count2 == 1)
    }

    @Test("Broadcast with no consumers does not crash")
    func noConsumers() {
        let broadcaster = PaymentEventBroadcaster()
        let charge = Charge(
            id: "ch_1", providerId: "stripe", amount: 1000, currency: "usd", status: .succeeded
        )
        broadcaster.broadcast(.chargeSucceeded(charge))
        broadcaster.finish()
    }
}
