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
    public let id: UUID = UUID()
    
    public let timestamp: Date
    public let type: TailBeatEventType
    public let level: TailBeatLogLevel
    public let category: String
    public let message: String
    public let context: [String: String]?
    public let file: String?
    public let function: String?
    public let line: Int?
    public let extras: [TailBeatExtras]
    public let source: TailBeatLogSource
    
    init(timestamp: Date, type: TailBeatEventType, level: TailBeatLogLevel, category: String, message: String, context: [String : String]?, file: String, function: String, line: Int, extras: [TailBeatExtras] = [], source: TailBeatLogSource = .Log) {
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
