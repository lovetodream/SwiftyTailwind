import Foundation

protocol ChecksumValidating {
    func generateChecksumFrom(_ filePath: String) throws -> String
    func compareChecksum(from filePath: String, to checksum: String) throws -> Bool
}

struct ChecksumValidation: ChecksumValidating {
    func generateChecksumFrom(_ filePath: String) throws -> String {
        let checksumGenerationTask = Process()
        checksumGenerationTask.launchPath = "/usr/bin/shasum"
        checksumGenerationTask.arguments = ["-a", "256", filePath]
        
        let pipe = Pipe()
        checksumGenerationTask.standardOutput = pipe
        checksumGenerationTask.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: String.Encoding.utf8) else {
            throw DownloaderError.errorReadingFilesForChecksumValidation
        }
        
        return output
    }
    
    func compareChecksum(from filePath: String, to checksum: String) throws -> Bool {
        let checksumString = try String(contentsOf: URL(fileURLWithPath: filePath))
        return checksum == checksumString
    }
}
