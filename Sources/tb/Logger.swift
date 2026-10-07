//
//  Logger.swift
//  tb
//
//  A thin, zero-dependency drop-in for `os.Logger` that writes to the unified
//  log (OSLog). Compared to `os.Logger` it additionally:
//    - renders each message itself, so it — not the reading system — decides
//      which interpolated values are written out and which become `<private>`
//      (see OSLogMessage.swift);
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

/// Drop-in replacement for `os.Logger`.
///
/// Swap `import os` for `import tb`; the call sites stay as they are. The
/// initializers, the method names, their levels and the message syntax —
/// with `privacy:`, `align:`, `format:` and `attributes:` — match `os.Logger`.
///
/// What differs is who hides a value. The kit renders the message itself:
/// a value that is hidden by `.private` or by its type is written out in a
/// debug build and as `<private>` in every other build, and a `.sensitive`
/// value is written out in none. See `OSLogPrivacy`.
public struct Logger: Sendable {
    /// Sentinel that marks the structured tail in a message. Versioned so the
    /// format can evolve without breaking older readers.
    public static let eyeCatcher = "⟦tb1⟧"

    /// A logger that records nothing.
    public static var disabled: Logger { Logger(.disabled) }

    private let logger: os.Logger

    public init(subsystem: String, category: String) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    /// A logger for the default log.
    public init() {
        self.logger = os.Logger()
    }

    /// A logger for an existing log object.
    public init(_ logObj: OSLog) {
        self.logger = os.Logger(logObj)
    }

    /// Whether messages of this level are currently recorded.
    public func isEnabled(type: OSLogType) -> Bool {
        logger.isEnabled(type: type)
    }

    // MARK: - os.Logger-compatible level methods
    //
    // Each method logs at the level `os.Logger` uses for the same name. The
    // message is only built — and its interpolated expressions only evaluated —
    // when that level is recorded.
    //
    // `context` is written to the log as it is, in every build. Keep user data
    // out of it; put that in the message, where it has a privacy option.

    /// Logs at the debug level.
    public func trace(_ message: @autoclosure () -> OSLogMessage, context: [String: String]? = nil,
                      fileID: String = #fileID, filePath: String = #filePath,
                      function: String = #function, line: Int = #line) {
        emit(.debug, message, context, fileID, filePath, function, line)
    }

    /// Logs at the debug level.
    public func debug(_ message: @autoclosure () -> OSLogMessage, context: [String: String]? = nil,
                      fileID: String = #fileID, filePath: String = #filePath,
                      function: String = #function, line: Int = #line) {
        emit(.debug, message, context, fileID, filePath, function, line)
    }

    /// Logs at the info level.
    public func info(_ message: @autoclosure () -> OSLogMessage, context: [String: String]? = nil,
                     fileID: String = #fileID, filePath: String = #filePath,
                     function: String = #function, line: Int = #line) {
        emit(.info, message, context, fileID, filePath, function, line)
    }

    /// Logs at the default (notice) level.
    public func notice(_ message: @autoclosure () -> OSLogMessage, context: [String: String]? = nil,
                       fileID: String = #fileID, filePath: String = #filePath,
                       function: String = #function, line: Int = #line) {
        emit(.default, message, context, fileID, filePath, function, line)
    }

    /// Logs at the error level.
    public func warning(_ message: @autoclosure () -> OSLogMessage, context: [String: String]? = nil,
                        fileID: String = #fileID, filePath: String = #filePath,
                        function: String = #function, line: Int = #line) {
        emit(.error, message, context, fileID, filePath, function, line)
    }

    /// Logs at the error level.
    public func error(_ message: @autoclosure () -> OSLogMessage, context: [String: String]? = nil,
                      fileID: String = #fileID, filePath: String = #filePath,
                      function: String = #function, line: Int = #line) {
        emit(.error, message, context, fileID, filePath, function, line)
    }

    /// Logs an error's `localizedDescription` at the error level. The
    /// description is a hidden value unless `privacy` says otherwise. Where it
    /// is hidden, the domain and the code of the error are written in its
    /// place, as in `log.error("\(error)")`.
    public func error(_ error: any Error, privacy: OSLogPrivacy = .auto, context: [String: String]? = nil,
                      fileID: String = #fileID, filePath: String = #filePath,
                      function: String = #function, line: Int = #line) {
        emit(.error, { "\(localizedDescriptionOf: error, privacy: privacy)" }, context, fileID, filePath, function, line)
    }

