//
//  OptionTests.swift
//  tb
//
//  os_log's layout and number options: `align:`, and the `format:` of whole
//  numbers, floating-point numbers and booleans.
//
//  Every entry of the table was first logged through `os.Logger`; its `text`
//  is what the log store gave back. The tests hold the kit to that text, and
//  hold the table to what `os.Logger` writes for the same call on the system
//  the tests run on.
//

import Foundation
import os
import Testing
@testable import tb

/// One option, or one combination of options, applied to a value.
struct Option: Sendable, CustomTestStringConvertible {
    /// Names the option in test output and in the line it logs.
    let name: String
    /// What `os.Logger` writes for the value when it is public.
    let text: String
    /// What is written for the value when it is hidden: `<private>`, after
    /// whatever os_log makes part of the message rather than of the value.
    let hidden: String
    /// A kit message made of the value alone, with the given privacy.
    let message: @Sendable (tb.OSLogPrivacy) -> tb.OSLogMessage
    /// Logs the value through `os.Logger`, as `option.<name>|<value>|`.
    let reference: @Sendable (os.Logger) -> Void

    init(_ name: String, _ text: String, hidden: String = "<private>",
         _ message: @escaping @Sendable (tb.OSLogPrivacy) -> tb.OSLogMessage,
         _ reference: @escaping @Sendable (os.Logger) -> Void) {
        self.name = name
        self.text = text
        self.hidden = hidden
        self.message = message
        self.reference = reference
    }

    var testDescription: String { name }

    static let all = decimal + hex + octal + alignedWholeNumbers + floatingPoint + booleans + text
}

