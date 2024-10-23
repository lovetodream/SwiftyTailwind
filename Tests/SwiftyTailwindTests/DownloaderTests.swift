import Foundation
import XCTest

@testable import SwiftyTailwind

final class DownloaderTests: XCTestCase {
    var subject: Downloader!
    
    override func setUp() {
        super.setUp()
        subject = Downloader()
    }
    
    override func tearDown() {
        subject = nil
        super.tearDown()
    }
    func test_download() async throws {
        let tmpDir = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)").path()
        do {
            _ = try await subject.download(version: .latest, directory: tmpDir)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        try FileManager.default.removeItem(atPath: tmpDir)
    }
}
