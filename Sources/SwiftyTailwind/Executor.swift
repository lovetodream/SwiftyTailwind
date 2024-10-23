import Foundation
import Logging

/**
 Executing describes the interface to run system processes. Executors are used by `SwiftyTailwind` to run the Tailwind executable using system processes.
 */
protocol Executing {
    /**
     Runs a system process using the given executable path and arguments.
     - Parameters:
        - executablePath: The absolute path to the executable to run.
        - directory: The working directory from to run the executable.
        - arguments: The arguments to pass to the executable.
     */
    func run(executablePath: String,
             directory: String,
             arguments: [String]) async throws
}

class Executor: Executing {
    
    let logger: Logger
    
    /**
     Creates a new instance of `Executor`
     */
    init() {
        self.logger = Logger(label: "io.tuist.SwiftyTailwind.Executor")
    }
    
    func run(executablePath: String, directory: String, arguments: [String]) async throws {
        return try await Task {
            let arguments = ([executablePath] + arguments).joined(separator: " ")
            self.logger.info("Tailwind: \(arguments)")
            try shellOut(command: "cd \(directory) && \(arguments)")
        }.value
    }
}
