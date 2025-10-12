//
//  TailBeat+Logger.swift
//  TailBeatKit
//
//  Created by Stephan Arenswald on 13.10.25.
//

/// This extension contains all log methods that are available from TailBeat itself. If you want to
/// support another framework, you can add another extension and implement the required
/// protocol.
extension TailBeat {
    public func log(level: TailBeatLogLevel = .Debug,
             category: String = "",
             _ message: String,
             context: [String: String]? = nil,
             file: String = #file,
             function: String = #function,
             line: Int = #line,
             extras: [TailBeatExtras] = []
    ) {
        let event = TailBeatEvent(
            timestamp: .now,
            type: .Log,
            level: .Debug,
            category: "",
            message: message,
            context: nil,
            file: file.description,
            function: function.description,
            line: Int(line)
        )
        net.yield(event: event)
    }
    
    public func log(level: TailBeatLogLevel = .Debug,
             category: String = "",
             _ bool: Bool,
             context: [String: String]? = nil,
             file: String = #file,
             function: String = #function,
             line: Int = #line,
             extras: [TailBeatExtras] = []
    ) {
        let event = TailBeatEvent(
            timestamp: .now,
            type: .Log,
            level: .Debug,
            category: "",
            message: bool.description,
            context: nil,
            file: file.description,
            function: function.description,
            line: Int(line)
        )
        net.yield(event: event)
    }
}
