//
//  TailBeatEventType.swift
//  TailBeat
//
//  Created by Stephan Arenswald on 29.09.25.
//


import Foundation
import Network
import OSLog
import UniformTypeIdentifiers

public enum TailBeatEventType: Int, Codable, Sendable {
    case Log = 0
    case AppStarted = 1
    case AppExited = 2
}
