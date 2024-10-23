import XCTest
@testable import SwiftyTailwind

final class SwiftyTailwindTests: XCTestCase {
    func test_initialize() async throws {
        let tmpDir = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)").path()
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        do {
            // Given
            let subject = SwiftyTailwind(directory: tmpDir)
            
            // When
            try await subject.initialize(directory: tmpDir, options: .full)
            
            // Then
            let tailwindConfigPath = tmpDir.appending("/tailwind.config.js")
            XCTAssertTrue(FileManager.default.fileExists(atPath: tailwindConfigPath))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        try FileManager.default.removeItem(atPath: tmpDir)
    }
    
    func test_run() async throws {
        let tmpDir = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)").path()
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        do {
            // Given
            let subject = SwiftyTailwind(directory: tmpDir)
            
            let inputCSSPath = tmpDir.appending("/input.css")
            let inputCSSContent = """
            @tailwind components;
            
            p {
                @apply font-bold;
            }
            """
            let outputCSSPath = tmpDir.appending("/output.css")

            try inputCSSContent.write(to: URL(string: inputCSSPath)!, atomically: false, encoding: .utf8)

            // When
            try await subject.run(input: inputCSSPath, output: outputCSSPath, directory: tmpDir)
            
            // Then
            XCTAssertTrue(FileManager.default.fileExists(atPath: outputCSSPath))
            let content = try String(contentsOf: XCTUnwrap(URL(filePath: outputCSSPath)), encoding: .utf8)
            XCTAssertTrue(content.contains("font-weight: 700"))
        } catch {
            XCTFail("Unexpected error: \(error) \(error.localizedDescription)")
        }
        try FileManager.default.removeItem(atPath: tmpDir)
    }
}