    /// Logs at the fault level.
    public func critical(_ message: @autoclosure () -> OSLogMessage, context: [String: String]? = nil,
                         fileID: String = #fileID, filePath: String = #filePath,
                         function: String = #function, line: Int = #line) {
        emit(.fault, message, context, fileID, filePath, function, line)
    }

    /// Logs at the fault level.
    public func fault(_ message: @autoclosure () -> OSLogMessage, context: [String: String]? = nil,
                      fileID: String = #fileID, filePath: String = #filePath,
                      function: String = #function, line: Int = #line) {
        emit(.fault, message, context, fileID, filePath, function, line)
    }

    /// Logs at the given level, or at the default (notice) level.
    public func log(level: OSLogType = .default, _ message: @autoclosure () -> OSLogMessage,
                    context: [String: String]? = nil,
                    fileID: String = #fileID, filePath: String = #filePath,
                    function: String = #function, line: Int = #line) {
        emit(level, message, context, fileID, filePath, function, line)
    }

    // MARK: - Emission

    private func emit(_ type: OSLogType, _ message: () -> OSLogMessage, _ context: [String: String]?,
                      _ fileID: String, _ filePath: String, _ function: String, _ line: Int) {
        guard logger.isEnabled(type: type) else { return }
        #if DEBUG
        let reveal = true       // what `.private` and `.auto` hide is written out
        let file = filePath     // absolute → TailBeat click-to-open on the dev machine
        #else
        let reveal = false      // hidden values become `<private>`, or a fingerprint
        let file = fileID       // relative → no absolute path in customer logs
        #endif
        let (text, tail) = Self.fitted(text: message().render(revealingHiddenValues: reveal),
                                       tail: Tail(f: file, fn: function, ln: line, ctx: context,
                                                  kind: nil, app: nil, ver: nil),
                                       capacity: Self.capacity(for: type))
        // The kit has already decided what the line contains, so the finished
        // text is handed over as `.public`: a reader like TailBeat can recover
        // it, and what it recovers does not depend on the reading system.
        // The literal `⟦tb1⟧` sits between the human message and the JSON tail.
        logger.log(level: type, "\(text, privacy: .public) ⟦tb1⟧\(tail, privacy: .public)")
    }

    // MARK: - Lines that are too long
    //
    // os_log stores a limited number of bytes of the values of one message.
    // What is beyond is cut off, from the end — and the end of a line is its
    // tail. A line that is too long would so lose the place it came from. The
    // kit therefore cuts the text itself, before os_log cuts the tail.

    /// How many UTF-8 bytes os_log is sure to store of the two values of a
    /// line, text and tail together: 1008, and 786 for a fault.
    ///
    /// Both are measured. Below the fault level a line of 1008 bytes comes
    /// back whole from the log store and one of 1009 comes back cut, however
    /// the bytes are divided between text and tail. A fault has more room,
    /// 2030 bytes, but shares it with the call stack that os_log stores with
    /// a fault: up to 59 frames at 5 bytes each, and 16 bytes for every
    /// different binary among them. That leaves between 786 and 1978 bytes,
    /// depending on where the call comes from. The kit does not look at the
    /// stack; it keeps to what fits under every one. The tests repeat the
    /// measurement for the stack they run on.
    static func capacity(for type: OSLogType) -> Int {
        type == .fault ? 786 : 1008
    }

    /// The mark where a text has been cut. It is the one os_log itself puts
    /// where it cuts a value.
    static let cutMark = "<…>"

