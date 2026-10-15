import Foundation
import Testing

@testable import NotProtonApp

@Suite("CrossOver registry backup script")
struct CrossOverBottleBackupTests {
    @Test("Bundle includes registry-only backup shell script")
    func scriptIsBundled() throws {
        let url = try #require(CrossOverBottleBackup.scriptURL)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("find_bottles"))
        #expect(text.contains("system.reg"))
        #expect(text.contains("cp \"$bottlePath/system.reg\" \"$backupFile\""))
    }


    @Test("Copies bottle registries without changing originals; a second run keeps previous backups")
    func backsUpTwoBottles() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotProton backup test \(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let bottles = home.appendingPathComponent(
            "Library/Application Support/CrossOver/Bottles", isDirectory: true
        )
        for (name, content) in [("Default", "one"), ("Game Bottle", "two")] {
            let folder = bottles.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try content.write(to: folder.appendingPathComponent("system.reg"), atomically: true, encoding: .utf8)
        }
        let script = try #require(CrossOverBottleBackup.scriptURL)
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = home.path
        let first = try Shell.run("/bin/bash", [script.path], environment: environment)
        #expect(first.succeeded)
        #expect(first.stdout.contains("Found 2 bottle(s)"))
        let second = try Shell.run("/bin/bash", [script.path], environment: environment)
        #expect(second.succeeded)
        for (name, content) in [("Default", "one"), ("Game Bottle", "two")] {
            let folder = bottles.appendingPathComponent(name)
            let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            let backups = files.filter { $0.hasPrefix("system.reg.") && $0.hasSuffix(".bak") }
            #expect(backups.count == 2)
            #expect(try String(contentsOf: folder.appendingPathComponent("system.reg"), encoding: .utf8) == content)
            for backup in backups {
                #expect(try String(contentsOf: folder.appendingPathComponent(backup), encoding: .utf8) == content)
            }
        }
    }

    @Test("Missing CrossOver bottles directory exits with failure")
    func missingBottles() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotProton missing \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let script = try #require(CrossOverBottleBackup.scriptURL)
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = home.path
        let result = try Shell.run("/bin/bash", [script.path], environment: environment)
        #expect(!result.succeeded)
        #expect(result.stderr.contains("CrossOver bottles directory not found"))
    }

    @Test("Terminal formatting is stripped before display")
    func terminalColors() {
        #expect(CrossOverBottleBackup.plainText("\u{001B}[32mOK\u{001B}[0m\n") == "OK")
    }
}
