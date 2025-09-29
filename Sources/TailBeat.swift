//
//  TailBeat.swift
//  tailbeat-swift
//
//  Created by Stephan Arenswald on 28.09.25.
//

public class TailBeat {
    nonisolated(unsafe) public static let logger = TailBeatLogger()
    public static let userDefaults = TailBeatUserDefaults()
    
    public static func start(configure: ((inout TailBeatConfig) -> Void)? = nil) -> TailBeat {
        let _self = TailBeat()
        
        var config = TailBeatConfig()
        if configure != nil {
            configure!(&config)
        }
        
        logger.start(
            host: config.host,
            port: config.port,
            collectOSLogs: config.collectOSLogs,
            collectStdout: config.collectStdout,
            collectStderr: config.collectStderr
        )
        
        return _self
    }
}
