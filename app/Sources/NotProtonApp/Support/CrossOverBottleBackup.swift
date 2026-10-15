import Foundation

/// Executes the bundled, auditable registry-only CrossOver bottle backup script.
/// Uses Shell.run, which starts a Foundation Process and drains both pipes concurrently.
enum CrossOverBottleBackup {
    enum BackupError: LocalizedError {
        case missingScript
        case failed(status: Int32, details: String)

        var errorDescription: String? {
            switch self {
            case .missingScript:
                "The bundled CrossOver bottle backup script is missing. Rebuild the app."
            case .failed(let status, let details):
                "Bottle backup failed (exit status \(status)).\n\(details)"
            }
        }
    }

    /// The synchronous Process wait runs off the main actor, keeping SwiftUI responsive.
    static func run() async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try runBlocking()
        }.value
    }

    private nonisolated static func runBlocking() throws -> String {
        guard let script = scriptURL else {
            throw BackupError.missingScript
        }

        // Run a fixed bundled script through /bin/bash, not a user-supplied command.
        let result = try Shell.run("/bin/bash", [script.path])
        let stdout = plainText(result.stdout)
        let stderr = plainText(result.stderr)
        let output = [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard result.succeeded && !result.outputLost else {
            throw BackupError.failed(
                status: result.status,
                details: output.isEmpty ? "No output was captured from the backup script." : output
            )
        }
        return output.isEmpty ? "Backup completed." : output
    }

    nonisolated static var scriptURL: URL? {
        Bundle.module.url(forResource: "backup_crossover_bottles", withExtension: "sh")
    }

    /// Remove the terminal color codes from the script before presenting a SwiftUI alert.
    nonisolated static func plainText(_ text: String) -> String {
        text.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
