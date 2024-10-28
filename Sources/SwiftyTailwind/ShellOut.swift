/**
 *  ShellOut
 *  Copyright (c) John Sundell 2017
 *  Licensed under the MIT license. See LICENSE file.
 */

import Foundation
import Dispatch

// MARK: - API

@discardableResult public func shellOut(
    command: String,
    process: Process = .init(),
    outputHandle: FileHandle? = nil,
    errorHandle: FileHandle? = nil,
    environment: [String : String]? = nil
) throws -> String {
    return try process.launchBash(
        with: command,
        outputHandle: outputHandle,
        errorHandle: errorHandle,
        environment: environment
    )
}

/**
 *  Run a shell command using Bash
 *
 *  - parameter command: The command to run
 *  - parameter arguments: The arguments to pass to the command
 *  - parameter path: The path to execute the commands at (defaults to current folder)
 *  - parameter process: Which process to use to perform the command (default: A new one)
 *  - parameter outputHandle: Any `FileHandle` that any output (STDOUT) should be redirected to
 *              (at the moment this is only supported on macOS)
 *  - parameter errorHandle: Any `FileHandle` that any error output (STDERR) should be redirected to
 *              (at the moment this is only supported on macOS)
 *  - parameter environment: The environment for the command.
 *
 *  - returns: The output of running the command
 *  - throws: `ShellOutError` in case the command couldn't be performed, or it returned an error
 *
 *  Use this function to "shell out" in a Swift script or command line tool
 *  For example: `shellOut(to: "mkdir", arguments: ["NewFolder"], at: "~/CurrentFolder")`
 */
@discardableResult public func shellOut(
    to command: String,
    arguments: [String] = [],
    at path: String = ".",
    process: Process = .init(),
    outputHandle: FileHandle? = nil,
    errorHandle: FileHandle? = nil,
    environment: [String : String]? = nil
) throws -> String {
    let command = "cd \(path.escapingSpaces) && \(command) \(arguments.joined(separator: " "))"

    return try process.launchBash(
        with: command,
        outputHandle: outputHandle,
        errorHandle: errorHandle,
        environment: environment
    )
}

/**
 *  Run a series of shell commands using Bash
 *
 *  - parameter commands: The commands to run
 *  - parameter path: The path to execute the commands at (defaults to current folder)
 *  - parameter process: Which process to use to perform the command (default: A new one)
 *  - parameter outputHandle: Any `FileHandle` that any output (STDOUT) should be redirected to
 *              (at the moment this is only supported on macOS)
 *  - parameter errorHandle: Any `FileHandle` that any error output (STDERR) should be redirected to
 *              (at the moment this is only supported on macOS)
 *  - parameter environment: The environment for the command.
 *
 *  - returns: The output of running the command
 *  - throws: `ShellOutError` in case the command couldn't be performed, or it returned an error
 *
 *  Use this function to "shell out" in a Swift script or command line tool
 *  For example: `shellOut(to: ["mkdir NewFolder", "cd NewFolder"], at: "~/CurrentFolder")`
 */
@discardableResult public func shellOut(
    to commands: [String],
    at path: String = ".",
    process: Process = .init(),
    outputHandle: FileHandle? = nil,
    errorHandle: FileHandle? = nil,
    environment: [String : String]? = nil
) throws -> String {
    let command = commands.joined(separator: " && ")

    return try shellOut(
        to: command,
        at: path,
        process: process,
        outputHandle: outputHandle,
        errorHandle: errorHandle,
        environment: environment
    )
}

/**
 *  Run a pre-defined shell command using Bash
 *
 *  - parameter command: The command to run
 *  - parameter path: The path to execute the commands at (defaults to current folder)
 *  - parameter process: Which process to use to perform the command (default: A new one)
 *  - parameter outputHandle: Any `FileHandle` that any output (STDOUT) should be redirected to
 *  - parameter errorHandle: Any `FileHandle` that any error output (STDERR) should be redirected to
 *  - parameter environment: The environment for the command.
 *
 *  - returns: The output of running the command
 *  - throws: `ShellOutError` in case the command couldn't be performed, or it returned an error
 *
 *  Use this function to "shell out" in a Swift script or command line tool
 *  For example: `shellOut(to: .gitCommit(message: "Commit"), at: "~/CurrentFolder")`
 *
 *  See `ShellOutCommand` for more info.
 */
@discardableResult public func shellOut(
    to command: ShellOutCommand,
    at path: String = ".",
    process: Process = .init(),
    outputHandle: FileHandle? = nil,
    errorHandle: FileHandle? = nil,
    environment: [String : String]? = nil
) throws -> String {
    return try shellOut(
        to: command.string,
        at: path,
        process: process,
        outputHandle: outputHandle,
        errorHandle: errorHandle,
        environment: environment
    )
}

/// Structure used to pre-define commands for use with ShellOut
public struct ShellOutCommand {
    /// The string that makes up the command that should be run on the command line
    public var string: String

    /// Initialize a value using a string that makes up the underlying command
    public init(string: String) {
        self.string = string
    }
}

/// File system commands
public extension ShellOutCommand {
    /// Create a folder with a given name
    static func createFolder(named name: String) -> ShellOutCommand {
        let command = "mkdir".appending(argument: name)
        return ShellOutCommand(string: command)
    }

