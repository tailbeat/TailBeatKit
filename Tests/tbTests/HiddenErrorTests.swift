//
//  HiddenErrorTests.swift
//  tb
//
//  A hidden error is not written as `<private>`: os_log leaves readable what
//  says which error it is, and the kit writes the same.
//
//  `os.Logger` writes this hidden form on every system for a `.sensitive`
//  value, so the tests can compare with it wherever they run: each error of
//  the table goes through `os.Logger` and through the kit, as the same object.
//

import Foundation
import os
import Testing
@testable import tb

enum PayloadError: Error {
    case notFound(path: String)
}

enum LocalizedFailure: LocalizedError {
    case boom
    var errorDescription: String? { "a localized secret" }
}

struct CustomError: CustomNSError {
    static var errorDomain: String { "app.tb.custom" }
    var errorCode: Int { 42 }
    var errorUserInfo: [String: Any] { ["user": "jane"] }
}

final class DescribingError: NSError, @unchecked Sendable {
    override var description: String { "a description with a secret" }
}

/// An error whose hidden form is compared with what `os.Logger` writes.
struct ErrorSample: Sendable, CustomTestStringConvertible {
    let name: String
    let error: any Error
    /// What `os.Logger` wrote for the hidden error when the table was made.
    /// `nil` where that differs from run to run: the hidden form has the
    /// address of an underlying error in it, and the keys of a user info in
    /// the order its dictionary happens to have.
    let hidden: String?

    init(_ name: String, _ error: any Error, hidden: String? = nil) {
        self.name = name
        self.error = error
        self.hidden = hidden
    }

    var testDescription: String { name }