extension Option {
    /// Whole numbers in base 10: sign and minimum digits.
    static let decimal: [Option] = [
        Option("int.default", "-42",
               { "\(-42, privacy: $0)" },
               { $0.notice("option.int.default|\(-42, privacy: .public)|") }),
        Option("int.decimal", "-42",
               { "\(-42, format: .decimal, privacy: $0)" },
               { $0.notice("option.int.decimal|\(-42, format: .decimal, privacy: .public)|") }),
        Option("int.decimal.sign.pos", "+42",
               { "\(42, format: .decimal(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.int.decimal.sign.pos|\(42, format: .decimal(explicitPositiveSign: true), privacy: .public)|") }),
        Option("int.decimal.sign.neg", "-42",
               { "\(-42, format: .decimal(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.int.decimal.sign.neg|\(-42, format: .decimal(explicitPositiveSign: true), privacy: .public)|") }),
        Option("int.decimal.sign.zero", "+0",
               { "\(0, format: .decimal(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.int.decimal.sign.zero|\(0, format: .decimal(explicitPositiveSign: true), privacy: .public)|") }),
        Option("int.decimal.min4.neg5", "-0005",
               { "\(-5, format: .decimal(explicitPositiveSign: true, minDigits: 4), privacy: $0)" },
               { $0.notice("option.int.decimal.min4.neg5|\(-5, format: .decimal(explicitPositiveSign: true, minDigits: 4), privacy: .public)|") }),
        Option("int.decimal.min4.pos5", "0005",
               { "\(5, format: .decimal(minDigits: 4), privacy: $0)" },
               { $0.notice("option.int.decimal.min4.pos5|\(5, format: .decimal(minDigits: 4), privacy: .public)|") }),
        Option("int.decimal.min4.sign.pos5", "+0005",
               { "\(5, format: .decimal(explicitPositiveSign: true, minDigits: 4), privacy: $0)" },
               { $0.notice("option.int.decimal.min4.sign.pos5|\(5, format: .decimal(explicitPositiveSign: true, minDigits: 4), privacy: .public)|") }),
        Option("int.decimal.min2.big", "123456",
               { "\(123456, format: .decimal(minDigits: 2), privacy: $0)" },
               { $0.notice("option.int.decimal.min2.big|\(123456, format: .decimal(minDigits: 2), privacy: .public)|") }),
        Option("int.decimal.min0.zero", "",
               { "\(0, format: .decimal(minDigits: 0), privacy: $0)" },
               { $0.notice("option.int.decimal.min0.zero|\(0, format: .decimal(minDigits: 0), privacy: .public)|") }),
        Option("int.decimal.min0.one", "1",
               { "\(1, format: .decimal(minDigits: 0), privacy: $0)" },
               { $0.notice("option.int.decimal.min0.one|\(1, format: .decimal(minDigits: 0), privacy: .public)|") }),
        Option("int.decimal.min1.zero", "0",
               { "\(0, format: .decimal(minDigits: 1), privacy: $0)" },
               { $0.notice("option.int.decimal.min1.zero|\(0, format: .decimal(minDigits: 1), privacy: .public)|") }),
        Option("int.decimal.minNeg3", "7",
               { "\(7, format: .decimal(minDigits: -3), privacy: $0)" },
               { $0.notice("option.int.decimal.minNeg3|\(7, format: .decimal(minDigits: -3), privacy: .public)|") }),
        Option("int.decimal.min0.sign.zero", "+",
               { "\(0, format: .decimal(explicitPositiveSign: true, minDigits: 0), privacy: $0)" },
               { $0.notice("option.int.decimal.min0.sign.zero|\(0, format: .decimal(explicitPositiveSign: true, minDigits: 0), privacy: .public)|") }),
        Option("int.min", "-0000009223372036854775808",
               { "\(Int.min, format: .decimal(explicitPositiveSign: true, minDigits: 25), privacy: $0)" },
               { $0.notice("option.int.min|\(Int.min, format: .decimal(explicitPositiveSign: true, minDigits: 25), privacy: .public)|") }),
        Option("int8.min", "-00128",
               { "\(Int8.min, format: .decimal(minDigits: 5), privacy: $0)" },
               { $0.notice("option.int8.min|\(Int8.min, format: .decimal(minDigits: 5), privacy: .public)|") }),
        Option("int16.min", "-32768",
               { "\(Int16.min, format: .decimal(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.int16.min|\(Int16.min, format: .decimal(explicitPositiveSign: true), privacy: .public)|") }),
        Option("int32.max", "+2147483647",
               { "\(Int32.max, format: .decimal(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.int32.max|\(Int32.max, format: .decimal(explicitPositiveSign: true), privacy: .public)|") }),
        Option("int64.min", "-9223372036854775808",
               { "\(Int64.min, format: .decimal(minDigits: 3), privacy: $0)" },
               { $0.notice("option.int64.min|\(Int64.min, format: .decimal(minDigits: 3), privacy: .public)|") }),
        Option("uint.decimal", "42",
               { "\(UInt(42), format: .decimal, privacy: $0)" },
               { $0.notice("option.uint.decimal|\(UInt(42), format: .decimal, privacy: .public)|") }),
        Option("uint.decimal.sign", "+42", hidden: "+<private>",
               { "\(UInt(42), format: .decimal(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.uint.decimal.sign|\(UInt(42), format: .decimal(explicitPositiveSign: true), privacy: .public)|") }),
        Option("uint.decimal.sign.zero", "+0", hidden: "+<private>",
               { "\(UInt(0), format: .decimal(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.uint.decimal.sign.zero|\(UInt(0), format: .decimal(explicitPositiveSign: true), privacy: .public)|") }),
        Option("uint.decimal.sign.min4", "+0042", hidden: "+<private>",
               { "\(UInt(42), format: .decimal(explicitPositiveSign: true, minDigits: 4), privacy: $0)" },
               { $0.notice("option.uint.decimal.sign.min4|\(UInt(42), format: .decimal(explicitPositiveSign: true, minDigits: 4), privacy: .public)|") }),
        Option("uint.max.min25", "0000018446744073709551615",
               { "\(UInt.max, format: .decimal(minDigits: 25), privacy: $0)" },
               { $0.notice("option.uint.max.min25|\(UInt.max, format: .decimal(minDigits: 25), privacy: .public)|") }),
        Option("uint8.decimal.min5", "00255",
               { "\(UInt8.max, format: .decimal(minDigits: 5), privacy: $0)" },
               { $0.notice("option.uint8.decimal.min5|\(UInt8.max, format: .decimal(minDigits: 5), privacy: .public)|") }),
    ]

    /// Base 16, for unsigned numbers.
    static let hex: [Option] = [
        Option("uint.hex", "ff",
               { "\(UInt(255), format: .hex, privacy: $0)" },
               { $0.notice("option.uint.hex|\(UInt(255), format: .hex, privacy: .public)|") }),
        Option("uint.hex.upper", "FF",
               { "\(UInt(255), format: .hex(uppercase: true), privacy: $0)" },
               { $0.notice("option.uint.hex.upper|\(UInt(255), format: .hex(uppercase: true), privacy: .public)|") }),
        Option("uint.hex.prefix", "0xff", hidden: "0x<private>",
               { "\(UInt(255), format: .hex(includePrefix: true), privacy: $0)" },
               { $0.notice("option.uint.hex.prefix|\(UInt(255), format: .hex(includePrefix: true), privacy: .public)|") }),
        Option("uint.hex.prefix.upper", "0xFF", hidden: "0x<private>",
               { "\(UInt(255), format: .hex(includePrefix: true, uppercase: true), privacy: $0)" },
               { $0.notice("option.uint.hex.prefix.upper|\(UInt(255), format: .hex(includePrefix: true, uppercase: true), privacy: .public)|") }),
        Option("uint.hex.sign", "+ff", hidden: "+<private>",
               { "\(UInt(255), format: .hex(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.uint.hex.sign|\(UInt(255), format: .hex(explicitPositiveSign: true), privacy: .public)|") }),
        Option("uint.hex.sign.prefix", "+0xff", hidden: "+0x<private>",
               { "\(UInt(255), format: .hex(explicitPositiveSign: true, includePrefix: true), privacy: $0)" },
               { $0.notice("option.uint.hex.sign.prefix|\(UInt(255), format: .hex(explicitPositiveSign: true, includePrefix: true), privacy: .public)|") }),
        Option("uint.hex.min8", "000000ff",
               { "\(UInt(255), format: .hex(minDigits: 8), privacy: $0)" },
               { $0.notice("option.uint.hex.min8|\(UInt(255), format: .hex(minDigits: 8), privacy: .public)|") }),
        Option("uint.hex.all", "+0x000000FF", hidden: "+0x<private>",
               { "\(UInt(255), format: .hex(explicitPositiveSign: true, includePrefix: true, uppercase: true, minDigits: 8), privacy: $0)" },
               { $0.notice("option.uint.hex.all|\(UInt(255), format: .hex(explicitPositiveSign: true, includePrefix: true, uppercase: true, minDigits: 8), privacy: .public)|") }),
        Option("uint.hex.zero", "0x0", hidden: "0x<private>",
               { "\(UInt(0), format: .hex(includePrefix: true), privacy: $0)" },
               { $0.notice("option.uint.hex.zero|\(UInt(0), format: .hex(includePrefix: true), privacy: .public)|") }),
        Option("uint.hex.zero.min0", "0x", hidden: "0x<private>",
               { "\(UInt(0), format: .hex(includePrefix: true, minDigits: 0), privacy: $0)" },
               { $0.notice("option.uint.hex.zero.min0|\(UInt(0), format: .hex(includePrefix: true, minDigits: 0), privacy: .public)|") }),
        Option("uint.hex.max", "ffffffffffffffff",
               { "\(UInt.max, format: .hex, privacy: $0)" },
               { $0.notice("option.uint.hex.max|\(UInt.max, format: .hex, privacy: .public)|") }),
        Option("uint8.hex", "ab",
               { "\(UInt8(0xAB), format: .hex, privacy: $0)" },
               { $0.notice("option.uint8.hex|\(UInt8(0xAB), format: .hex, privacy: .public)|") }),
        Option("uint8.hex.min4", "00ab",
               { "\(UInt8(0xAB), format: .hex(minDigits: 4), privacy: $0)" },
               { $0.notice("option.uint8.hex.min4|\(UInt8(0xAB), format: .hex(minDigits: 4), privacy: .public)|") }),
        Option("uint16.hex", "0xffff", hidden: "0x<private>",
               { "\(UInt16.max, format: .hex(includePrefix: true), privacy: $0)" },
               { $0.notice("option.uint16.hex|\(UInt16.max, format: .hex(includePrefix: true), privacy: .public)|") }),
        Option("uint32.hex", "FFFFFFFF",
               { "\(UInt32.max, format: .hex(uppercase: true), privacy: $0)" },
               { $0.notice("option.uint32.hex|\(UInt32.max, format: .hex(uppercase: true), privacy: .public)|") }),
        Option("uint64.hex", "0xFFFFFFFFFFFFFFFF", hidden: "0x<private>",
               { "\(UInt64.max, format: .hex(includePrefix: true, uppercase: true), privacy: $0)" },
               { $0.notice("option.uint64.hex|\(UInt64.max, format: .hex(includePrefix: true, uppercase: true), privacy: .public)|") }),
    ]

    /// Base 8, for unsigned numbers.
    static let octal: [Option] = [
        Option("uint.octal", "10",
               { "\(UInt(8), format: .octal, privacy: $0)" },
               { $0.notice("option.uint.octal|\(UInt(8), format: .octal, privacy: .public)|") }),
        Option("uint.octal.prefix", "0o10", hidden: "0o<private>",
               { "\(UInt(8), format: .octal(includePrefix: true), privacy: $0)" },
               { $0.notice("option.uint.octal.prefix|\(UInt(8), format: .octal(includePrefix: true), privacy: .public)|") }),
        Option("uint.octal.upper", "0o10", hidden: "0o<private>",
               { "\(UInt(8), format: .octal(includePrefix: true, uppercase: true), privacy: $0)" },
               { $0.notice("option.uint.octal.upper|\(UInt(8), format: .octal(includePrefix: true, uppercase: true), privacy: .public)|") }),
        Option("uint.octal.sign", "+0o10", hidden: "+0o<private>",
               { "\(UInt(8), format: .octal(explicitPositiveSign: true, includePrefix: true), privacy: $0)" },
               { $0.notice("option.uint.octal.sign|\(UInt(8), format: .octal(explicitPositiveSign: true, includePrefix: true), privacy: .public)|") }),
        Option("uint.octal.min6", "000010",
               { "\(UInt(8), format: .octal(minDigits: 6), privacy: $0)" },
               { $0.notice("option.uint.octal.min6|\(UInt(8), format: .octal(minDigits: 6), privacy: .public)|") }),
        Option("uint.octal.all", "+0o000010", hidden: "+0o<private>",
               { "\(UInt(8), format: .octal(explicitPositiveSign: true, includePrefix: true, uppercase: true, minDigits: 6), privacy: $0)" },
               { $0.notice("option.uint.octal.all|\(UInt(8), format: .octal(explicitPositiveSign: true, includePrefix: true, uppercase: true, minDigits: 6), privacy: .public)|") }),
        Option("uint8.octal", "377",
               { "\(UInt8.max, format: .octal, privacy: $0)" },
               { $0.notice("option.uint8.octal|\(UInt8.max, format: .octal, privacy: .public)|") }),
        Option("uint64.octal", "0o1777777777777777777777", hidden: "0o<private>",
               { "\(UInt64.max, format: .octal(includePrefix: true), privacy: $0)" },
               { $0.notice("option.uint64.octal|\(UInt64.max, format: .octal(includePrefix: true), privacy: .public)|") }),
    ]

    /// Whole numbers in a column.
    static let alignedWholeNumbers: [Option] = [
        Option("int.right8", "     -42",
               { "\(-42, align: .right(columns: 8), privacy: $0)" },
               { $0.notice("option.int.right8|\(-42, align: .right(columns: 8), privacy: .public)|") }),
        Option("int.left8", "-42     ",
               { "\(-42, align: .left(columns: 8), privacy: $0)" },
               { $0.notice("option.int.left8|\(-42, align: .left(columns: 8), privacy: .public)|") }),
        Option("int.none", "-42",
               { "\(-42, align: .none, privacy: $0)" },
               { $0.notice("option.int.none|\(-42, align: .none, privacy: .public)|") }),
        Option("int.right2.wide", "-12345",
               { "\(-12345, align: .right(columns: 2), privacy: $0)" },
               { $0.notice("option.int.right2.wide|\(-12345, align: .right(columns: 2), privacy: .public)|") }),
        Option("int.right0", "-42",
               { "\(-42, align: .right(columns: 0), privacy: $0)" },
               { $0.notice("option.int.right0|\(-42, align: .right(columns: 0), privacy: .public)|") }),
        Option("int.rightNeg8", "-42     ",
               { "\(-42, align: .right(columns: -8), privacy: $0)" },
               { $0.notice("option.int.rightNeg8|\(-42, align: .right(columns: -8), privacy: .public)|") }),
        Option("int.leftNeg8", "-42     ",
               { "\(-42, align: .left(columns: -8), privacy: $0)" },
               { $0.notice("option.int.leftNeg8|\(-42, align: .left(columns: -8), privacy: .public)|") }),
        Option("int.right8.sign.min4", "   +0042",
               { "\(42, format: .decimal(explicitPositiveSign: true, minDigits: 4), align: .right(columns: 8), privacy: $0)" },
               { $0.notice("option.int.right8.sign.min4|\(42, format: .decimal(explicitPositiveSign: true, minDigits: 4), align: .right(columns: 8), privacy: .public)|") }),
        Option("int.left8.sign.min4", "+0042   ",
               { "\(42, format: .decimal(explicitPositiveSign: true, minDigits: 4), align: .left(columns: 8), privacy: $0)" },
               { $0.notice("option.int.left8.sign.min4|\(42, format: .decimal(explicitPositiveSign: true, minDigits: 4), align: .left(columns: 8), privacy: .public)|") }),
        Option("uint.hex.right8.prefix", "0x      ff", hidden: "0x<private>",
               { "\(UInt(255), format: .hex(includePrefix: true), align: .right(columns: 8), privacy: $0)" },
               { $0.notice("option.uint.hex.right8.prefix|\(UInt(255), format: .hex(includePrefix: true), align: .right(columns: 8), privacy: .public)|") }),
        Option("uint.hex.left8.prefix", "0xff      ", hidden: "0x<private>",
               { "\(UInt(255), format: .hex(includePrefix: true), align: .left(columns: 8), privacy: $0)" },
               { $0.notice("option.uint.hex.left8.prefix|\(UInt(255), format: .hex(includePrefix: true), align: .left(columns: 8), privacy: .public)|") }),
        Option("uint.hex.right8.sign.prefix.min4", "+0x    00ff", hidden: "+0x<private>",
               { "\(UInt(255), format: .hex(explicitPositiveSign: true, includePrefix: true, minDigits: 4), align: .right(columns: 8), privacy: $0)" },
               { $0.notice("option.uint.hex.right8.sign.prefix.min4|\(UInt(255), format: .hex(explicitPositiveSign: true, includePrefix: true, minDigits: 4), align: .right(columns: 8), privacy: .public)|") }),
        Option("uint.decimal.right8.sign", "+      42", hidden: "+<private>",
               { "\(UInt(42), format: .decimal(explicitPositiveSign: true), align: .right(columns: 8), privacy: $0)" },
               { $0.notice("option.uint.decimal.right8.sign|\(UInt(42), format: .decimal(explicitPositiveSign: true), align: .right(columns: 8), privacy: .public)|") }),
        Option("uint8.right5", "    7",
               { "\(UInt8(7), align: .right(columns: 5), privacy: $0)" },
               { $0.notice("option.uint8.right5|\(UInt8(7), align: .right(columns: 5), privacy: .public)|") }),
        Option("int64.left22", "-9223372036854775808  ",
               { "\(Int64.min, align: .left(columns: 22), privacy: $0)" },
               { $0.notice("option.int64.left22|\(Int64.min, align: .left(columns: 22), privacy: .public)|") }),
    ]

    /// Floating-point numbers: notation, precision, sign, capitals, column.
    static let floatingPoint: [Option] = [
        Option("double.default", "3.141590",
               { "\(3.14159, privacy: $0)" },
               { $0.notice("option.double.default|\(3.14159, privacy: .public)|") }),
        Option("double.fixed", "3.141590",
               { "\(3.14159, format: .fixed, privacy: $0)" },
               { $0.notice("option.double.fixed|\(3.14159, format: .fixed, privacy: .public)|") }),
        Option("double.fixed.p2", "3.14",
               { "\(3.14159, format: .fixed(precision: 2), privacy: $0)" },
               { $0.notice("option.double.fixed.p2|\(3.14159, format: .fixed(precision: 2), privacy: .public)|") }),
        Option("double.fixed.p0", "3",
               { "\(3.14159, format: .fixed(precision: 0), privacy: $0)" },
               { $0.notice("option.double.fixed.p0|\(3.14159, format: .fixed(precision: 0), privacy: .public)|") }),
        Option("double.fixed.p0.half", "2",
               { "\(2.5, format: .fixed(precision: 0), privacy: $0)" },
               { $0.notice("option.double.fixed.p0.half|\(2.5, format: .fixed(precision: 0), privacy: .public)|") }),
        Option("double.fixed.p10", "3.1415900000",
               { "\(3.14159, format: .fixed(precision: 10), privacy: $0)" },
               { $0.notice("option.double.fixed.p10|\(3.14159, format: .fixed(precision: 10), privacy: .public)|") }),
        Option("double.fixed.pNeg", "3.141590",
               { "\(3.14159, format: .fixed(precision: -2), privacy: $0)" },
               { $0.notice("option.double.fixed.pNeg|\(3.14159, format: .fixed(precision: -2), privacy: .public)|") }),
        Option("double.fixed.sign", "+3.141590",
               { "\(3.14159, format: .fixed(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.double.fixed.sign|\(3.14159, format: .fixed(explicitPositiveSign: true), privacy: .public)|") }),
        Option("double.fixed.sign.neg", "-3.141590",
               { "\(-3.14159, format: .fixed(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.double.fixed.sign.neg|\(-3.14159, format: .fixed(explicitPositiveSign: true), privacy: .public)|") }),
        Option("double.fixed.p2.sign", "+3.14",
               { "\(3.14159, format: .fixed(precision: 2, explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.double.fixed.p2.sign|\(3.14159, format: .fixed(precision: 2, explicitPositiveSign: true), privacy: .public)|") }),
        Option("double.fixed.upper.nan", "NAN",
               { "\(Double.nan, format: .fixed(uppercase: true), privacy: $0)" },
               { $0.notice("option.double.fixed.upper.nan|\(Double.nan, format: .fixed(uppercase: true), privacy: .public)|") }),
        Option("double.fixed.upper.inf", "-INF",
               { "\(-Double.infinity, format: .fixed(uppercase: true), privacy: $0)" },
               { $0.notice("option.double.fixed.upper.inf|\(-Double.infinity, format: .fixed(uppercase: true), privacy: .public)|") }),
        Option("double.fixed.sign.inf", "+inf",
               { "\(Double.infinity, format: .fixed(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.double.fixed.sign.inf|\(Double.infinity, format: .fixed(explicitPositiveSign: true), privacy: .public)|") }),
        Option("double.fixed.sign.nan", "nan",
               { "\(Double.nan, format: .fixed(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.double.fixed.sign.nan|\(Double.nan, format: .fixed(explicitPositiveSign: true), privacy: .public)|") }),
        Option("double.fixed.negzero", "-0.0",
               { "\(-0.0, format: .fixed(precision: 1), privacy: $0)" },
               { $0.notice("option.double.fixed.negzero|\(-0.0, format: .fixed(precision: 1), privacy: .public)|") }),
        Option("double.exp", "3.141590e+04",
               { "\(31415.9, format: .exponential, privacy: $0)" },
               { $0.notice("option.double.exp|\(31415.9, format: .exponential, privacy: .public)|") }),
        Option("double.exp.p2", "3.14e+04",
               { "\(31415.9, format: .exponential(precision: 2), privacy: $0)" },
               { $0.notice("option.double.exp.p2|\(31415.9, format: .exponential(precision: 2), privacy: .public)|") }),
        Option("double.exp.p0", "3e+04",
               { "\(31415.9, format: .exponential(precision: 0), privacy: $0)" },
               { $0.notice("option.double.exp.p0|\(31415.9, format: .exponential(precision: 0), privacy: .public)|") }),
        Option("double.exp.upper", "3.141590E+04",
               { "\(31415.9, format: .exponential(uppercase: true), privacy: $0)" },
               { $0.notice("option.double.exp.upper|\(31415.9, format: .exponential(uppercase: true), privacy: .public)|") }),
        Option("double.exp.sign", "+3.141590e+04",
               { "\(31415.9, format: .exponential(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.double.exp.sign|\(31415.9, format: .exponential(explicitPositiveSign: true), privacy: .public)|") }),
        Option("double.exp.all", "+3.142E-04",
               { "\(0.000314159, format: .exponential(precision: 3, explicitPositiveSign: true, uppercase: true), privacy: $0)" },
               { $0.notice("option.double.exp.all|\(0.000314159, format: .exponential(precision: 3, explicitPositiveSign: true, uppercase: true), privacy: .public)|") }),
        Option("double.exp.zero", "0.000000e+00",
               { "\(0.0, format: .exponential, privacy: $0)" },
               { $0.notice("option.double.exp.zero|\(0.0, format: .exponential, privacy: .public)|") }),
        Option("double.hybrid", "0.5",
               { "\(0.5, format: .hybrid, privacy: $0)" },
               { $0.notice("option.double.hybrid|\(0.5, format: .hybrid, privacy: .public)|") }),
        Option("double.hybrid.big", "3.14159e+07",
               { "\(31415926.5, format: .hybrid, privacy: $0)" },
               { $0.notice("option.double.hybrid.big|\(31415926.5, format: .hybrid, privacy: .public)|") }),
        Option("double.hybrid.small", "3.14159e-05",
               { "\(0.0000314159, format: .hybrid, privacy: $0)" },
               { $0.notice("option.double.hybrid.small|\(0.0000314159, format: .hybrid, privacy: .public)|") }),
        Option("double.hybrid.p3", "3.14e+04",
               { "\(31415.9, format: .hybrid(precision: 3), privacy: $0)" },
               { $0.notice("option.double.hybrid.p3|\(31415.9, format: .hybrid(precision: 3), privacy: .public)|") }),
        Option("double.hybrid.p0", "3e+04",
               { "\(31415.9, format: .hybrid(precision: 0), privacy: $0)" },
               { $0.notice("option.double.hybrid.p0|\(31415.9, format: .hybrid(precision: 0), privacy: .public)|") }),
        Option("double.hybrid.upper", "3.14159E-05",
               { "\(0.0000314159, format: .hybrid(uppercase: true), privacy: $0)" },
               { $0.notice("option.double.hybrid.upper|\(0.0000314159, format: .hybrid(uppercase: true), privacy: .public)|") }),
        Option("double.hybrid.sign", "+100",
               { "\(100.0, format: .hybrid(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.double.hybrid.sign|\(100.0, format: .hybrid(explicitPositiveSign: true), privacy: .public)|") }),
        Option("double.hybrid.all", "+1E+20",
               { "\(1e20, format: .hybrid(precision: 4, explicitPositiveSign: true, uppercase: true), privacy: $0)" },
               { $0.notice("option.double.hybrid.all|\(1e20, format: .hybrid(precision: 4, explicitPositiveSign: true, uppercase: true), privacy: .public)|") }),
        Option("double.hex", "0x1p-1",
               { "\(0.5, format: .hex, privacy: $0)" },
               { $0.notice("option.double.hex|\(0.5, format: .hex, privacy: .public)|") }),
        Option("double.hex.pi", "0x1.921f9f01b866ep+1",
               { "\(3.14159, format: .hex, privacy: $0)" },
               { $0.notice("option.double.hex.pi|\(3.14159, format: .hex, privacy: .public)|") }),
        Option("double.hex.upper", "0X1.921F9F01B866EP+1",
               { "\(3.14159, format: .hex(uppercase: true), privacy: $0)" },
               { $0.notice("option.double.hex.upper|\(3.14159, format: .hex(uppercase: true), privacy: .public)|") }),
        Option("double.hex.sign", "+0x1.921f9f01b866ep+1",
               { "\(3.14159, format: .hex(explicitPositiveSign: true), privacy: $0)" },
               { $0.notice("option.double.hex.sign|\(3.14159, format: .hex(explicitPositiveSign: true), privacy: .public)|") }),
        Option("double.hex.zero", "0x0p+0",
               { "\(0.0, format: .hex, privacy: $0)" },
               { $0.notice("option.double.hex.zero|\(0.0, format: .hex, privacy: .public)|") }),
        Option("double.hex.nan", "NAN",
               { "\(Double.nan, format: .hex(uppercase: true), privacy: $0)" },
               { $0.notice("option.double.hex.nan|\(Double.nan, format: .hex(uppercase: true), privacy: .public)|") }),
        Option("float.default", "2.500000",
               { "\(Float(2.5), privacy: $0)" },
               { $0.notice("option.float.default|\(Float(2.5), privacy: .public)|") }),
        Option("float.fixed.p2", "3.14",
               { "\(Float(3.14159), format: .fixed(precision: 2), privacy: $0)" },
               { $0.notice("option.float.fixed.p2|\(Float(3.14159), format: .fixed(precision: 2), privacy: .public)|") }),
        Option("float.fixed.p10", "0.1000000015",
               { "\(Float(0.1), format: .fixed(precision: 10), privacy: $0)" },
               { $0.notice("option.float.fixed.p10|\(Float(0.1), format: .fixed(precision: 10), privacy: .public)|") }),
        Option("float.exp", "3.141590e+04",
               { "\(Float(31415.9), format: .exponential, privacy: $0)" },
               { $0.notice("option.float.exp|\(Float(31415.9), format: .exponential, privacy: .public)|") }),
        Option("float.hybrid", "0.1",
               { "\(Float(0.1), format: .hybrid, privacy: $0)" },
               { $0.notice("option.float.hybrid|\(Float(0.1), format: .hybrid, privacy: .public)|") }),
        Option("float.hex", "0x1.99999ap-4",
               { "\(Float(0.1), format: .hex, privacy: $0)" },
               { $0.notice("option.float.hex|\(Float(0.1), format: .hex, privacy: .public)|") }),
        Option("double.right12", "    3.141590",
               { "\(3.14159, align: .right(columns: 12), privacy: $0)" },
               { $0.notice("option.double.right12|\(3.14159, align: .right(columns: 12), privacy: .public)|") }),
        Option("double.left12", "3.141590    ",
               { "\(3.14159, align: .left(columns: 12), privacy: $0)" },
               { $0.notice("option.double.left12|\(3.14159, align: .left(columns: 12), privacy: .public)|") }),
        Option("double.fixed.p2.right12.sign", "       +3.14",
               { "\(3.14159, format: .fixed(precision: 2, explicitPositiveSign: true), align: .right(columns: 12), privacy: $0)" },
               { $0.notice("option.double.fixed.p2.right12.sign|\(3.14159, format: .fixed(precision: 2, explicitPositiveSign: true), align: .right(columns: 12), privacy: .public)|") }),
        Option("double.exp.left14", "3.141590e+04  ",
               { "\(31415.9, format: .exponential, align: .left(columns: 14), privacy: $0)" },
               { $0.notice("option.double.exp.left14|\(31415.9, format: .exponential, align: .left(columns: 14), privacy: .public)|") }),
        Option("double.nan.right6", "   nan",
               { "\(Double.nan, align: .right(columns: 6), privacy: $0)" },
               { $0.notice("option.double.nan.right6|\(Double.nan, align: .right(columns: 6), privacy: .public)|") }),
        Option("float.right12", "    2.500000",
               { "\(Float(2.5), align: .right(columns: 12), privacy: $0)" },
               { $0.notice("option.float.right12|\(Float(2.5), align: .right(columns: 12), privacy: .public)|") }),
    ]

    /// Booleans.
    static let booleans: [Option] = [
        Option("bool.default.true", "true",
               { "\(true, privacy: $0)" },
               { $0.notice("option.bool.default.true|\(true, privacy: .public)|") }),
        Option("bool.default.false", "false",
               { "\(false, privacy: $0)" },
               { $0.notice("option.bool.default.false|\(false, privacy: .public)|") }),
        Option("bool.truth.true", "true",
               { "\(true, format: .truth, privacy: $0)" },
               { $0.notice("option.bool.truth.true|\(true, format: .truth, privacy: .public)|") }),
        Option("bool.truth.false", "false",
               { "\(false, format: .truth, privacy: $0)" },
               { $0.notice("option.bool.truth.false|\(false, format: .truth, privacy: .public)|") }),
        Option("bool.answer.true", "YES",
               { "\(true, format: .answer, privacy: $0)" },
               { $0.notice("option.bool.answer.true|\(true, format: .answer, privacy: .public)|") }),
        Option("bool.answer.false", "NO",
               { "\(false, format: .answer, privacy: $0)" },
               { $0.notice("option.bool.answer.false|\(false, format: .answer, privacy: .public)|") }),
    ]

    /// Text in a column. The width counts UTF-8 bytes.
    static let text: [Option] = [
        Option("string.none", "ab",
               { "\("ab", align: .none, privacy: $0)" },
               { $0.notice("option.string.none|\("ab", align: .none, privacy: .public)|") }),
        Option("string.right6", "    ab",
               { "\("ab", align: .right(columns: 6), privacy: $0)" },
               { $0.notice("option.string.right6|\("ab", align: .right(columns: 6), privacy: .public)|") }),
        Option("string.left6", "ab    ",
               { "\("ab", align: .left(columns: 6), privacy: $0)" },
               { $0.notice("option.string.left6|\("ab", align: .left(columns: 6), privacy: .public)|") }),
        Option("string.right1", "ab",
               { "\("ab", align: .right(columns: 1), privacy: $0)" },
               { $0.notice("option.string.right1|\("ab", align: .right(columns: 1), privacy: .public)|") }),
        Option("string.right0", "ab",
               { "\("ab", align: .right(columns: 0), privacy: $0)" },
               { $0.notice("option.string.right0|\("ab", align: .right(columns: 0), privacy: .public)|") }),
        Option("string.rightNeg6", "ab    ",
               { "\("ab", align: .right(columns: -6), privacy: $0)" },
               { $0.notice("option.string.rightNeg6|\("ab", align: .right(columns: -6), privacy: .public)|") }),
        Option("string.leftNeg6", "ab    ",
               { "\("ab", align: .left(columns: -6), privacy: $0)" },
               { $0.notice("option.string.leftNeg6|\("ab", align: .left(columns: -6), privacy: .public)|") }),
        Option("string.empty.right4", "    ",
               { "\("", align: .right(columns: 4), privacy: $0)" },
               { $0.notice("option.string.empty.right4|\("", align: .right(columns: 4), privacy: .public)|") }),
        Option("string.umlaut.right8", " Grüße",
               { "\("Grüße", align: .right(columns: 8), privacy: $0)" },
               { $0.notice("option.string.umlaut.right8|\("Grüße", align: .right(columns: 8), privacy: .public)|") }),
        Option("string.umlaut.left8", "Grüße ",
               { "\("Grüße", align: .left(columns: 8), privacy: $0)" },
               { $0.notice("option.string.umlaut.left8|\("Grüße", align: .left(columns: 8), privacy: .public)|") }),
        Option("string.emoji.right8", "  a👋b",
               { "\("a👋b", align: .right(columns: 8), privacy: $0)" },
               { $0.notice("option.string.emoji.right8|\("a👋b", align: .right(columns: 8), privacy: .public)|") }),
        Option("string.cjk.right8", "  日本",
               { "\("日本", align: .right(columns: 8), privacy: $0)" },
               { $0.notice("option.string.cjk.right8|\("日本", align: .right(columns: 8), privacy: .public)|") }),
        Option("string.combining.right8", "    éx",
               { "\("e\u{301}x", align: .right(columns: 8), privacy: $0)" },
               { $0.notice("option.string.combining.right8|\("e\u{301}x", align: .right(columns: 8), privacy: .public)|") }),
        Option("type.right12", "         Int",
               { "\(Int.self, align: .right(columns: 12), privacy: $0)" },
               { $0.notice("option.type.right12|\(Int.self, align: .right(columns: 12), privacy: .public)|") }),
        Option("type.left12", "Int         ",
               { "\(Int.self, align: .left(columns: 12), privacy: $0)" },
               { $0.notice("option.type.left12|\(Int.self, align: .left(columns: 12), privacy: .public)|") }),
        Option("describable.right12", "   file:///tmp",
               { "\(URL(fileURLWithPath: "/tmp"), align: .right(columns: 14), privacy: $0)" },
               { $0.notice("option.describable.right12|\(URL(fileURLWithPath: "/tmp"), align: .right(columns: 14), privacy: .public)|") }),
        Option("describable.left12", "file:///tmp   ",
               { "\(URL(fileURLWithPath: "/tmp"), align: .left(columns: 14), privacy: $0)" },
               { $0.notice("option.describable.left12|\(URL(fileURLWithPath: "/tmp"), align: .left(columns: 14), privacy: .public)|") }),
        Option("substring.right6", "   Jup",
               { "\("Jupiter".prefix(3), align: .right(columns: 6), privacy: $0)" },
               { $0.notice("option.substring.right6|\("Jupiter".prefix(3), align: .right(columns: 6), privacy: .public)|") }),
    ]
}

