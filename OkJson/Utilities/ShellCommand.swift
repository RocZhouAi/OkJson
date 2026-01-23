//  ShellCommand.swift
//  OkJson
//
//  Shell command execution utilities
//

import Foundation

/// Execute shell commands from Swift
enum ShellCommand {
    /// Execute a shell command and return output
    static func execute(_ command: String, arguments: [String] = []) -> Result<String, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return .success(output)
            } else {
                return .failure(NSError(domain: "ShellCommand", code: Int(process.terminationStatus)))
            }
        } catch {
            return .failure(error)
        }
    }

    /// Execute using bash (for commands with pipes, redirects, etc.)
    static func executeBash(_ command: String) -> Result<String, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return .success(output)
            } else {
                return .failure(NSError(domain: "ShellCommand", code: Int(process.terminationStatus)))
            }
        } catch {
            return .failure(error)
        }
    }

    /// Quick example: Get current git branch
    static func getCurrentGitBranch() -> String? {
        switch executeBash("git branch --show-current") {
        case .success(let output):
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        case .failure:
            return nil
        }
    }

    /// Quick example: Get file count in directory
    static func getFileCount(at path: String) -> Int? {
        switch executeBash("find \"\(path)\" -type f | wc -l") {
        case .success(let output):
            return Int(output.trimmingCharacters(in: .whitespacesAndNewlines))
        case .failure:
            return nil
        }
    }
}
