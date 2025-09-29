//
//  TailBeatExtras.swift
//  TailBeat
//
//  Created by Stephan Arenswald on 29.09.25.
//


import Foundation
import Network
import OSLog
import UniformTypeIdentifiers

public enum TailBeatExtras: Int, Codable, Sendable {
    case Highlight = 0
    case NewStart = 1
    case StackTrace = 2
}
