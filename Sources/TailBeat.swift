//
//  TailBeat.swift
//  tailbeat-swift
//
//  Created by Stephan Arenswald on 28.09.25.
//

@MainActor
class TailBeat {
    public static let logger = TailBeatLogger()
    public static let userDefaults = TailBeatUserDefaults()
    
    public static func start() {
        logger.start()
    }
}
