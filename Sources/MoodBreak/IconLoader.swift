import AppKit
import Foundation

enum IconLoader {
    static func loadStatusIcon() -> NSImage? {
        for url in candidateURLs(fileName: "cat", ext: "pdf") {
            if let image = loadTemplateImage(at: url) {
                DebugLogger.log("Icon", "Loaded cat.pdf from \(url.path)")
                return image
            }
        }

        for url in candidateURLs(fileName: "cat", ext: "svg") {
            if let image = loadTemplateImage(at: url) {
                DebugLogger.log("Icon", "Loaded cat.svg from \(url.path)")
                return image
            }
        }

        DebugLogger.log("Icon", "Failed to load icon asset, fallback to MB")
        return nil
    }

    private static func loadTemplateImage(at url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    private static func candidateURLs(fileName: String, ext: String) -> [URL] {
        var urls: [URL] = []
        let plainFileName = "\(fileName).\(ext)"
        let iconRelativePath = "Icons/\(plainFileName)"

        if let envRoot = ProcessInfo.processInfo.environment["MOODBREAK_ASSET_ROOT"] {
            let envRootURL = URL(fileURLWithPath: envRoot)
            urls.append(envRootURL.appendingPathComponent(iconRelativePath))
            urls.append(envRootURL.appendingPathComponent(plainFileName))
        }

        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent(iconRelativePath))
            urls.append(resourceURL.appendingPathComponent(plainFileName))
        }

        let mainBundleURL = Bundle.main.bundleURL
        urls.append(mainBundleURL.appendingPathComponent("MoodBreak_MoodBreak.bundle/\(iconRelativePath)"))
        urls.append(mainBundleURL.appendingPathComponent("MoodBreak_MoodBreak.bundle/\(plainFileName)"))
        urls.append(mainBundleURL.appendingPathComponent(iconRelativePath))
        urls.append(mainBundleURL.appendingPathComponent(plainFileName))

        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        urls.append(currentDirectoryURL.appendingPathComponent(iconRelativePath))
        urls.append(currentDirectoryURL.appendingPathComponent(plainFileName))

        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        urls.append(projectRoot.appendingPathComponent("Sources/MoodBreak/Resources/\(iconRelativePath)"))
        urls.append(projectRoot.appendingPathComponent("Sources/MoodBreak/Resources/\(plainFileName)"))
        urls.append(projectRoot.appendingPathComponent(iconRelativePath))
        urls.append(projectRoot.appendingPathComponent(plainFileName))

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
