import Testing

@testable import ScorePayments

@Suite("PaymentsPlugin")
struct PaymentsPluginTests {

    @Test("Plugin has correct name")
    func pluginName() {
        let plugin = PaymentsPlugin()
        #expect(plugin.name == "Payments")
    }
}
