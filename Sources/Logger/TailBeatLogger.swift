//
//  TailBeatLogger.swift
//  tailbeat-swift
//
//  Created by Stephan Arenswald on 28.09.25.
//

import Foundation
import Network
import OSLog
import UniformTypeIdentifiers

public final actor TailBeatLogger {
    public static let shared = TailBeatLogger()
    
    private let logStream: LogStream
//    private let networkService: NetworkService?
    private var osLogSink: OSLogSink?
    private var stdSink: StdSink?
    
    init() {
        logStream = LogStream()
//        networkService = networkService
    }
    
    public func start(
        host: String = "127.0.0.1",
        port: UInt16 = 8085,
        collectOSLogs: Bool = false,
        collectStdout: Bool = false,
        collectStderr: Bool = false
    ) async {
#if DEBUG
        await logStream.connect(host: host, port: port)
        await logStream.start()
        
        if collectStdout && collectStderr {
            stdSink = StdSink { line in
                self.yield(
                    source: .Stdout,
                    timestamp: .now,
                    type: .Log,
                    level: .Debug,
                    category: "",
                    message: line,
                    context: nil,
                    file: "",
                    function: "",
                    line: 0,
                    extras: []
                )
            }
        }
        
        if collectOSLogs {
            do {
                osLogSink = try OSLogSink { entry in
                    let level: TailBeatLogLevel = {
                        switch entry.level {
                        case .debug:   return .Debug
                        case .info:    return .Info
                        case .notice:  return .Info
                        case .error:   return .Error
                        case .fault:   return .Fatal
                        case .undefined: return .Debug
                        @unknown default: return .Debug
                        }
                    }()
                    
                    self.yield(
                        source: .OSLog,
                        timestamp: entry.date,
                        type: .Log,
                        level: level,
                        category: entry.category,
                        message: entry.composedMessage,
                        context: nil,
                        file: "",
                        function: "",
                        line: 0,
                        extras: []
                    )
                }
            } catch {
                print("Failed to start OSLog polling: \(error)")
            }
        }
        
        logAppStart()
#endif
    }
    
    public nonisolated func log(level: TailBeatLogLevel = .Debug,
             category: String = "",
             _ message: String,
             context: [String: String]? = nil,
             file: String = #file,
             function: String = #function,
             line: Int = #line,
             extras: [TailBeatExtras] = []
    ) {
        yield(
            source: .Log,
            timestamp: .now,
            type: .Log,
            level: level,
            category: category,
            message: message,
            context: context,
            file: file,
            function: function,
            line: line,
            extras: extras
        )
    }
    
    func logAppStart() {
        let appName = Bundle.main.appName
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "Unknown Bundle Identifier"
        let appVersion = Bundle.main.appVersionLong
        
        yield(
            source: .Log,
            timestamp: .now,
            type: .AppStarted,
            level: .Info,
            category: "",
            message: "\(appName) started (\(appVersion)) (\(bundleIdentifier))",
            context: nil,
            file: "",
            function: "",
            line: 0,
            extras: []
        )
    }
    
    private nonisolated func yield(
        source: TailBeatLogSource,
        timestamp: Date,
        type: TailBeatEventType,
        level: TailBeatLogLevel,
        category: String,
        message: String,
        context: [String: String]?,
        file: String,
        function: String,
        line: Int,
        extras: [TailBeatExtras]
    ) {
#if DEBUG
        var file = file
        var function = function
        var line = line
        
        if source != .Log {
            file = ""
            function = ""
            line = 0
        }
        
        let log = TailBeatEvent(
            timestamp: Date(),
            type: type,
            level: level,
            category: category,
            message: message,
            context: context,
            file: file,
            function: function,
            line: line,
            extras: extras,
            source: source
        )
        
        logStream.yield(event: log)
#endif
    }
}
