//
//  tbTests.swift
//  tb
//
//  Exercises the two-file kit end to end: the OSLog-backed `Logger`, the
//  `mask` helper, and `exportRecentLogs`, which reads the current process's
//  entries back out of the unified log as NDJSON.
//

import Foundation
import OSLog
import Testing
@testable import tb

// MARK: - Logger

@Suite struct LoggerTests {
    @Test func eyeCatcherIsVersionedSentinel() {
        #expect(tb.Logger.eyeCatcher == "⟦tb1⟧")
    }

    @Test func everyLevelEmitsWithoutCrashing() {
        let log = tb.Logger(subsystem: "app.tb.tests", category: "levels")
        log.trace("trace")
        log.debug("debug")
        log.info("info")
        log.notice("notice")
        log.warning("warning")
        log.error("error")
        log.error(CocoaError(.fileNoSuchFile))
        log.fault("fault")
        log.log("default")
        log.log(level: .info, "with context", context: ["request": "42"])
    }

    @Test func startEmitsAppStartWithoutCrashing() {
        tb.start(subsystem: "app.tb.tests")
    }
}

// MARK: - mask

@Suite struct MaskTests {
    @Test func emptyValueCollapsesToSentinel() {
        #expect(tb.mask("") == "∅")
    }

    @Test func sameInputAlwaysMasksTheSame() {
        #expect(tb.mask("/Users/alice/secret") == tb.mask("/Users/alice/secret"))
    }

    @Test func differentInputsMaskDifferently() {
        #expect(tb.mask("alpha") != tb.mask("beta"))
    }

    @Test func maskIsWrappedAndHidesTheOriginal() {
        let secret = "super-secret-token"
        let masked = tb.mask(secret)
        #expect(masked.hasPrefix("‹"))
        #expect(masked.hasSuffix("›"))
        #expect(!masked.contains(secret))
    }
}

// MARK: - Export round-trip

@Suite struct ExportTests {
    /// Emit a uniquely identifiable `.error` (which persists in the OSLog store,
    /// unlike `.debug`/`.info`) and assert it round-trips back out through
    /// `exportRecentLogs` as a well-formed NDJSON record.
    @Test func errorLevelLogRoundTripsThroughExport() throws {
        let subsystem = "app.tb.tests.export"
        let category = "roundtrip"
        let marker = "tb-marker-\(UUID().uuidString)"
        let since = Date().addingTimeInterval(-5)

        tb.Logger(subsystem: subsystem, category: category).error(marker)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tb-export-\(UUID().uuidString).ndjson")
        defer { try? FileManager.default.removeItem(at: url) }

        // OSLog commits asynchronously; retry briefly until the marker shows up.
        var contents = ""
        for _ in 0..<30 {
            try exportRecentLogs(since: since, to: url)
            contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if contents.contains(marker) { break }
            Thread.sleep(forTimeInterval: 0.1)
        }

        let lines = contents.split(separator: "\n").map(String.init)
        #expect(!lines.isEmpty)

        // Every emitted line is a JSON object carrying the full record shape.
        for line in lines {
            let object = try JSONSerialization.jsonObject(with: Data(line.utf8))
            let record = try #require(object as? [String: Any])
            #expect(record["timestamp"] as? String != nil)
            #expect(record["subsystem"] as? String != nil)
            #expect(record["category"] as? String != nil)
            #expect(record["level"] as? String != nil)
            #expect(record["process"] as? String != nil)
            #expect(record["pid"] as? Int != nil)
            #expect(record["message"] as? String != nil)
        }

        // The marker came back out, tagged with our subsystem/category/level.
        #expect(contents.contains(marker))
        let markerLine = try #require(lines.first { $0.contains(marker) })
        let record = try #require(
            try JSONSerialization.jsonObject(with: Data(markerLine.utf8)) as? [String: Any]
        )
        #expect(record["subsystem"] as? String == subsystem)
        #expect(record["category"] as? String == category)
        #expect(record["level"] as? String == "error")
        #expect((record["message"] as? String)?.contains(marker) == true)
    }
}
