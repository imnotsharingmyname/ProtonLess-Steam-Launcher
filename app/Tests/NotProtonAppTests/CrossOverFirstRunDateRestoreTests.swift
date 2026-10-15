import Foundation
import Testing

@testable import NotProtonApp

@Suite("CrossOver first-run date restore script")
struct CrossOverFirstRunDateRestoreTests {
    @Test("Restore script is included as a SwiftPM resource")
    func scriptIsBundled() throws {
        let url = try #require(CrossOverFirstRunDateRestore.scriptURL)
        let script = try String(contentsOf: url, encoding: .utf8)
        #expect(script.contains("CrossOver_FirstRunDate_Backup.txt"))
        #expect(script.contains("FirstRunDate -date"))
        #expect(script.contains("pgrep -x \"CrossOver\""))
    }
}
