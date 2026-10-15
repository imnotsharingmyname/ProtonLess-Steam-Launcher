import Foundation

/// Restores the previously backed-up CrossOver FirstRunDate preference.
/// Runs without Terminal and returns the script's output for a SwiftUI alert.
enum CrossOverFirstRunDateRestore {
    enum RestoreError: LocalizedError {
        case missingScript
        case failed(status: Int32, details: String)

        var errorDescription: String? {
            switch self {
            case .missingScript:
                "The bundled CrossOver settings restore script is missing. Rebuild the app."
            case .failed(let status, let details):
                "CrossOver settings restore failed (exit status \(status)).\n\(details)"
            }
        }
    }

    static func run() async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try runBlocking()
        }.value
    }

    private nonisolated static func runBlocking() throws -> String {
        guard let script = scriptURL else {
            throw RestoreError.missingScript
        }
        // Process launched by Shell.run: stdout/stderr captured, no Terminal opened.
        let result = try Shell.run("/bin/bash", [script.path])
        let output = [result.stdout, result.stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard result.succeeded && !result.outputLost else {
            throw RestoreError.failed(
                status: result.status,
                details: output.isEmpty ? "No output was captured from the restore script." : output
            )
        }
        return output.isEmpty ? "CrossOver settings restored." : output
    }

    nonisolated static var scriptURL: URL? {
        Bundle.module.url(forResource: "restore_crossover_first_run_date", withExtension: "sh")
    }
}
