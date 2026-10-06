//
//  OSLogMessage.swift
//  tb
//
//  The message type behind `Logger`. It gives log calls os_log's call form —
//  `"\(value)"`, `"\(value, privacy: .public)"` and the other options of an
//  interpolated value — through Swift's custom string interpolation, and keeps
//  every value apart from the literal text until the message is rendered.
//
//  Rendering is where a value is either written out or replaced by
//  `<private>`. The kit does this itself, so what a log line contains is
//  decided by the build that wrote it, not by the system that reads it.
//
//  The type names match the `os` module on purpose: a file that spells out
//  `OSLogMessage`, `OSLogPrivacy` or `OSLogType` compiles with only
//  `import tb`.
//

import Foundation
import os

/// The level of a log message. This is Apple's own type under its own name.
public typealias OSLogType = os.OSLogType

/// A log object, as accepted by `Logger.init(_:)`. This is Apple's own type
/// under its own name.
public typealias OSLog = os.OSLog

// MARK: - Privacy

/// The privacy of an interpolated value, written as for os_log:
/// `"\(value, privacy: .public)"`.
///
/// A value is either *shown* or *hidden*. A shown value is always written as
/// text. A hidden value is written as text in a debug build and as `<private>`
/// in every other build.
public struct OSLogPrivacy: Sendable {
    enum Option: Sendable {
        case auto, `public`, `private`, sensitive
    }

    let option: Option

    /// The default. Numbers and booleans are shown; everything else — text,
    /// objects, errors, describable values — is hidden.
    public static var auto: OSLogPrivacy { OSLogPrivacy(option: .auto) }

    /// The value is always shown.
    public static var `public`: OSLogPrivacy { OSLogPrivacy(option: .public) }

    /// The value is hidden.
    public static var `private`: OSLogPrivacy { OSLogPrivacy(option: .private) }

    /// The value is hidden.
    public static var sensitive: OSLogPrivacy { OSLogPrivacy(option: .sensitive) }

    /// Whether a value with this option is shown. `shownByDefault` is what
    /// `.auto` means for the value's type.
    func shows(byDefault shownByDefault: Bool) -> Bool {
        switch option {
        case .auto: shownByDefault
        case .public: true
        case .private, .sensitive: false
        }
    }
}

// MARK: - Interpolation

/// Collects the pieces of a log message: literal text and interpolated values.
///
/// The compiler drives this type for every string literal passed to a `Logger`
/// method; it is not meant to be used directly.
public struct OSLogInterpolation: StringInterpolationProtocol {
    /// An interpolated value, kept apart from the text around it.
    ///
    /// Everything that decides how a value appears in the log lives here:
    /// formatting belongs in `render`, and a new option becomes a new property.
    struct Value {
        /// The option written at the call site.
        var privacy: OSLogPrivacy
        /// What `.auto` means for a value of this type.
        var shownByDefault: Bool
        /// Text in front of the value that os_log makes part of the message
        /// rather than of the value — the `+` and `0x` of an unsigned number.
        /// It is written for a hidden value too, and stays outside the column
        /// of an aligned one.
        var prefix = ""
        var align = OSLogStringAlignment.none
        /// The value as text, without `prefix` and not yet aligned. Not called
        /// for a value that is written as `<private>`.
        var render: () -> String

        func text(revealingHiddenValues reveal: Bool) -> String {
            let text = reveal || privacy.shows(byDefault: shownByDefault)
                ? align.apply(to: render())
                : OSLogMessage.hiddenValue      // as it is: os_log does not align what it hides
            return prefix.isEmpty ? text : prefix + text
        }
    }

    enum Segment {
        case literal(String)
        case value(Value)
    }

    var segments: [Segment] = []
    /// A guess at the length of the rendered text, to size its buffer once.
    var capacity: Int

    public init(literalCapacity: Int, interpolationCount: Int) {
        capacity = literalCapacity + 16 * interpolationCount
        segments.reserveCapacity(2 * interpolationCount + 1)
    }

    public mutating func appendLiteral(_ literal: String) {
        if !literal.isEmpty { segments.append(.literal(literal)) }
    }

    /// Every `appendInterpolation` ends here.
    mutating func appendValue(_ privacy: OSLogPrivacy, shownByDefault: Bool, prefix: String = "",
                              align: OSLogStringAlignment = .none, _ render: @escaping () -> String) {
        segments.append(.value(Value(privacy: privacy, shownByDefault: shownByDefault, prefix: prefix,
                                     align: align, render: render)))
    }
}

// MARK: Text — hidden by default

extension OSLogInterpolation {
    public mutating func appendInterpolation(_ string: String, align: OSLogStringAlignment = .none,
                                             privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: false, align: align) { string }
    }

    /// Any describable value, written as its `description`.
    public mutating func appendInterpolation<T: CustomStringConvertible>(_ value: T, align: OSLogStringAlignment = .none,
                                                                         privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: false, align: align) { value.description }
    }

    /// A type, written as its unqualified name.
    public mutating func appendInterpolation(_ type: any Any.Type, align: OSLogStringAlignment = .none,
                                             privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: false, align: align) { String(describing: type) }
    }
}

// MARK: Objects and errors — hidden by default

