//
//  TailBeatEvent.swift
//  TailBeat
//
//  Created by Stephan Arenswald on 29.09.25.
//


import Foundation
import Network
import OSLog
import UniformTypeIdentifiers

public struct TailBeatEvent: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    
    let timestamp: Date
    let type: TailBeatEventType
    let level: TailBeatLogLevel
    let category: String
    let message: String
    let context: [String: String]?
    let file: String
    let function: String
    let line: Int
    let extras: [TailBeatExtras]
    let source: TailBeatLogSource
    
    init(timestamp: Date, type: TailBeatEventType, level: TailBeatLogLevel, category: String, message: String, context: [String : String]?, file: String, function: String, line: Int, extras: [TailBeatExtras] = [], source: TailBeatLogSource = .TailBeat) {
        self.timestamp = timestamp
        self.type = type
        self.level = level
        self.category = category
        self.message = message
        self.context = context
        self.file = file
        self.function = function
        self.line = line
        self.extras = extras
        self.source = source
    }
    
    private enum CodingKeys: String, CodingKey {
        case timestamp, type, level, category, message, context, file, function, line, extras, source
    }
}
