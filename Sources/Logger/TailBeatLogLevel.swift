//
//  TailBeatLogLevel.swift
//  TailBeatSwift
//
//  Created by Stephan Arenswald on 28.09.25.
//

public enum TailBeatLogLevel: Int, Codable, Sendable {
    case Trace = 0
    case Debug = 1
    case Info = 2
    case Warning = 3
    case Error = 4
    case Fatal = 5
}

