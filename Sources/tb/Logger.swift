//
//  Logger.swift
//  tb
//
//  A thin, zero-dependency drop-in for `os.Logger` that writes to the macOS
//  unified log (OSLog). Compared to `os.Logger` it additionally:
//    - captures the call site (file / function / line) plus an optional
//      `context` bag and appends them as an eye-catcher + compact JSON tail, so
//      a reader like TailBeat can reconstruct the full record while Console and
//      Xcode still show a readable line;
//    - emits the absolute `#filePath` in DEBUG (so TailBeat can click-to-open the
//      source on the developer's machine) and only the relative `#fileID` in
//      RELEASE (no absolute path in customer logs).
//
//  There is deliberately no sink / registry / fan-out: OSLog is the single
//  source of truth. Reading logs back (e.g. "Export Logs") goes through
//  `exportRecentLogs` / OSLogStore. If a project later wants file logging it
//  should reach for swift-log, not this module.
//

import Foundation
import os

/// Drop-in replacement for `os.Logger`, with native OSLog levels.
///
/// Swap `os.Logger(subsystem:category:)` for `tb.Logger(subsystem:category:)`;
/// the method names and levels are identical.
public struct Logger: Sendable {
    /// Sentinel that marks the structured tail in a message. Versioned so the
    /// format can evolve without breaking older readers.
    public static let eyeCatcher = "⟦tb1⟧"

    private let logger: os.Logger

    public init(subsystem: String, category: String) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    // MARK: - os.Logger-compatible level methods

    public func trace(_ message: String, context: [String: String]? = nil,
                      fileID: String = #fileID, filePath: String = #filePath,
                      function: String = #function, line: Int = #line) {
        emit(.debug, message, context, fileID, filePath, function, line)
    }

    public func debug(_ message: String, context: [String: String]? = nil,
                      fileID: String = #fileID, filePath: String = #filePath,
                      function: String = #function, line: Int = #line) {
        emit(.debug, message, context, fileID, filePath, function, line)
    }

    public func info(_ message: String, context: [String: String]? = nil,
                     fileID: String = #fileID, filePath: String = #filePath,
                     function: String = #function, line: Int = #line) {
        emit(.info, message, context, fileID, filePath, function, line)
    }

    public func notice(_ message: String, context: [String: String]? = nil,
                       fileID: String = #fileID, filePath: String = #filePath,
                       function: String = #function, line: Int = #line) {
        emit(.default, message, context, fileID, filePath, function, line)
    }

    /// A warning. Maps to OSLog `.default` (notice) so it persists in the store.
    public func warning(_ message: String, context: [String: String]? = nil,
                        fileID: String = #fileID, filePath: String = #filePath,
                        function: String = #function, line: Int = #line) {
        emit(.default, message, context, fileID, filePath, function, line)
    }

    public func error(_ message: String, context: [String: String]? = nil,
                      fileID: String = #fileID, filePath: String = #filePath,
                      function: String = #function, line: Int = #line) {
        emit(.error, message, context, fileID, filePath, function, line)
    }

    /// Convenience overload for Swift errors (used throughout the existing code base).
    public func error(_ error: any Error, context: [String: String]? = nil,
                      fileID: String = #fileID, filePath: String = #filePath,
                      function: String = #function, line: Int = #line) {
        emit(.error, error.localizedDescription, context, fileID, filePath, function, line)
    }

    public func fault(_ message: String, context: [String: String]? = nil,
                      fileID: String = #fileID, filePath: String = #filePath,
                      function: String = #function, line: Int = #line) {
        emit(.fault, message, context, fileID, filePath, function, line)
    }

    public func log(level: OSLogType = .default, _ message: String, context: [String: String]? = nil,
                    fileID: String = #fileID, filePath: String = #filePath,
                    function: String = #function, line: Int = #line) {
        emit(level, message, context, fileID, filePath, function, line)
    }

    // MARK: - Emission

    private func emit(_ type: OSLogType, _ message: String, _ context: [String: String]?,
                      _ fileID: String, _ filePath: String, _ function: String, _ line: Int) {
        #if DEBUG
        let file = filePath     // absolute → TailBeat click-to-open on the dev machine
        #else
        let file = fileID       // relative → no absolute path in customer logs
        #endif
        let tail = Tail(f: file, fn: function, ln: line, ctx: context,
                        kind: nil, app: nil, ver: nil).encoded()
        // The whole payload is `.public` so a reader like TailBeat can recover it;
        // safety comes from never logging secrets, not from OSLog redaction.
        // The literal `⟦tb1⟧` sits between the human message and the JSON tail.
        logger.log(level: type, "\(message, privacy: .public) ⟦tb1⟧\(tail, privacy: .public)")
    }

    /// The structured tail. Optional fields are omitted when `nil`
    /// (compiler-synthesized `encodeIfPresent`).
    struct Tail: Encodable {
        let f: String?
        let fn: String?
        let ln: Int?
        let ctx: [String: String]?
        let kind: String?
        let app: String?
        let ver: String?

        func encoded() -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            guard let data = try? encoder.encode(self),
                  let json = String(data: data, encoding: .utf8) else { return "{}" }
            return json
        }
    }

    /// Emits the highlighted AppStart record. Internal — driven by `tb.start()`.
    static func emitAppStart(subsystem: String) {
        let info = Bundle.main.infoDictionary
        let name = (info?["CFBundleName"] as? String) ?? ProcessInfo.processInfo.processName
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (info?["CFBundleVersion"] as? String) ?? "?"
        let tail = Tail(f: nil, fn: nil, ln: nil, ctx: nil,
                        kind: "appStart", app: name, ver: "\(version) (\(build))").encoded()
        let logger = os.Logger(subsystem: subsystem, category: "lifecycle")
        logger.log(level: .default, "\(name, privacy: .public) started ⟦tb1⟧\(tail, privacy: .public)")
    }
}

/// Call once per process at launch. Emits a single highlighted AppStart record
/// (app name + version from `Bundle.main`) at `.notice`. This is the only
/// predefined internal message — there is no per-call "extras" parameter.
public func start(subsystem: String = "app.MacPacker") {
    Logger.emitAppStart(subsystem: subsystem)
}

/// Obscure a sensitive value (deterministic within a build, non-reversible) so it
/// can appear in a log without exposing its content. Passwords should simply never
/// be logged; use this for things like paths you want present-but-not-readable.
public func mask(_ value: String) -> String {
    guard !value.isEmpty else { return "∅" }
    var hash: UInt64 = 1_469_598_103_934_665_603        // FNV-1a offset basis
    for byte in value.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
    return "‹\(String(hash, radix: 16).prefix(10))›"
}