// MARK: - The kit against the table, the table against os.Logger

@Suite struct OptionTests {
    /// Both builds, from one test run: `revealingHiddenValues` is what a debug
    /// build passes as `true` and every other build as `false`.
    @Test(arguments: Option.all)
    func kitWritesWhatOSLoggerWrote(option: Option) {
        // A shown value reads the same in every build.
        #expect(option.message(.public).render(revealingHiddenValues: true) == option.text)
        #expect(option.message(.public).render(revealingHiddenValues: false) == option.text)
        // A hidden value keeps its options where the build reveals it, and is
        // not laid out at all where it does not.
        #expect(option.message(.private).render(revealingHiddenValues: true) == option.text)
        #expect(option.message(.private).render(revealingHiddenValues: false) == option.hidden)
    }

    @Test(arguments: Option.all)
    func osLoggerWritesWhatTheTableSays(option: Option) throws {
        #expect(try #require(try Recorded.option(option.name)) == option.text)
    }

    /// The options take values that are only known when the call runs.
    @Test func optionsTakeRunTimeValues() {
        let digits = 4, columns = 8, precision = 1
        let message: tb.OSLogMessage = """
            \(7, format: .decimal(minDigits: digits), align: .right(columns: columns)) \
            \(UInt(255), format: .hex(minDigits: digits + 2), align: .left(columns: columns)) \
            \(2.55, format: .fixed(precision: precision), align: .right(columns: columns - 2))|
            """
        #expect(message.render(revealingHiddenValues: false) == "    0007 0000ff      2.5|")
    }

    /// Past what os_log would store of one message, a width stops growing.
    @Test func absurdWidthsAreBounded() {
        let wide: tb.OSLogMessage = "\("x", align: .right(columns: .max))\("y", align: .left(columns: .min))"
        let zeros: tb.OSLogMessage = "\(7, format: .decimal(minDigits: .max))\(1.5, format: .fixed(precision: .max))"
        #expect(wide.render(revealingHiddenValues: true).utf8.count == 2 * 1024)
        #expect(zeros.render(revealingHiddenValues: true).utf8.count == 1024 + 2 + 1024)
    }
}
