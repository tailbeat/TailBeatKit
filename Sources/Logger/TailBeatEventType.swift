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

enum TailBeatEventType: Int, Codable {
    case Log = 0
    case AppStarted = 1
    case AppExited = 2
}