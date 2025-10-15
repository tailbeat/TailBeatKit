//
//  LanguageChange.swift
//  TailBeatKit
//
//  Created by Stephan Arenswald on 15.10.25.
//

import Foundation

class LanguageControl {
    func change(to: String) {
        UserDefaults.standard.set([to], forKey: "AppleLanguages")
        restartApp()
    }
    
    private func restartApp() {
        let bundlePath = Bundle.main.bundlePath

        let command = """
        sleep 0.1; open "\(bundlePath)"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]

        do {
            try task.run()
        } catch {
            print("Error restarting app:", error)
        }

        exit(0)
    }
}
