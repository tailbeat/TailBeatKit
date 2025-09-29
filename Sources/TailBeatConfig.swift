//
//  TailBeatConfig.swift
//  TailBeat
//
//  Created by Stephan Arenswald on 28.09.25.
//

public struct TailBeatConfig {
    public var host: String = "127.0.0.1"
    public var port: UInt16 = 8085
    public var collectStdout: Bool = false
    public var collectStderr: Bool = false
    public var collectOSLogs: Bool = false
}
