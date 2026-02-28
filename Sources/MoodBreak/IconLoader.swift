import AppKit
import Foundation

enum IconLoader {
    static func loadStatusIcon() -> NSImage? {
        for url in candidateURLs(fileName: "cat", ext: "pdf") {
            if let image = NSImage(contentsOf: url) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                return image
            }
        }

        for url in candidateURLs(fileName: "cat", ext: "svg") {
            if let image = NSImage(contentsOf: url) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                return image
            }
        }

        return nil
    }

    private static func candidateURLs(fileName: String, ext: String) -> [URL] {
        var urls: [URL] = []

        if let envRoot = ProcessInfo.processInfo.environment["MOODBREAK_ASSET_ROOT"] {
            urls.append(URL(fileURLWithPath: envRoot).appendingPathComponent("\(fileName).\(ext)"))
        }

        urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("\(fileName).\(ext)"))

        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        urls.append(sourceRoot.appendingPathComponent("\(fileName).\(ext)"))

        return deduplicated(urls)
    }

    private static func deduplicated(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []

        for url in urls {
            let key = url.path
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            result.append(url)
        }

        return result
    }
}
