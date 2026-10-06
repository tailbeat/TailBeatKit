//
//  OSLoggerReference
//
//  The reference for `KitDemo`: the calls of `EveryOption.swift`, which is the
//  very file `KitDemo` compiles, through Apple's `os.Logger`.
//
//      swift run OSLoggerReference [subsystem]
//
//  The lines carry the category "os".
//

import os

let subsystem = CommandLine.arguments.dropFirst().first ?? "app.tb.demo"
let log = Logger(subsystem: subsystem, category: "os")

everyOption(log)
everyPrivacyOption(log)
