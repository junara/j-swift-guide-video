// JGVCore の解析・検証の単体テスト (swift test)
import CoreGraphics
import Foundation
import Testing
@testable import JGVCore

@Suite struct JSONTests {
  @Test func parsesNestedValues() throws {
    let j = try JSON.parse(#"{"a": [1, 2.5, -3e2], "b": {"c": "xあ"}, "d": null, "e": true}"#)
    #expect(j["a"]?.array?.count == 3)
    #expect(j["a"]?.array?[2].double == -300)
    #expect(j["b"]?["c"]?.string == "xあ")
    #expect(j["e"]?.bool == true)
  }

  @Test func rejectsInfiniteNumbers() {
    #expect(throws: (any Error).self) { try JSON.parse(#"{"fps": 1e999}"#) }
  }

  @Test func rejectsTooDeepNesting() {
    #expect(throws: (any Error).self) { try JSON.parse(String(repeating: "[", count: 1000) + String(repeating: "]", count: 1000)) }
    #expect((try? JSON.parse(String(repeating: "[", count: 100) + String(repeating: "]", count: 100))) != nil)
  }
}

@Suite struct TimelineTests {
  func timeline(_ extra: String) throws -> Timeline {
    try Timeline(JSON.parse(#"{"fps": 30, "width": 1920, "height": 1080, "durationInSeconds": 10"# + extra + "}"))
  }

  @Test func acceptsNormalTimelines() throws {
    #expect(try timeline("").invalidReason == nil)
    #expect(try Timeline(JSON.parse(#"{"fps": 29.97, "width": 1080, "height": 1920, "durationInSeconds": 0}"#)).invalidReason == nil)
    #expect(try timeline(#", "scenes": [{"index": 0, "visual": {"type": "Step01"}, "start": 0, "end": 10}], "lines": [{"audio": "narration/apple-0123456789abcdef.wav", "start": 1, "duration": 2}]"#).invalidReason == nil)
  }

  @Test(arguments: [
    #"{"fps": 0, "width": 1920, "height": 1080}"#,
    #"{"fps": 241, "width": 1920, "height": 1080}"#,
    #"{"fps": 30, "width": 15, "height": 1080}"#,
    #"{"fps": 30, "width": 8193, "height": 1080}"#,
    #"{"fps": 30, "width": 1920, "height": 1080, "durationInSeconds": 7201}"#,
  ])
  func rejectsBadSizes(_ text: String) throws {
    #expect(try Timeline(JSON.parse(text)).invalidReason != nil)
  }

  @Test func rejectsPathsInNames() throws {
    #expect(try timeline(#", "scenes": [{"index": 0, "visual": {"type": "../../Secret"}}]"#).invalidReason != nil)
    #expect(try timeline(#", "lines": [{"audio": "../../outside.wav", "start": 0, "duration": 1}]"#).invalidReason != nil)
    #expect(try timeline(#", "lines": [{"audio": "narration/a.wav", "start": 1e300, "duration": 1}]"#).invalidReason != nil)
  }

  @Test func visualNames() {
    #expect(Safety.isVisualName("Prepare"))
    #expect(Safety.isVisualName("Step01_b"))
    #expect(!Safety.isVisualName("prepare"))
    #expect(!Safety.isVisualName("../X"))
    #expect(!Safety.isVisualName("A-B"))
  }
}

@Suite struct AnimationTests {
  @Test func interpolateZeroWidthRange() {
    let o = InterpolateOptions(left: .clamp, right: .clamp)
    #expect(interpolate(5, [0, 0], [10, 20], o) == 20)
    #expect(interpolate(-1, [0, 0], [10, 20], o) == 10)
    #expect(!interpolate(0, [0, 0], [10, 20]).isNaN)
  }

  @Test func interpolateClamps() {
    let o = InterpolateOptions(left: .clamp, right: .clamp)
    #expect(interpolate(15, [0, 10], [0, 100], o) == 100)
    #expect(interpolate(5, [0, 10], [0, 100], o) == 50)
  }
}

@Suite struct SVGPathTests {
  @Test func missingArgumentDoesNotEatNextCommand() {
    // M の y が欠けていても、次の V は V として読む (前の版は V を飛ばして 20 を L の x にしていた)
    let p = SVGPath.parse("M10V20")
    #expect(p.currentPoint == CGPoint(x: 10, y: 20))
  }

  @Test func relativeAndShorthandNumbers() {
    let p = SVGPath.parse("m10 10l.5.5-1e1 0")
    #expect(abs(p.currentPoint.x - 0.5) < 1e-9)
    #expect(abs(p.currentPoint.y - 10.5) < 1e-9)
  }
}

@Suite struct SafetyTests {
  @Test func detectsSymlinksUnderRoot() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("jgv-test-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: root) }
    let outside = root.appendingPathComponent("outside")
    let proj = root.appendingPathComponent("proj")
    try fm.createDirectory(at: outside, withIntermediateDirectories: true)
    try fm.createDirectory(at: proj, withIntermediateDirectories: true)
    try fm.createSymbolicLink(at: proj.appendingPathComponent("out"), withDestinationURL: outside)
    #expect(throws: (any Error).self) { try Safety.requireNoSymlinks(under: proj, proj.appendingPathComponent("out/snapshots")) }
    #expect(throws: Never.self) { try Safety.requireNoSymlinks(under: proj, proj.appendingPathComponent(".jgv/narration")) }
  }
}

@Suite struct NonFiniteInputTests {
  @Test func survivesInfiniteArcValues() {
    // 範囲を超える数 (inf) が円弧に入っても落ちない
    _ = SVGPath.parse("M0 0 A 1e999 10 0 0 1 10 0")
    _ = SVGPath.parse("M0 0 A 1e300 1e300 0 0 1 1e300 0")
    #expect(SVGDocument.length("1e999") == nil)
    #expect(SVGDocument.numbers("1 1e999 2") == [1, 2])
  }

  @Test func springClampsHugeFrames() {
    #expect(spring(frame: 1e20, fps: 30).isFinite)
    #expect(spring(frame: .nan, fps: 30).isFinite)
  }
}

@Suite struct TimelineShapeTests {
  func timeline(_ extra: String) throws -> Timeline {
    try Timeline(JSON.parse(#"{"fps": 30, "width": 1920, "height": 1080, "durationInSeconds": 10"# + extra + "}"))
  }

  @Test func rejectsOddAndFractionalSizes() throws {
    #expect(try Timeline(JSON.parse(#"{"fps": 30, "width": 1921, "height": 1080}"#)).invalidReason != nil)
    #expect(try Timeline(JSON.parse(#"{"fps": 30, "width": 1920, "height": 1080.5}"#)).invalidReason != nil)
    #expect(try Timeline(JSON.parse(#"{"fps": 30, "width": 1080, "height": 1920}"#)).invalidReason == nil)
  }

  @Test func sceneIndexMustMatchPosition() throws {
    // ビルドのターゲット名 (Scene<N>) と --scene=N が同じ工程を指すように、index は並びの順だけ
    #expect(try timeline(#", "scenes": [{"index": 3, "start": 0, "end": 10}]"#).invalidReason != nil)
    #expect(try timeline(#", "scenes": [{"index": 0, "start": 0, "end": 5}, {"index": 0, "start": 5, "end": 10}]"#).invalidReason != nil)
    #expect(try timeline(#", "scenes": [{"index": 0, "start": 0, "end": 5}, {"index": 1, "start": 5, "end": 10}]"#).invalidReason == nil)
    #expect(try timeline(#", "scenes": [{"index": 0, "start": 0, "end": 10}], "lines": [{"sceneIndex": 4, "start": 0, "duration": 1}]"#).invalidReason != nil)
  }
}

@Suite struct SVGSafetyTests {
  func svg(_ body: String) -> Data { Data("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'>\(body)</svg>".utf8) }

  @Test func rejectsTooDeepNesting() throws {
    // 解析も描画も入れ子の数だけ再帰するので、スタックがあふれる前に止める
    let deep = String(repeating: "<g>", count: 5000) + "<rect width='1' height='1'/>" + String(repeating: "</g>", count: 5000)
    #expect(throws: (any Error).self) { try SVGDocument.parse(svg(deep)) }
    let ok = String(repeating: "<g>", count: 10) + "<rect width='1' height='1'/>" + String(repeating: "</g>", count: 10)
    #expect(throws: Never.self) { try SVGDocument.parse(svg(ok)) }
  }

  @Test(.timeLimit(.minutes(1))) func hugeDashOffsetsDoNotHang() throws {
    // CoreGraphics の破線は ずらし ÷ 周期 に比例して時間がかかる。そのまま渡すと 1 回の描画が終わらない
    let doc = try SVGDocument.parse(svg("""
      <path d='M0 0L50 50' stroke='red' stroke-dasharray='5' stroke-dashoffset='1e15'/>
      <path d='M0 0L50 50' stroke='red' stroke-dasharray='1e308' stroke-dashoffset='-1e308'/>
      <path d='M0 0L1e9 0' stroke='red' stroke-dasharray='1'/>
      """))
    let cg = Bitmap.context(width: 100, height: 100)
    RenderContext(cg: cg, frame: 0, config: VideoConfig(fps: 30, width: 100, height: 100, durationInFrames: 1)).run { doc.draw() }
  }
}

@Suite struct AudioFileTests {
  /// 8 ビット・モノラルの wav (ヘッダーと frames バイトの無音)
  func wav(rate: UInt32, frames: Int) throws -> URL {
    var d = Data()
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
    d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + frames))
    d.append(contentsOf: Array("WAVE".utf8))
    d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(rate); u32(rate); u16(1); u16(8)
    d.append(contentsOf: Array("data".utf8)); u32(UInt32(frames))
    d.append(Data(repeating: 128, count: frames))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("jgv-audio-\(UUID().uuidString).wav")
    try d.write(to: url)
    return url
  }

  @Test func readsOrdinaryFiles() throws {
    let url = try wav(rate: 8000, frames: 8000)
    defer { try? FileManager.default.removeItem(at: url) }
    let samples = try AudioFile.readMono(url, sampleRate: 48000)
    #expect(abs(samples.count - 48000) < 4800)
  }

  @Test func rejectsFilesThatWouldExplode() throws {
    // サンプルレートが極端に低いファイルは、48kHz にすると数 GB になる・フレーム数が UInt32 に入らず落ちる
    let url = try wav(rate: 100, frames: 100_000)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(throws: (any Error).self) { try AudioFile.readMono(url, sampleRate: 48000) }
  }

  @Test func rejectsNonRegularFiles() throws {
    // フォルダ・FIFO などは開かない (FIFO は読み終わらずに止まったままになる)
    #expect(throws: (any Error).self) { try AudioFile.readMono(FileManager.default.temporaryDirectory, sampleRate: 48000) }
  }
}
