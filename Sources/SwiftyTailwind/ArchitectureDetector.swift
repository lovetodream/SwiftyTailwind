import Foundation

public enum CpuArchitecture: String, Hashable  {
    case aarch64   = "aarch64"
    case arm64   = "arm64"
    case armv7   = "armv7"
    case x86_64   = "x86_64"
    
    var tailwindValue: String {
        switch self {
        case .arm64, .aarch64: return "arm64"
        case .armv7: return "armv7"
        case .x86_64: return "x64"
        }
    }
}

/**
 A protocol that declares an interface to obtain the CPU architecture of the environment in which the program is running.
 */
protocol ArchitectureDetecting {
    /**
        It returns the architecture if it can be obtained and nil otherwise.
     */
    func architecture() -> CpuArchitecture?
}

class ArchitectureDetector: ArchitectureDetecting {
    func architecture() -> CpuArchitecture? {
        let output = try? shellOut(to: "uname", arguments: ["-m"])
        return CpuArchitecture(rawValue: output ?? "")
    }
}