    private static let missingFile = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT))
    private static let inner = NSError(domain: "app.tb.inner", code: 3)

    static let all: [ErrorSample] = [
        // Swift errors: the type is the domain, the case the code
        ErrorSample("swift", PlainError.boom, hidden: "Error Domain=tbTests.PlainError Code=0"),
        ErrorSample("swift.describable", DescribedError.boom, hidden: "Error Domain=tbTests.DescribedError Code=0"),
        ErrorSample("swift.payload", PayloadError.notFound(path: "/Users/jane"), hidden: "Error Domain=tbTests.PayloadError Code=0"),
        ErrorSample("swift.localized", LocalizedFailure.boom, hidden: "Error Domain=tbTests.LocalizedFailure Code=0"),
        ErrorSample("swift.custom", CustomError(), hidden: "Error Domain=app.tb.custom Code=42 UserInfo={user=<private>}"),

        // Objects: domain and code, and the keys of the user info
        ErrorSample("object", NSError(domain: "app.tb.tests", code: 7), hidden: "Error Domain=app.tb.tests Code=7"),
        ErrorSample("object.negative", NSError(domain: "app.tb.tests", code: -1009), hidden: "Error Domain=app.tb.tests Code=-1009"),
        ErrorSample("object.unicode", NSError(domain: "dömäin 日本 👋", code: 1), hidden: "Error Domain=dömäin 日本 👋 Code=1"),
        ErrorSample("object.description", NSError(domain: "app.tb.tests", code: 7, userInfo: [NSLocalizedDescriptionKey: "secret text"]),
                    hidden: "Error Domain=app.tb.tests Code=7 UserInfo={NSLocalizedDescription=<private>}"),
        ErrorSample("object.subclass", DescribingError(domain: "app.tb.sub", code: 5), hidden: "Error Domain=app.tb.sub Code=5"),
        ErrorSample("object.keys", NSError(domain: "app.tb.tests", code: 7, userInfo: [
            NSLocalizedDescriptionKey: "secret text", NSLocalizedFailureReasonErrorKey: "a reason", NSFilePathErrorKey: "/Users/jane",
            "path": "/Users/jane", "a": "1", "b": "2", "c": "3"])),

        // Values in the user info: numbers are written, everything else is not
        ErrorSample("value.number", NSError(domain: "app.tb.tests", code: 7, userInfo: ["attempt": 3]),
                    hidden: "Error Domain=app.tb.tests Code=7 UserInfo={attempt=3}"),
        ErrorSample("value.bool", NSError(domain: "app.tb.tests", code: 7, userInfo: ["retry": true]),
                    hidden: "Error Domain=app.tb.tests Code=7 UserInfo={retry=1}"),
        ErrorSample("value.double", NSError(domain: "app.tb.tests", code: 7, userInfo: ["ratio": 1.5]),
                    hidden: "Error Domain=app.tb.tests Code=7 UserInfo={ratio=1.5}"),
        ErrorSample("value.kinds", NSError(domain: "app.tb.tests", code: 7, userInfo: [
            "string": "s", "numeric string": "42", "url": URL(fileURLWithPath: "/Users/jane"), "array": [1, 2], "dictionary": ["k": 1],
            "null": NSNull(), "date": Date(timeIntervalSince1970: 0), "data": Data([1, 2]), "float": Float(0.1), "big": UInt64.max,
            "nan": Double.nan, "decimal": NSDecimalNumber(string: "1.25")])),
        ErrorSample("value.errors", NSError(domain: "app.tb.tests", code: 7, userInfo: [NSMultipleUnderlyingErrorsKey: [inner]]),
                    hidden: "Error Domain=app.tb.tests Code=7 UserInfo={NSMultipleUnderlyingErrorsKey=<private>}"),

        // Another error in the user info is written in the same form
        ErrorSample("nested", NSError(domain: "app.tb.tests", code: 7, userInfo: ["cause": inner]),
                    hidden: "Error Domain=app.tb.tests Code=7 UserInfo={cause=Error Domain=app.tb.inner Code=3}"),
        ErrorSample("underlying", NSError(domain: "app.tb.tests", code: 7, userInfo: [NSUnderlyingErrorKey: missingFile])),
        ErrorSample("underlying.swift", NSError(domain: "app.tb.tests", code: 7, userInfo: [NSUnderlyingErrorKey: PlainError.boom])),
        ErrorSample("underlying.text", NSError(domain: "app.tb.tests", code: 7, userInfo: [NSUnderlyingErrorKey: "not an error"]),
                    hidden: "Error Domain=app.tb.tests Code=7 UserInfo={NSUnderlyingError=<private>}"),
        ErrorSample("underlying.chain", (1...6).reduce(inner) { error, level in
            NSError(domain: "app.tb.level\(level)", code: level, userInfo: [NSUnderlyingErrorKey: error, "secret": "s"])
        }),
        ErrorSample("nested.chain", (1...6).reduce(missingFile) { error, level in
            NSError(domain: "app.tb.level\(level)", code: level, userInfo: [level % 2 == 0 ? "cause" : NSUnderlyingErrorKey: error, "n": level])
        }),

        // The system's errors
        ErrorSample("posix.missing", POSIXError(.ENOENT), hidden: #"Error Domain=NSPOSIXErrorDomain Code=2 "No such file or directory""#),
        ErrorSample("posix.denied", POSIXError(.EACCES), hidden: "Error Domain=NSPOSIXErrorDomain Code=13"),
        ErrorSample("posix.unknown", NSError(domain: NSPOSIXErrorDomain, code: 999), hidden: "Error Domain=NSPOSIXErrorDomain Code=999"),
        ErrorSample("cocoa", CocoaError(.fileNoSuchFile), hidden: "Error Domain=NSCocoaErrorDomain Code=4"),
        ErrorSample("url", URLError(.notConnectedToInternet), hidden: "Error Domain=NSURLErrorDomain Code=-1009"),
        ErrorSample("osstatus", NSError(domain: NSOSStatusErrorDomain, code: -50), hidden: "Error Domain=NSOSStatusErrorDomain Code=-50"),
        ErrorSample("mach", NSError(domain: NSMachErrorDomain, code: 5), hidden: "Error Domain=NSMachErrorDomain Code=5"),
        ErrorSample("thrown.read", thrown { _ = try Data(contentsOf: URL(fileURLWithPath: "/nonexistent/tb/file.txt")) }),
        ErrorSample("thrown.remove", thrown { try FileManager.default.removeItem(atPath: "/nonexistent/tb/file.txt") }),
        ErrorSample("thrown.json", thrown { _ = try JSONSerialization.jsonObject(with: Data("[".utf8)) }),
    ]

    /// A Swift error with several keys in its user info. Such an error makes
    /// that dictionary anew whenever it is turned into an object, and a new
    /// dictionary has its keys in an order of its own. Two lines about the
    /// same error can therefore name the keys in different orders — two lines
    /// of `os.Logger` as much as one of each logger — and the comparison has
    /// to look at the entries, not at their order.
    static let unordered = ErrorSample("thrown.decoding", thrown { _ = try JSONDecoder().decode([Int].self, from: Data("{".utf8)) })

    /// The error `body` throws.
    private static func thrown(_ body: () throws -> Void) -> any Error {
        do { try body() } catch { return error }
        return PlainError.boom
    }
}

@Suite struct HiddenErrorTests {
    private func release(_ message: tb.OSLogMessage) -> String { message.render(revealingHiddenValues: false) }
    private func debug(_ message: tb.OSLogMessage) -> String { message.render(revealingHiddenValues: true) }

