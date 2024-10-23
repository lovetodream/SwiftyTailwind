import Foundation
import Logging
import AsyncHTTPClient
import NIOCore
import NIOFoundationCompat

/*
 An enum that represents the various errors that the `Downloader` can throw.
 */
enum DownloaderError: LocalizedError {
    /**
     This error is thrown when the binary name cannot be determined.
     */
    case unableToDetermineBinaryName
    case checksumIsIncorrect
    case errorReadingFilesForChecksumValidation
    
    var errorDescription: String? {
        switch self {
        case .unableToDetermineBinaryName:
            return "We were unable to determine Tailwind's binary name for this architecture and OS."
        case .checksumIsIncorrect:
            return "We attempted 5 downloads of the binary but the checksum never matched."
        case .errorReadingFilesForChecksumValidation:
            return "We were unable to read files for checksum validation."
        }
    }
}

protocol Downloading {
    /**
     It downloads the latest version of Tailwind in a default directory.
     */
    func download() async throws -> String
    /**
     It downloads the given version of Tailwind in the given directory.
     */
    func download(version: TailwindVersion, directory: String, numRetries: Int) async throws -> String
}

class Downloader: Downloading {
    let architectureDetector: ArchitectureDetecting
    let logger: Logger
    
    /**
     Returns the default directory where Tailwind binaries should be downloaded.
     */
    static func defaultDownloadDirectory() -> String {
        return URL.temporaryDirectory.appending(component: "SwiftyTailwind").absoluteString
    }
    
    static let sha256FileName: String = "sha256sums.txt"
    static let checksumValidator: ChecksumValidating = ChecksumValidation()
    
    init(architectureDetector: ArchitectureDetecting = ArchitectureDetector()) {
        self.architectureDetector = architectureDetector
        self.logger = Logger(label: "io.tuist.SwiftyTailwind.Downloader")
    }
    
    func download() async throws -> String {
        try await download(version: .latest, directory: Downloader.defaultDownloadDirectory())
    }
    
    func download(version: TailwindVersion,
                  directory: String,
                  numRetries: Int = 0) async throws -> String
    {
        guard let binaryName = binaryName() else {
            throw DownloaderError.unableToDetermineBinaryName
        }
        let expectedVersion = try await versionToDownload(version: version)
        let binaryPath = directory.appending(pathComponents: [expectedVersion, binaryName])
        if FileManager.default.fileExists(atPath: binaryPath) { return binaryPath }
        try await downloadBinary(name: binaryName, version: expectedVersion, to: binaryPath)
        let checksumPath = directory.appending(pathComponents: [expectedVersion, Self.sha256FileName])
        try await downloadChecksumFile(version: expectedVersion, into: checksumPath)
        do {
            let binaryChecksum = try Self.checksumValidator.generateChecksumFrom(binaryPath)
            guard try Self.checksumValidator.compareChecksum(from: checksumPath, to: binaryChecksum) else {
                
                if numRetries < 5 {
                    // retry download
                    logger.error("Checksum validation failed. Attempt #\(numRetries + 1) to retry download...")
                    return try await download(version: version, directory: directory, numRetries: numRetries + 1)
                } else {
                    throw DownloaderError.checksumIsIncorrect
                }
            }
        } catch {
            if error.localizedDescription == DownloaderError.checksumIsIncorrect.localizedDescription {
                throw error
            } else {
                logger.error("Error accessing checksum file or binary for checksum validation. Error: \(error.localizedDescription)")
            }
        }
        return binaryPath
    }
    
    private func downloadBinary(name: String, version: String, to downloadPath: String) async throws {
        let parentDirectory = downloadPath.split(separator: "/", omittingEmptySubsequences: false).dropLast().joined(separator: "/")
        if !FileManager.default.fileExists(atPath: parentDirectory, isDirectory: nil) {
            logger.debug("Creating directory \(parentDirectory)")
            try FileManager.default.createDirectory(atPath: parentDirectory, withIntermediateDirectories: true)
        }
        let url = "https://github.com/tailwindlabs/tailwindcss/releases/download/\(version)/\(name)"
        logger.debug("Downloading binary \(name) from version \(version)...")
        let client = HTTPClient()
        let request = try HTTPClient.Request(url: url)
        let delegate = try FileDownloadDelegate(path: downloadPath, reportProgress: { [weak self] in
            if let totalBytes = $0.totalBytes {
                self?.logger.debug("Total bytes count: \(totalBytes)")
            }
            self?.logger.debug("Downloaded \($0.receivedBytes) bytes so far")
        })
        do {
            try await withCheckedThrowingContinuation { continuation in
                client.execute(request: request, delegate: delegate).futureResult.whenComplete { result in
                    switch result {
                    case .success(_):
                        _ = try? shellOut(command: "chmod +x \(downloadPath)")
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            try await client.shutdown()
            throw error
        }
        try await client.shutdown()
    }
    
    private func downloadChecksumFile(version: String, into downloadPath: String) async throws {
        try await downloadBinary(name: Self.sha256FileName, version: version, to: downloadPath)
    }
    
    /**
     Returns the version that should be downloaded.
     */
    private func versionToDownload(version: TailwindVersion) async throws -> String {
        switch version {
        case .fixed(let rawVersion):
            if rawVersion.starts(with: "v") {
                return rawVersion
            } else {
                /**
                 Releases on GitHub are prefixed with "v" so we need to include it.
                 */
                return "v\(rawVersion)"
            }
        case .latest: return try await latestVersion()
        }
    }
    
    /**
     It obtains the latest available release from GitHub releases
     */
    private func latestVersion() async throws -> String {
        let latestReleaseURL = "https://api.github.com/repos/tailwindlabs/tailwindcss/releases/latest"
        logger.debug("Getting the latest Tailwind version from \(latestReleaseURL)")
        
        let httpClient = HTTPClient()
        
        var tagName: String!
        do {
            var request = HTTPClientRequest(url: latestReleaseURL)
            request.headers.add(name: "Content-Type", value: "application/json")
            request.headers.add(name: "User-Agent", value: "io.tuist.SwiftyTailwind")
            let response = try await httpClient.execute(request, timeout: .seconds(30))
            let body = try await response.body.collect(upTo: 1024 * 1024)
            let json = try! JSONSerialization.jsonObject(with: Data(buffer: body)) as! [String: Any]
            tagName = json["tag_name"] as! String
            logger.debug("The latest Tailwind version available is \(tagName!)")
        } catch {
            try await httpClient.shutdown()
            throw error
        }
        
        try await httpClient.shutdown()
        
        return tagName
    }
    
    /**
        It returns the name of the artifact that we should pull from the GitHub release. The artifact follows the convention: tailwindcss-{os}-{arch}
     */
    private func binaryName() -> String? {
        guard let architecture = architectureDetector.architecture()?.tailwindValue else {
            return nil
        }
        var os: String!
        var ext: String! = ""
        #if os(Windows)
        os = "windows"
        ext = ".exe"
        #elseif os(Linux)
        os = "linux"
        #else
        os = "macos"
        #endif
        return "tailwindcss-\(os as String)-\(architecture)\(ext as String)"
    }
}

private extension String {
    func appending(pathComponents: [String]) -> String {
        let joined = pathComponents.joined(by: "/")
        if self.last == "/" {
            return self + joined
        } else {
            return self + "/" + joined
        }
    }
}