    /// Text and tail of a line, such that both fit into `capacity` bytes.
    ///
    /// The tail is never cut; the text gives way to it. One part of the tail
    /// gives way first, though: a context that makes the tail longer than
    /// half the line is left out, with a note in its place, so that a long
    /// context does not push the message out of its own line.
    ///
    /// A call site that is longer than a whole line on its own — a file path
    /// of about a thousand bytes — is beyond this: the text is then cut down
    /// to the mark, and os_log cuts the tail.
    static func fitted(text: String, tail: Tail, capacity: Int) -> (text: String, tail: String) {
        var encoded = tail.encoded()
        guard text.utf8.count + encoded.utf8.count > capacity else { return (text, encoded) }
        if let context = tail.ctx, encoded.utf8.count > capacity / 2 {
            let size = context.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count }
            encoded = Tail(f: tail.f, fn: tail.fn, ln: tail.ln, ctx: [cutMark: "\(size) bytes of context left out"],
                           kind: tail.kind, app: tail.app, ver: tail.ver).encoded()
        }
        return (cut(text, toUTF8Count: capacity - encoded.utf8.count), encoded)
    }

    /// `text` in at most `count` UTF-8 bytes: cut behind a whole character,
    /// with `cutMark` — counted in — where the rest was. If there is no room
    /// even for the mark, the mark is all that is left.
    static func cut(_ text: String, toUTF8Count count: Int) -> String {
        guard text.utf8.count > count else { return text }
        let room = count - cutMark.utf8.count
        var end = text.startIndex, used = 0
        while end < text.endIndex {
            let next = text.index(after: end)
            used += text.utf8.distance(from: end, to: next)
            if used > room { break }
            end = next
        }
        return String(text[..<end]) + cutMark
    }

    /// The structured tail: one JSON object. Fields are written in the order
    /// declared here and left out when `nil`.
    struct Tail {
        let f: String?
        let fn: String?
        let ln: Int?
        let ctx: [String: String]?
        let kind: String?
        let app: String?
        let ver: String?

        /// Written by hand rather than with `JSONEncoder`: this runs for every
        /// log call, and an encoder per call costs several times the rest of
        /// the call. The output is what `JSONEncoder` produces with
        /// `.withoutEscapingSlashes`, in a fixed key order.
        func encoded() -> String {
            var json: [UInt8] = []
            json.reserveCapacity(128)
            json.append(UInt8(ascii: "{"))
            if let f { json.appendJSONMember(#""f":"#); json.appendJSONString(f) }
            if let fn { json.appendJSONMember(#""fn":"#); json.appendJSONString(fn) }
            if let ln { json.appendJSONMember(#""ln":"#); json.append(contentsOf: String(ln).utf8) }
            if let ctx {
                json.appendJSONMember(#""ctx":{"#)
                for (key, value) in ctx.sorted(by: { $0.key < $1.key }) {
                    json.appendJSONMember("")
                    json.appendJSONString(key)
                    json.append(UInt8(ascii: ":"))
                    json.appendJSONString(value)
                }
                json.append(UInt8(ascii: "}"))
            }
            if let kind { json.appendJSONMember(#""kind":"#); json.appendJSONString(kind) }
            if let app { json.appendJSONMember(#""app":"#); json.appendJSONString(app) }
            if let ver { json.appendJSONMember(#""ver":"#); json.appendJSONString(ver) }
            json.append(UInt8(ascii: "}"))
            return String(decoding: json, as: UTF8.self)
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

/// JSON as UTF-8 bytes. Every character that needs escaping is a single byte,
/// and no byte of a longer UTF-8 sequence can be mistaken for one.
private extension [UInt8] {
    /// Starts a member of the open object: a comma unless it is the first
    /// one, then `opening`.
    mutating func appendJSONMember(_ opening: StaticString) {
        if last != UInt8(ascii: "{") { append(UInt8(ascii: ",")) }
        opening.withUTF8Buffer { append(contentsOf: $0) }
    }

    /// Appends `value` as a JSON string. Escapes exactly what `JSONEncoder`
    /// escapes with `.withoutEscapingSlashes`: `"`, `\` and U+0000…U+001F.
    mutating func appendJSONString(_ value: String) {
        func needsEscape(_ byte: UInt8) -> Bool {
            byte < 0x20 || byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "\\")
        }
        append(UInt8(ascii: "\""))
        if !value.utf8.contains(where: needsEscape) {
            append(contentsOf: value.utf8)      // the usual case: file paths, function names
        } else {
            for byte in value.utf8 {
                switch byte {
                case UInt8(ascii: "\""): append(contentsOf: #"\""#.utf8)
                case UInt8(ascii: "\\"): append(contentsOf: #"\\"#.utf8)
                case 0x08: append(contentsOf: #"\b"#.utf8)
                case 0x09: append(contentsOf: #"\t"#.utf8)
                case 0x0A: append(contentsOf: #"\n"#.utf8)
                case 0x0C: append(contentsOf: #"\f"#.utf8)
                case 0x0D: append(contentsOf: #"\r"#.utf8)
                case 0x00..<0x20:
                    let hex = Array("0123456789abcdef".utf8)
                    append(contentsOf: #"\u00"#.utf8)
                    append(hex[Int(byte >> 4)])
                    append(hex[Int(byte & 0x0F)])
                default: append(byte)
                }
            }
        }
        append(UInt8(ascii: "\""))
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
