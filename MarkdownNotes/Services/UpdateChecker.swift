import Foundation
import AppKit

// MARK: - GitHub Release Models
public struct GitHubAsset: Codable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let size: Int
    public let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case browserDownloadUrl = "browser_download_url"
    }

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

public struct GitHubRelease: Codable, Identifiable, Equatable {
    public let id: Int
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String
    public let publishedAt: String?
    public let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    public var displayTitle: String {
        if let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return "M Notes \(tagName)"
    }

    public var versionString: String {
        var tag = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if tag.lowercased().hasPrefix("v") {
            tag = String(tag.dropFirst())
        }
        return tag
    }

    public var formattedDate: String {
        guard let publishedAt = publishedAt else { return "" }
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: publishedAt) {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: date)
        }
        return publishedAt
    }

    public var downloadAsset: GitHubAsset? {
        assets.first(where: { $0.name.lowercased().hasSuffix(".zip") })
            ?? assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })
            ?? assets.first
    }
}

// MARK: - Update Check State
public enum UpdateCheckState: Equatable {
    case idle
    case checking
    case upToDate(GitHubRelease)
    case updateAvailable(GitHubRelease)
    case failed(String)

    public static func == (lhs: UpdateCheckState, rhs: UpdateCheckState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking):
            return true
        case (.upToDate(let a), .upToDate(let b)):
            return a.id == b.id
        case (.updateAvailable(let a), .updateAvailable(let b)):
            return a.id == b.id
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Update Checker Service
@MainActor
public class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    public static let repoOwner = "Is-Lingling"
    public static let repoName = "M-Notes"
    public static let latestReleaseURLString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
    public static let repoURLString = "https://github.com/\(repoOwner)/\(repoName)"

    @Published public var state: UpdateCheckState = .idle
    @Published public var lastCheckedDate: Date?
    @Published public var isShowingReleaseNotes: Bool = false
    @Published public var selectedReleaseForNotes: GitHubRelease?
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadedZipURL: URL?

    public init() {}

    // Current local version & build
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    public var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public var currentVersionDisplay: String {
        "v\(currentVersion) (Build \(currentBuild))"
    }

    // MARK: - Version Comparison
    public static func compareVersion(remote: String, local: String) -> ComparisonResult {
        let cleanRemote = cleanVersionString(remote)
        let cleanLocal = cleanVersionString(local)

        let remoteParts = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let localParts = cleanLocal.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(remoteParts.count, localParts.count)
        guard maxCount > 0 else { return .orderedSame }

        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return .orderedDescending } // Remote is newer
            if r < l { return .orderedAscending }  // Remote is older
        }
        return .orderedSame
    }

    public static func isRemoteNewer(remote: String, local: String) -> Bool {
        compareVersion(remote: remote, local: local) == .orderedDescending
    }

    private static func cleanVersionString(_ version: String) -> String {
        var v = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.lowercased().hasPrefix("v") {
            v = String(v.dropFirst())
        }
        if let dashIndex = v.firstIndex(of: "-") {
            v = String(v[..<dashIndex])
        }
        if let plusIndex = v.firstIndex(of: "+") {
            v = String(v[..<plusIndex])
        }
        return v
    }

    // MARK: - Check for Updates
    public func checkForUpdates(manual: Bool = true, completion: ((UpdateCheckState) -> Void)? = nil) {
        guard state != .checking else { return }
        state = .checking

        guard let url = URL(string: Self.latestReleaseURLString) else {
            let err = "无效的更新地址"
            self.state = .failed(err)
            completion?(.failed(err))
            return
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15.0)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("M-Notes/\(currentVersion) (macOS)", forHTTPHeaderField: "User-Agent")

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "UpdateChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: "网络响应异常"])
                }

                if httpResponse.statusCode == 404 {
                    throw NSError(domain: "UpdateChecker", code: 404, userInfo: [NSLocalizedDescriptionKey: "GitHub 仓库暂未发布 Release"])
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "UpdateChecker", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器返回错误 (状态码 \(httpResponse.statusCode))"])
                }

                let decoder = JSONDecoder()
                let release = try decoder.decode(GitHubRelease.self, from: data)

                let isNewer = Self.isRemoteNewer(remote: release.tagName, local: self.currentVersion)
                self.lastCheckedDate = Date()

                if isNewer {
                    self.state = .updateAvailable(release)
                } else {
                    self.state = .upToDate(release)
                }
                completion?(self.state)
            } catch {
                let message = error.localizedDescription
                self.state = .failed(message)
                completion?(.failed(message))
            }
        }
    }

    // MARK: - Open Release Notes
    public func showReleaseNotes(for release: GitHubRelease) {
        selectedReleaseForNotes = release
        isShowingReleaseNotes = true
    }

    // MARK: - Open Download
    public func openDownloadPage(for release: GitHubRelease) {
        if let asset = release.downloadAsset, let url = URL(string: asset.browserDownloadUrl) {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    public func openGitHubRepo() {
        if let url = URL(string: Self.repoURLString) {
            NSWorkspace.shared.open(url)
        }
    }
}