    /// Create a file with a given name and contents (will overwrite any existing file with the same name)
    static func createFile(named name: String, contents: String) -> ShellOutCommand {
        var command = "echo"
        command.append(argument: contents)
        command.append(" > ")
        command.append(argument: name)

        return ShellOutCommand(string: command)
    }

    /// Move a file from one path to another
    static func moveFile(from originPath: String, to targetPath: String) -> ShellOutCommand {
        let command = "mv".appending(argument: originPath)
            .appending(argument: targetPath)

        return ShellOutCommand(string: command)
    }

    /// Copy a file from one path to another
    static func copyFile(from originPath: String, to targetPath: String) -> ShellOutCommand {
        let command = "cp".appending(argument: originPath)
            .appending(argument: targetPath)

        return ShellOutCommand(string: command)
    }

    /// Remove a file
    static func removeFile(from path: String, arguments: [String] = ["-f"]) -> ShellOutCommand {
        let command = "rm".appending(arguments: arguments)
            .appending(argument: path)

        return ShellOutCommand(string: command)
    }

    /// Open a file using its designated application
    static func openFile(at path: String) -> ShellOutCommand {
        let command = "open".appending(argument: path)
        return ShellOutCommand(string: command)
    }

    /// Read a file as a string
    static func readFile(at path: String) -> ShellOutCommand {
        let command = "cat".appending(argument: path)
        return ShellOutCommand(string: command)
    }

    /// Create a symlink at a given path, to a given target
    static func createSymlink(to targetPath: String, at linkPath: String) -> ShellOutCommand {
        let command = "ln -s".appending(argument: targetPath)
            .appending(argument: linkPath)

        return ShellOutCommand(string: command)
    }

    /// Expand a symlink at a given path, returning its target path
    static func expandSymlink(at path: String) -> ShellOutCommand {
        let command = "readlink".appending(argument: path)
        return ShellOutCommand(string: command)
    }
}

/// Error type thrown by the `shellOut()` function, in case the given command failed
public struct ShellOutError: Swift.Error {
    /// The termination status of the command that was run
    public let terminationStatus: Int32
    /// The error message as a UTF8 string, as returned through `STDERR`
    public var message: String { return errorData.shellOutput() }
    /// The raw error buffer data, as returned through `STDERR`
    public let errorData: Data
    /// The raw output buffer data, as retuned through `STDOUT`
    public let outputData: Data
    /// The output of the command as a UTF8 string, as returned through `STDOUT`
    public var output: String { return outputData.shellOutput() }
}

extension ShellOutError: CustomStringConvertible {
    public var description: String {
        return """
               ShellOut encountered an error
               Status code: \(terminationStatus)
               Message: "\(message)"
               Output: "\(output)"
               """
    }
}

extension ShellOutError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}

// MARK: - Private

private extension Process {
    @discardableResult func launchBash(with command: String, outputHandle: FileHandle? = nil, errorHandle: FileHandle? = nil, environment: [String : String]? = nil) throws -> String {
        launchPath = "/bin/bash"
        arguments = ["-c", command]

        if let environment = environment {
            self.environment = environment
        }

        // Because FileHandle's readabilityHandler might be called from a
        // different queue from the calling queue, avoid a data race by
        // protecting reads and writes to outputData and errorData on
        // a single dispatch queue.
        let outputQueue = DispatchQueue(label: "bash-output-queue")

        var outputData = Data()
        var errorData = Data()

        let outputPipe = Pipe()
        standardOutput = outputPipe

        let errorPipe = Pipe()
        standardError = errorPipe

#if !os(Linux)
        outputPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            outputQueue.async {
                outputData.append(data)
                outputHandle?.write(data)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            outputQueue.async {
                errorData.append(data)
                errorHandle?.write(data)
            }
        }
#endif

        launch()

#if os(Linux)
        outputQueue.sync {
            outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        }
#endif

        waitUntilExit()

        if let handle = outputHandle, !handle.isStandard {
            handle.closeFile()
        }

        if let handle = errorHandle, !handle.isStandard {
            handle.closeFile()
        }

#if !os(Linux)
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
#endif

        // Block until all writes have occurred to outputData and errorData,
        // and then read the data back out.
        return try outputQueue.sync {
            if terminationStatus != 0 {
                throw ShellOutError(
                    terminationStatus: terminationStatus,
                    errorData: errorData,
                    outputData: outputData
                )
            }

            return outputData.shellOutput()
        }
    }
}

private extension FileHandle {
    var isStandard: Bool {
        return self === FileHandle.standardOutput ||
        self === FileHandle.standardError ||
        self === FileHandle.standardInput
    }
}

private extension Data {
    func shellOutput() -> String {
        guard let output = String(data: self, encoding: .utf8) else {
            return ""
        }

        guard !output.hasSuffix("\n") else {
            let endIndex = output.index(before: output.endIndex)
            return String(output[..<endIndex])
        }

        return output

    }
}

private extension String {
    var escapingSpaces: String {
        return replacingOccurrences(of: " ", with: "\\ ")
    }

    func appending(argument: String) -> String {
        return "\(self) \"\(argument)\""
    }

    func appending(arguments: [String]) -> String {
        return appending(argument: arguments.joined(separator: "\" \""))
    }

    mutating func append(argument: String) {
        self = appending(argument: argument)
    }

    mutating func append(arguments: [String]) {
        self = appending(arguments: arguments)
    }
}