    /// The hidden form, whichever way the error is hidden and whichever way
    /// it gets into the message.
    @Test(arguments: ErrorSample.all)
    func aHiddenErrorIsWrittenAsOSLoggerWritesIt(sample: ErrorSample) throws {
        let error = sample.error
        let expected = try #require(try Recorded.reference("hidden.error.\(sample.name)"))
        if let hidden = sample.hidden { #expect(expected == hidden, "os.Logger writes what the table says") }

        // Hidden in every build.
        #expect(debug("\(error, privacy: .sensitive)") == expected)
        #expect(release("\(error, privacy: .sensitive)") == expected)
        // Hidden by its kind or by `.private`, in a build that hides.
        #expect(release("\(error)") == expected)
        #expect(release("\(error, privacy: .private)") == expected)
        #expect(release("\(error, privacy: .auto(mask: .none), attributes: "name=error")") == expected)
        // As an optional, as an object, and from `Logger.error(_:)`.
        #expect(release("\(Optional(error))") == expected)
        #expect(release("\(error as NSError)") == (try #require(try Recorded.reference("hidden.object.\(sample.name)"))))
        #expect(release("\(error as NSError as NSObject?)") == expected)
        #expect(release("\(localizedDescriptionOf: error, privacy: .auto)") == expected)
        #expect(debug("\(localizedDescriptionOf: error, privacy: .sensitive)") == expected)
    }

    /// The entries of the outermost user info of a hidden form, sorted, with
    /// what stands around them.
    private func entries(_ hidden: String) -> [String] {
        guard let start = hidden.range(of: " UserInfo={"), hidden.hasSuffix("}") else { return [hidden] }
        var entries: [String] = [], entry = "", depth = 0
        for character in hidden[start.upperBound...].dropLast() {
            if character == "{" { depth += 1 } else if character == "}" { depth -= 1 }
            if character == ",", depth == 0 { entries.append(entry.trimmingCharacters(in: .whitespaces)); entry = "" } else { entry.append(character) }
        }
        return [String(hidden[..<start.lowerBound])] + (entries + [entry.trimmingCharacters(in: .whitespaces)]).sorted()
    }

    @Test func aSwiftErrorWithSeveralKeysHasTheEntriesOSLoggerWrites() throws {
        let error = ErrorSample.unordered.error
        let expected = entries(try #require(try Recorded.reference("hidden.error.thrown.decoding")))
        #expect(expected.first == "Error Domain=NSCocoaErrorDomain Code=4864")
        #expect(expected.count == 4, "\(expected)")
        #expect(entries(release("\(error)")) == expected)
        #expect(entries(debug("\(error, privacy: .sensitive)")) == expected)
        #expect(entries(release("\(localizedDescriptionOf: error, privacy: .private)")) == expected)
        #expect(entries("Error Domain=d Code=1 UserInfo={b=<private>, a=0x1 {Error Domain=e Code=2 UserInfo={z=1, y=2}}}")
                == ["Error Domain=d Code=1", "a=0x1 {Error Domain=e Code=2 UserInfo={z=1, y=2}}", "b=<private>"])
    }

    /// Shown, an error is written in full, as before.
    @Test(arguments: ErrorSample.all)
    func aShownErrorIsWrittenInFull(sample: ErrorSample) {
        let error = sample.error
        #expect(debug("\(error)") == (error as NSError).description)
        #expect(release("\(error, privacy: .public)") == (error as NSError).description)
        #expect(debug("\(localizedDescriptionOf: error, privacy: .private)") == error.localizedDescription)
        #expect(release("\(localizedDescriptionOf: error, privacy: .public)") == error.localizedDescription)
    }

    /// What an error is about stays out of its hidden form: its texts, its
    /// paths, and how it describes itself.
    @Test func theHiddenFormLeavesOutWhatTheErrorIsAbout() {
        let underlying = NSError(domain: "app.tb.inner", code: 3, userInfo: [NSLocalizedDescriptionKey: "inner secret", NSFilePathErrorKey: "/Users/jane/inner"])
        let error = NSError(domain: "app.tb.tests", code: 7, userInfo: [
            NSLocalizedDescriptionKey: "secret text", NSLocalizedFailureReasonErrorKey: "secret reason", NSFilePathErrorKey: "/Users/jane/file",
            NSURLErrorKey: URL(fileURLWithPath: "/Users/jane/file"), NSUnderlyingErrorKey: underlying, "cause": underlying, "attempt": 3])
        let hidden = release("\(error)")
        for secret in ["secret", "jane", "/Users"] {
            #expect(!hidden.contains(secret), "\(secret) in \(hidden)")
        }
        #expect(hidden.hasPrefix("Error Domain=app.tb.tests Code=7 UserInfo={"))
        #expect(hidden.contains("attempt=3") && hidden.contains("NSFilePath=<private>") && hidden.contains("Error Domain=app.tb.inner Code=3"))
        #expect(!release("\(DescribingError(domain: "app.tb.sub", code: 5))").contains("secret"))
        #expect(!release("\(PayloadError.notFound(path: "/Users/jane"))").contains("jane"))
        #expect(!release("\(LocalizedFailure.boom)").contains("secret"))
    }

    /// No error, no hidden form; and a mask takes its place.
    @Test func whatIsNotAnErrorStaysPrivate() {
        let none: (any Error)? = nil
        #expect(release("\(none)") == "<private>")
        #expect(release("\(nil as NSError?)") == "<private>")
        #expect(release("\(NSNumber(value: 7))") == "<private>")
        #expect(release("\(PlainError.boom.localizedDescription)") == "<private>")
        #expect(release("\(String(describing: PlainError.boom))") == "<private>")
        #expect(release("\(PlainError.boom, privacy: .private(mask: .hash))").hasPrefix("<mask.hash: '"))
        #expect(debug("\(PlainError.boom, privacy: .sensitive(mask: .hash))").hasPrefix("<mask.hash: '"))
    }
}
