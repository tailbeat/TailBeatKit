//
//  AppEnvironment.swift
//  TailBeatKit
//
//  Created by Stephan Arenswald on 10.10.25.
//

public struct AppEnvironment: Codable, Equatable, Sendable {
    let schema: Int = 1
    
    public let language: String?
    public let appearance: String?
    
    public init(language: String?, appearance: String?) {
        self.language = language
        self.appearance = appearance
    }
}
