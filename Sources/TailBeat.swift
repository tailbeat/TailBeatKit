//
//  TailBeat.swift
//  tailbeat-swift
//
//  Created by Stephan Arenswald on 28.09.25.
//

public class TailBeat {
    public static let logger: TailBeatLogger = TailBeatLogger()
    public static let userDefaults: TailBeatUserDefaults = TailBeatUserDefaults()
    
    public static func start(configure: ((inout TailBeatConfig) -> Void)? = nil) {
        var config = TailBeatConfig()
        if configure != nil {
            configure!(&config)
        }
        
        Task {
            await TailBeat.logger.start(
                host: config.host,
                port: config.port,
                collectOSLogs: config.collectOSLogs,
                collectStdout: config.collectStdout,
                collectStderr: config.collectStderr
            )
        }
    }
}