extension OSLogInterpolation {
    public mutating func appendInterpolation(_ object: NSObject, privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: false) { object.description }
    }

    public mutating func appendInterpolation(_ object: NSObject?, privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: false) { object?.description ?? "(null)" }
    }

    // The error overloads are generic so that a value which is both an object
    // and an error — an `NSError` — has one best match: the object overload
    // above, which is not generic.

    /// An error, written as os_log writes it: the description of its `NSError` form.
    public mutating func appendInterpolation<E: Error>(_ error: E, privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: false) { (error as NSError).description }
    }

    public mutating func appendInterpolation<E: Error>(_ error: E?, privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: false) { (error as NSError?)?.description ?? "(null)" }
    }

    /// An error that is also describable is written as an error. Without this
    /// overload such a value would match the error overload and the describable
    /// one equally well.
    public mutating func appendInterpolation<E: Error & CustomStringConvertible>(_ error: E, privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: false) { (error as NSError).description }
    }
}

// MARK: Numbers and booleans — shown by default

extension OSLogInterpolation {
    public mutating func appendInterpolation(_ number: Int, format: OSLogIntegerFormatting<Int> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInteger(number, format, align, privacy)
    }

    public mutating func appendInterpolation(_ number: Int8, format: OSLogIntegerFormatting<Int8> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInteger(number, format, align, privacy)
    }

    public mutating func appendInterpolation(_ number: Int16, format: OSLogIntegerFormatting<Int16> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInteger(number, format, align, privacy)
    }

    public mutating func appendInterpolation(_ number: Int32, format: OSLogIntegerFormatting<Int32> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInteger(number, format, align, privacy)
    }

    public mutating func appendInterpolation(_ number: Int64, format: OSLogIntegerFormatting<Int64> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInteger(number, format, align, privacy)
    }

    public mutating func appendInterpolation(_ number: UInt, format: OSLogIntegerFormatting<UInt> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInteger(number, format, align, privacy)
    }

    public mutating func appendInterpolation(_ number: UInt8, format: OSLogIntegerFormatting<UInt8> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInteger(number, format, align, privacy)
    }

    public mutating func appendInterpolation(_ number: UInt16, format: OSLogIntegerFormatting<UInt16> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInteger(number, format, align, privacy)
    }

    public mutating func appendInterpolation(_ number: UInt32, format: OSLogIntegerFormatting<UInt32> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInteger(number, format, align, privacy)
    }

    public mutating func appendInterpolation(_ number: UInt64, format: OSLogIntegerFormatting<UInt64> = .decimal,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInteger(number, format, align, privacy)
    }

    /// os_log refuses `.hex` and `.octal` for a signed number, with this
    /// message, when the call is compiled. This overload is what such a call
    /// resolves to, so the kit refuses it in the same way.
    @available(*, unavailable, message: "Signed integers must be formatted using .decimal")
    public mutating func appendInterpolation<T: FixedWidthInteger & SignedInteger>(
        _ number: T, format: OSLogIntegerFormatting<UInt>, align: OSLogStringAlignment = .none,
        privacy: OSLogPrivacy = .auto) {}

    mutating func appendInteger<T: FixedWidthInteger>(_ number: T, _ format: OSLogIntegerFormatting<T>,
                                                      _ align: OSLogStringAlignment, _ privacy: OSLogPrivacy) {
        appendValue(privacy, shownByDefault: true, prefix: format.prefix, align: align) { format.text(number) }
    }

    /// Written with six decimal places unless `format` says otherwise, as
    /// os_log's default `%f`.
    public mutating func appendInterpolation(_ number: Double, format: OSLogFloatFormatting = .fixed,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: true, align: align) { format.text(number) }
    }

    public mutating func appendInterpolation(_ number: Float, format: OSLogFloatFormatting = .fixed,
                                             align: OSLogStringAlignment = .none, privacy: OSLogPrivacy = .auto) {
        appendInterpolation(Double(number), format: format, align: align, privacy: privacy)
    }

    /// Written as `true` or `false` unless `format` says otherwise.
    public mutating func appendInterpolation(_ boolean: Bool, format: OSLogBoolFormat = .truth,
                                             privacy: OSLogPrivacy = .auto) {
        appendValue(privacy, shownByDefault: true) { format.text(boolean) }
    }
}

// MARK: - Message

/// A log message: literal text with interpolated values.
///
/// Create one by passing a string literal to a `Logger` method. A `String`
/// variable is passed as an interpolated value: `log.info("\(text)")`.
public struct OSLogMessage: ExpressibleByStringInterpolation {
    /// What is written in place of a hidden value.
    static let hiddenValue = "<private>"

    let interpolation: OSLogInterpolation

    public init(stringInterpolation: OSLogInterpolation) {
        interpolation = stringInterpolation
    }

    public init(stringLiteral value: String) {
        var interpolation = OSLogInterpolation(literalCapacity: value.utf8.count, interpolationCount: 0)
        interpolation.appendLiteral(value)
        self.interpolation = interpolation
    }

    /// The message as text. Hidden values are written out when `reveal` is
    /// true and as `<private>` otherwise.
    func render(revealingHiddenValues reveal: Bool) -> String {
        var text = ""
        text.reserveCapacity(interpolation.capacity)
        for segment in interpolation.segments {
            switch segment {
            case .literal(let literal): text += literal
            case .value(let value): text += value.text(revealingHiddenValues: reveal)
            }
        }
        return text
    }
}
