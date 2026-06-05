//
//  Export.swift
//  tb
//
//  Reads the current process's recent entries back out of the unified log and
//  writes them as newline-delimited JSON (NDJSON) — the payload a reader like
//  TailBeat ingests, and what the app's "Export Logs" button hands the user.
//
//  OSLog is the single source of truth, so the result is bound by OSLog
//  retention: `notice`/`error`/`fault` persist and appear here; `debug`/`info`
//  generally do not. Every entry from the process is included (all subsystems
//  and categories), not just `tb` messages — `tb` messages simply carry the
//  `⟦tb1⟧` tail so the reader can show extra context for them.
//

import Foundation
import OSLog

/// Write every persisted OSLog entry from the current process since `since`
/// to `url` as NDJSON. Throws if the log store is unavailable (e.g. blocked by
/// the sandbox) or the file cannot be written.
public func exportRecentLogs(since: Date, to url: URL) throws {
    let store = try OSLogStore(scope: .currentProcessIdentifier)
    let position = store.position(date: since)
    let entries = try store.getEntries(at: position)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    let timestamp = ISO8601DateFormatter()
    timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var ndjson = ""
    for entry in entries {
        guard let log = entry as? OSLogEntryLog else { continue }
        let record = ExportRecord(
            timestamp: timestamp.string(from: log.date),
            subsystem: log.subsystem,
            category: log.category,
            level: levelName(log.level),
            process: log.process,
            pid: Int(log.processIdentifier),
            message: log.composedMessage
        )
        if let data = try? encoder.encode(record),
           let line = String(data: data, encoding: .utf8) {
            ndjson += line + "\n"
        }
    }

    try ndjson.write(to: url, atomically: true, encoding: .utf8)
}

private struct ExportRecord: Encodable {
    let timestamp: String
    let subsystem: String
    let category: String
    let level: String
    let process: String
    let pid: Int
    let message: String
}

private func levelName(_ level: OSLogEntryLog.Level) -> String {
    switch level {
    case .undefined: return "undefined"
    case .debug:     return "debug"
    case .info:      return "info"
    case .notice:    return "notice"
    case .error:     return "error"
    case .fault:     return "fault"
    @unknown default: return "unknown"
    }
}
