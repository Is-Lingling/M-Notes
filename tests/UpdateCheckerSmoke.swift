import Foundation

@main
struct UpdateCheckerSmoke {
    static func main() throws {
        // 1. Test version comparison
        print("Testing version comparison...")
        precondition(UpdateChecker.compareVersion(remote: "1.0", local: "1.0") == .orderedSame)
        precondition(UpdateChecker.compareVersion(remote: "1.0.0", local: "1.0") == .orderedSame)
        precondition(UpdateChecker.compareVersion(remote: "v1.0.0", local: "1.0") == .orderedSame)
        precondition(UpdateChecker.compareVersion(remote: "V1.0", local: "1.0.0") == .orderedSame)
        precondition(UpdateChecker.compareVersion(remote: "1.0.0-beta.1", local: "1.0") == .orderedSame)

        precondition(UpdateChecker.isRemoteNewer(remote: "1.0.1", local: "1.0") == true)
        precondition(UpdateChecker.isRemoteNewer(remote: "v1.0.1", local: "1.0.0") == true)
        precondition(UpdateChecker.isRemoteNewer(remote: "1.1", local: "1.0.5") == true)
        precondition(UpdateChecker.isRemoteNewer(remote: "v2.0.0", local: "1.9.9") == true)

        precondition(UpdateChecker.isRemoteNewer(remote: "0.9.9", local: "1.0") == false)
        precondition(UpdateChecker.isRemoteNewer(remote: "v1.0.0", local: "1.0") == false)
        precondition(UpdateChecker.isRemoteNewer(remote: "1.0.0", local: "1.0.1") == false)

        // 2. Test JSON decoding
        print("Testing JSON decoding...")
        let sampleJSON = """
        {
          "id": 123456,
          "tag_name": "v1.0.1",
          "name": "M Notes v1.0.1 修复与改进",
          "body": "## 改进说明\\n- 修复分割线字号问题\\n- 增加新特性",
          "html_url": "https://github.com/Is-Lingling/M-Notes/releases/tag/v1.0.1",
          "published_at": "2026-09-12T18:00:00Z",
          "assets": [
            {
              "id": 999,
              "name": "M-Notes-v1.0.1-macOS.zip",
              "size": 4200000,
              "browser_download_url": "https://github.com/Is-Lingling/M-Notes/releases/download/v1.0.1/M-Notes-v1.0.1-macOS.zip"
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let release = try decoder.decode(GitHubRelease.self, from: sampleJSON)
        precondition(release.id == 123456)
        precondition(release.tagName == "v1.0.1")
        precondition(release.versionString == "1.0.1")
        precondition(release.displayTitle == "M Notes v1.0.1 修复与改进")
        precondition(release.assets.count == 1)
        precondition(release.downloadAsset?.name == "M-Notes-v1.0.1-macOS.zip")
        precondition(release.downloadAsset?.browserDownloadUrl.contains("M-Notes-v1.0.1-macOS.zip") == true)

        print("PASS: UpdateCheckerSmoke passed all tests successfully.")
    }
}
