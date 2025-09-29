//
//  TailBeatLogSource.swift
//  TailBeat
//
//  Created by Stephan Arenswald on 29.09.25.
//


import Foundation
import Network
import OSLog
import UniformTypeIdentifiers

public enum TailBeatLogSource: Int, Codable, Sendable {
    case Stdout = 0
    case Stderr = 1
    case OSLog = 2
    case TailBeat = 3
}
