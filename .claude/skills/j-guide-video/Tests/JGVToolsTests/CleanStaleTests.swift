// jgv clean --stale が、jgv の印の無いものを消さないことのテスト (swift test)
import Foundation
import Testing
@testable import JGVTools

@Suite(.serialized) struct CleanStaleTests {
  @Test func keepsUnmarkedFolders() throws {
    let fm = FileManager.default
    let cache = fm.temporaryDirectory.appendingPathComponent("jgv-cache-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: cache) }
    let projects = cache.appendingPathComponent("projects")
    // 印の無いもの (消してはいけない)
    let foreign = [projects.appendingPathComponent("random-folder"), projects.appendingPathComponent("0123456789ab"),
                   cache.appendingPathComponent("build-mystuff"), cache.appendingPathComponent("build-0123456789ab")]
    // 印があり、プロジェクトがもう無いもの (消してよい)
    let orphan = projects.appendingPathComponent("abcdefabcdef")
    for d in foreign + [orphan] { try fm.createDirectory(at: d, withIntermediateDirectories: true) }
    try "/nonexistent/project/\(UUID().uuidString)\n".write(to: orphan.appendingPathComponent("project-path"), atomically: true, encoding: .utf8)

    setenv("J_GUIDE_VIDEO_CACHE", cache.path, 1)
    defer { unsetenv("J_GUIDE_VIDEO_CACHE") }
    try Project.clean(["--stale"])

    for d in foreign { #expect(fm.fileExists(atPath: d.path), "\(d.lastPathComponent) が消えた") }
    #expect(!fm.fileExists(atPath: orphan.path))
  }
}
