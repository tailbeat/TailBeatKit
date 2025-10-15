//
//  TailBeat.swift
//  TailBeatKit
//
//  Created by Stephan Arenswald on 13.10.25.
//

import AppKit
import Foundation

public enum TailBeat {
    
    // Start TailBeat
    public static func start(
        host: String = "127.0.0.1",
        port: UInt16 = 8085
    ) {
        #if DEBUG
        Task {
            await TailBeatCore.shared.start(host: host, port: port)
        }
        TailBeat.logger.logAppStart()
        #endif
    }
    
    public static func stop() {
        #if DEBUG
        Task {
            await TailBeatCore.shared.stop()
        }
        #endif
    }
    
    public static var logger: TailBeatLogger2 { TailBeatLogger2.shared }
    
    @MainActor
    public static var ui: TailBeatUI { TailBeatUI.shared }
}

public final actor TailBeatLogger2 {
    static let shared: TailBeatLogger2 = .init()
    
    public nonisolated func log(
        level: TailBeatLogLevel = .Debug,
        category: String = "",
        _ message: String,
        context: [String: String]? = nil,
        file: String = #filePath,
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
        Task {
            await TailBeatCore.shared.enqueueLog(event)
        }
    }
    
    public nonisolated func log(level: TailBeatLogLevel = .Debug,
             category: String = "",
             _ bool: Bool,
             context: [String: String]? = nil,
             file: String = #filePath,
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
        Task {
            await TailBeatCore.shared.enqueueLog(event)
        }
    }
    
    internal nonisolated func logAppStart() {
        let appName = Bundle.main.appName
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "Unknown Bundle Identifier"
        let appVersion = Bundle.main.appVersionLong
        
        let event = TailBeatEvent(
            timestamp: .now,
            type: .AppStarted,
            level: .Info,
            category: "",
            message: "\(appName) started (\(appVersion)) (\(bundleIdentifier))",
            context: nil,
            file: "",
            function: "",
            line: 0
        )
        Task {
            await TailBeatCore.shared.enqueueLog(event)
        }
    }
}
